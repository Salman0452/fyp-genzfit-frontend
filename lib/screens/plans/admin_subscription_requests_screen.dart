import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/plan_models.dart';

class AdminSubscriptionRequestsScreen extends StatelessWidget {
  const AdminSubscriptionRequestsScreen({super.key});

  Future<void> _verifyRequest(String docId) async {
    await FirebaseFirestore.instance
        .collection('user_subscriptions')
        .doc(docId)
        .update({
      'status': 'active',
      'startDate': Timestamp.now(),
      // Optionally set endDate for monthly/yearly
    });
  }

  Future<void> _rejectRequest(String docId) async {
    await FirebaseFirestore.instance
        .collection('user_subscriptions')
        .doc(docId)
        .update({
      'status': 'rejected',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_subscriptions')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final err = snapshot.error?.toString() ?? 'Unknown error';
            final match =
                RegExp(r'https://console\.firebase\.google\.com/[^\s)\]]+')
                    .firstMatch(err);
            final indexUrl = match?.group(0);
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: Colors.red.shade700),
                    const SizedBox(height: 12),
                    Text('Firestore Error',
                        style: GoogleFonts.poppins(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SelectableText(err),
                    if (indexUrl != null) ...[
                      const SizedBox(height: 12),
                      SelectableText(indexUrl),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: indexUrl));
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Index link copied')));
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy index link'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final requests = snapshot.data!.docs;
          if (requests.isEmpty) {
            return const Center(child: Text('No pending requests.'));
          }
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, i) {
              final doc = requests[i];
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  title: Text('User: ${data['userId']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plan: ${data['planId']}'),
                      if (data['paymentReceiptUrl'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: SelectableText(
                              'Receipt: ${data['paymentReceiptUrl']}'),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _verifyRequest(doc.id),
                        tooltip: 'Verify',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _rejectRequest(doc.id),
                        tooltip: 'Reject',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
