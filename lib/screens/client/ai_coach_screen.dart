import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:genzfit/models/user_model.dart';
import 'package:genzfit/services/ai_chatbot_service.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../providers/plan_provider.dart';
import '../../models/plan_models.dart';

class AICoachScreen extends StatefulWidget {
  final UserModel user;

  const AICoachScreen({super.key, required this.user});

  @override
  State<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends State<AICoachScreen> {
  late final AIChatbotService _chatbotService;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  List<String> _suggestedPrompts = [];
  bool _isLoading = false;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    _chatbotService = AIChatbotService(apiKey: apiKey);
    _loadConversationHistory();
    _loadSuggestedPrompts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final planProvider = Provider.of<PlanProvider>(context, listen: false);
      planProvider.loadPlans();
      planProvider.loadActiveSubscription(widget.user.id);
      planProvider.loadTodayUsage(widget.user.id);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversationHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final history =
          await _chatbotService.getConversationHistory(widget.user.id);
      setState(() {
        _messages = history;
        _isLoadingHistory = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoadingHistory = false);
      _showError('Failed to load conversation history');
    }
  }

  Future<void> _loadSuggestedPrompts() async {
    try {
      final prompts = await _chatbotService.getSuggestedPrompts(
        widget.user.id,
        widget.user,
      );
      setState(() => _suggestedPrompts = prompts);
    } catch (e) {
      print('Error loading suggested prompts: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final planProvider = Provider.of<PlanProvider>(context, listen: false);
    final activePlan = planProvider.activeSubscription;
    final plans = planProvider.plans;
    int dailyLimit = 3;
    if (activePlan != null) {
      final plan = plans.firstWhere(
        (p) => p.id == activePlan.planId,
        orElse: () => PlanModel(
            id: '',
            name: '',
            dailyMessageLimit: 3,
            price: 0,
            duration: '',
            description: '',
            sortOrder: 0),
      );
      dailyLimit = plan.dailyMessageLimit;
    }
    final used = planProvider.todayUsage?.messageCount ?? 0;
    if (used >= dailyLimit) {
      _showError(
          'You have reached your daily AI chatbot message limit. Upgrade your plan to continue.');
      return;
    }
    final userMessage = ChatMessage(
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _messageController.clear();
    });
    _scrollToBottom();
    try {
      final response = await _chatbotService.sendMessage(
        userId: widget.user.id,
        user: widget.user,
        message: text.trim(),
      );

      final aiMessage = ChatMessage(
        role: 'assistant',
        content: response,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(aiMessage);
        _isLoading = false;
      });
      await planProvider.incrementUsage(widget.user.id);
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to get response. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade900,
      ),
    );
  }

  Future<void> _clearHistory() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            isDarkMode ? const Color(0xFF262626) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color:
                isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        title: Text(
          'Clear Conversation',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to clear all messages?',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color:
                isDarkMode ? const Color(0xFFB0B0B0) : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? const Color(0xFFB0B0B0)
                    : AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Clear',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _chatbotService.clearHistory(widget.user.id);
      setState(() => _messages.clear());
    }
  }

  Widget _buildUsageProgressBar(PlanProvider planProvider) {
    final activePlan = planProvider.activeSubscription;
    final plans = planProvider.plans;
    int dailyLimit = 3;
    if (activePlan != null) {
      final plan = plans.firstWhere(
        (p) => p.id == activePlan.planId,
        orElse: () => PlanModel(
            id: '',
            name: '',
            dailyMessageLimit: 3,
            price: 0,
            duration: '',
            description: '',
            sortOrder: 0),
      );
      dailyLimit = plan.dailyMessageLimit;
    }
    final used = planProvider.todayUsage?.messageCount ?? 0;
    final percent = dailyLimit > 0 ? (used / dailyLimit).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AI Chatbot Usage: $used / $dailyLimit',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        LinearPercentIndicator(
          lineHeight: 16.0,
          percent: percent,
          backgroundColor: Colors.grey.shade300,
          progressColor: percent < 0.8
              ? Colors.green
              : (percent < 1.0 ? Colors.orange : Colors.red),
          barRadius: const Radius.circular(8),
          center: Text('${(percent * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, color: Colors.black)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return ChangeNotifierProvider(
      create: (_) => PlanProvider()
        ..loadPlans()
        ..loadActiveSubscription(widget.user.id)
        ..loadTodayUsage(widget.user.id),
      child: Consumer<PlanProvider>(
        builder: (context, planProvider, _) {
          final activePlan = planProvider.activeSubscription;
          final plans = planProvider.plans;
          int dailyLimit = 3;
          if (activePlan != null) {
            final plan = plans.firstWhere(
              (p) => p.id == activePlan.planId,
              orElse: () => PlanModel(
                  id: '',
                  name: '',
                  dailyMessageLimit: 3,
                  price: 0,
                  duration: '',
                  description: '',
                  sortOrder: 0),
            );
            dailyLimit = plan.dailyMessageLimit;
          }
          final used = planProvider.todayUsage?.messageCount ?? 0;
          final limitReached = used >= dailyLimit;
          return Scaffold(
            backgroundColor:
                isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
            appBar: AppBar(
              backgroundColor:
                  isDarkMode ? const Color(0xFF262626) : Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.brandBlue, AppColors.brandGreen],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.smart_toy,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Coach',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color:
                              isDarkMode ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Powered by Groq',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode
                              ? const Color(0xFFB0B0B0)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary),
                  onPressed: _clearHistory,
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: _isLoadingHistory
                      ? Center(
                          child: CircularProgressIndicator(
                            color: isDarkMode
                                ? AppColors.brandGreen
                                : AppColors.brandGreenDeep,
                          ),
                        )
                      : _messages.isEmpty
                          ? _buildEmptyState(isDarkMode)
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                return _buildMessageBubble(
                                    _messages[index], isDarkMode);
                              },
                            ),
                ),
                if (_isLoading)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDarkMode
                                      ? const Color(0xFFB0B0B0)
                                      : const Color(0xFF595959),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Typing...',
                                style: GoogleFonts.inter(
                                  color: isDarkMode
                                      ? const Color(0xFFB0B0B0)
                                      : const Color(0xFF595959),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else if (limitReached)
                  Center(
                    child: Text(
                      'You have reached your daily AI chatbot message limit. Upgrade your plan to continue.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _buildInputArea(isDarkMode),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brandBlue, AppColors.brandGreen],
              ),
              borderRadius: BorderRadius.circular(60),
            ),
            child:
                const Icon(Icons.fitness_center, color: Colors.white, size: 60),
          ),
          const SizedBox(height: 24),
          Text(
            'Your AI Fitness Coach',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Get personalized advice based on your\nmeasurements, goals, and progress',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDarkMode
                  ? const Color(0xFFB0B0B0)
                  : AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF262626)
                  : const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDarkMode
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep)
                    .withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: isDarkMode
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep,
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'AI has access to:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDataPoint('Your body measurements & BMI', isDarkMode),
                _buildDataPoint('Current meal & exercise plans', isDarkMode),
                _buildDataPoint('Progress tracking over time', isDarkMode),
                _buildDataPoint('Your fitness goals', isDarkMode),
              ],
            ),
          ),
          const SizedBox(height: 40),
          if (_suggestedPrompts.isNotEmpty) ...[
            Text(
              'Try asking:',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedPrompts.map((prompt) {
                return InkWell(
                  onTap: () => _sendMessage(prompt),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF262626)
                          : const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (isDarkMode
                                ? AppColors.brandGreen
                                : AppColors.brandGreenDeep)
                            .withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      prompt,
                      style: GoogleFonts.inter(
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataPoint(String text, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(width: 28),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color:
                  isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDarkMode
                    ? const Color(0xFFB0B0B0)
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDarkMode) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brandBlue, AppColors.brandGreen],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser
                        ? (isDarkMode
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep)
                        : (isDarkMode
                            ? const Color(0xFF262626)
                            : const Color(0xFFF0F0F0)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: GoogleFonts.inter(
                      color: isUser
                          ? Colors.white
                          : (isDarkMode ? Colors.white : AppColors.textPrimary),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(message.timestamp),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDarkMode
                        ? const Color(0xFF595959)
                        : const Color(0xFFC0C0C0),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundImage: widget.user.avatarUrl != null
                  ? NetworkImage(widget.user.avatarUrl!)
                  : null,
              backgroundColor: isDarkMode
                  ? const Color(0xFF262626)
                  : const Color(0xFFF0F0F0),
              child: widget.user.avatarUrl == null
                  ? Text(
                      widget.user.name[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                        color:
                            isDarkMode ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDarkMode) {
    return Consumer<PlanProvider>(
      builder: (context, planProvider, _) {
        final activePlan = planProvider.activeSubscription;
        final plans = planProvider.plans;
        int dailyLimit = 3;
        if (activePlan != null) {
          final plan = plans.firstWhere(
            (p) => p.id == activePlan.planId,
            orElse: () => PlanModel(
                id: '',
                name: '',
                dailyMessageLimit: 3,
                price: 0,
                duration: '',
                description: '',
                sortOrder: 0),
          );
          dailyLimit = plan.dailyMessageLimit;
        }
        final used = planProvider.todayUsage?.messageCount ?? 0;
        final limitReached = used >= dailyLimit;
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF262626) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDarkMode
                      ? const Color(0xFF3A3A3A)
                      : const Color(0xFFE0E0E0),
                  width: 1,
                ),
              ),
            ),
            child: limitReached
                ? Center(
                    child: Text(
                      'You have reached your daily AI chatbot message limit. Upgrade your plan to continue.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF1A1A1A)
                                : const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDarkMode
                                  ? const Color(0xFF3A3A3A)
                                  : const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _messageController,
                            style: GoogleFonts.inter(
                              color: isDarkMode
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: _sendMessage,
                            decoration: InputDecoration(
                              hintText: 'Ask me anything...',
                              hintStyle: GoogleFonts.inter(
                                color: isDarkMode
                                    ? const Color(0xFF595959)
                                    : const Color(0xFFC0C0C0),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.brandBlue, AppColors.brandGreen],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send,
                              color: Colors.white, size: 20),
                          onPressed: () =>
                              _sendMessage(_messageController.text),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
