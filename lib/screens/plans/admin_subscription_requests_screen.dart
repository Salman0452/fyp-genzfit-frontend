import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
