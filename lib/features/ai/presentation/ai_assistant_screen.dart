import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/services/auth_service.dart';
import '../services/ai_service.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final AIService _aiService = AIService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _authService.getSeekerData();
    setState(() {
      _userProfile = profile;
      _isLoadingProfile = false;
    });

    // Add welcome message
    if (profile != null) {
      _addMessage(
        ChatMessage(
          text: "Hi ${profile['name']}! 👋 I'm your AI fitness coach. I can help you with:\n\n"
              "💪 Personalized workout plans\n"
              "🥗 Nutrition advice\n"
              "🎯 Fitness tips and guidance\n"
              "📊 Progress tracking advice\n\n"
              "What would you like to know?",
          isUser: false,
        ),
      );
    }
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Add user message
    _addMessage(ChatMessage(text: text, isUser: true));
    _messageController.clear();

    setState(() => _isLoading = true);

    // Get AI response
    final response = await _aiService.chat(text, userProfile: _userProfile);

    setState(() => _isLoading = false);

    if (response != null) {
      _addMessage(ChatMessage(text: response, isUser: false));
    } else {
      _addMessage(
        ChatMessage(
          text: "Sorry, I couldn't process that. Please try again.",
          isUser: false,
        ),
      );
    }
  }

  Future<void> _getPersonalizedPlan() async {
    if (_userProfile == null) return;

    setState(() => _isLoading = true);

    _addMessage(
      ChatMessage(
        text: "Get me a personalized fitness plan",
        isUser: true,
      ),
    );

    final suggestions = await _aiService.getPersonalizedSuggestions(
      name: _userProfile!['name'] ?? 'User',
      age: _userProfile!['age'] ?? 25,
      gender: _userProfile!['gender'] ?? 'Male',
      weight: (_userProfile!['weight'] ?? 70).toDouble(),
      height: (_userProfile!['height'] ?? 170).toDouble(),
      fitnessGoal: _userProfile!['fitnessGoal'] ?? 'Get Fit',
    );

    setState(() => _isLoading = false);

    if (suggestions != null) {
      _addMessage(ChatMessage(text: suggestions, isUser: false));
    }
  }

  Future<void> _getWorkoutPlan() async {
    if (_userProfile == null) return;

    setState(() => _isLoading = true);

    _addMessage(
      ChatMessage(
        text: "Create a workout plan for me",
        isUser: true,
      ),
    );

    final plan = await _aiService.getWorkoutPlan(
      fitnessGoal: _userProfile!['fitnessGoal'] ?? 'Get Fit',
      age: _userProfile!['age'] ?? 25,
      gender: _userProfile!['gender'] ?? 'Male',
    );

    setState(() => _isLoading = false);

    if (plan != null) {
      _addMessage(ChatMessage(text: plan, isUser: false));
    }
  }

  Future<void> _getMealPlan() async {
    if (_userProfile == null) return;

    setState(() => _isLoading = true);

    _addMessage(
      ChatMessage(
        text: "Give me a meal plan",
        isUser: true,
      ),
    );

    final plan = await _aiService.getMealPlan(
      fitnessGoal: _userProfile!['fitnessGoal'] ?? 'Get Fit',
      weight: (_userProfile!['weight'] ?? 70).toDouble(),
      age: _userProfile!['age'] ?? 25,
    );

    setState(() => _isLoading = false);

    if (plan != null) {
      _addMessage(ChatMessage(text: plan, isUser: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Quick action buttons
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.cardBackground,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickActionChip(
                        'Personalized Plan',
                        Icons.person,
                        _getPersonalizedPlan,
                      ),
                      const SizedBox(width: 8),
                      _buildQuickActionChip(
                        'Workout Plan',
                        Icons.fitness_center,
                        _getWorkoutPlan,
                      ),
                      const SizedBox(width: 8),
                      _buildQuickActionChip(
                        'Meal Plan',
                        Icons.restaurant,
                        _getMealPlan,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.smart_toy,
                          size: 80,
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'AI Fitness Coach',
                          style: AppTextStyles.heading.copyWith(fontSize: 24),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ask me anything about fitness!',
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI is thinking...',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.accent,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          // Input field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: AppColors.text),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Ask me anything...',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.smart_toy, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: message.isUser ? AppColors.accent : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.text,
                style: AppTextStyles.body.copyWith(
                  color: message.isUser ? Colors.white : AppColors.text,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accentOrange,
              child: Text(
                _userProfile?['name']?[0].toUpperCase() ?? 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({
    required this.text,
    required this.isUser,
  });
}
