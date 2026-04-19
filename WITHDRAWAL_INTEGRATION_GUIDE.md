# Withdrawal System Integration Guide

## How to Integrate into Your App

### 1. Add to Trainer Settings Screen

In `trainer_settings_screen.dart`, add a navigation button to the Earnings screen:

```dart
ListTile(
  title: const Text('Earnings & Withdrawals'),
  subtitle: const Text('Manage bank details and withdrawal requests'),
  leading: const Icon(Icons.monetization_on),
  trailing: const Icon(Icons.arrow_forward_ios),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrainerEarningsScreen(),
      ),
    );
  },
),
```

### 2. Add to Admin Dashboard

In your admin dashboard, add a navigation item:

```dart
ListTile(
  title: const Text('Withdrawal Requests'),
  subtitle: const Text('Manage trainer payment withdrawals'),
  leading: const Icon(Icons.payments),
  trailing: const Icon(Icons.arrow_forward_ios),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminWithdrawalManagementScreen(),
      ),
    );
  },
),
```

### 3. Import Statements

Add these imports where needed:

```dart
import 'package:genzfit/screens/trainer/trainer_earnings_screen.dart';
import 'package:genzfit/screens/admin/admin_withdrawal_management_screen.dart';
import 'package:genzfit/services/withdrawal_service.dart';
import 'package:genzfit/models/withdrawal_request_model.dart';
import 'package:genzfit/models/bank_details_model.dart';
```

### 4. Firestore Security Rules (Add to firestore.rules)

```dart
// Withdrawal requests collection
match /withdrawal_requests/{document=**} {
  // Trainers can read their own and create new
  allow read: if request.auth.uid != null && (
    resource.data.trainerId == request.auth.uid
  );
  allow create: if request.auth.uid != null && (
    request.resource.data.trainerId == request.auth.uid &&
    request.resource.data.status == 'requested'
  );
  
  // Only admins can update status
  allow update: if request.auth.uid != null && 
    get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.isAdmin == true;
}

// Bank details collection (nested under trainers)
match /trainers/{trainerId}/bank_details/{document=**} {
  // Trainers can read/write their own
  allow read, write: if request.auth.uid == trainerId;
  
  // Admins can read all
  allow read: if get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.isAdmin == true;
}

// Payment ledger
match /payment_ledger/{document=**} {
  // Trainers can read their own
  allow read: if request.auth.uid != null && (
    resource.data.trainerId == request.auth.uid
  );
  
  // Only server functions can write
  allow write: if false;
}
```

### 5. Add Withdrawal Status Badge to Trainer Dashboard

If you want to show withdrawal requests status in the trainer dashboard:

```dart
// In trainer dashboard
FutureBuilder<List<WithdrawalRequestModel>>(
  future: _withdrawalService.getWithdrawalHistory(trainerId).first,
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const SizedBox.shrink();
    
    final requests = snapshot.data ?? [];
    final pending = requests.where((r) => r.status == WithdrawalStatus.requested).length;
    
    if (pending > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$pending Pending Withdrawals',
          style: TextStyle(color: AppColors.warning, fontSize: 12),
        ),
      );
    }
    return const SizedBox.shrink();
  },
)
```

### 6. Add Notifications Integration

When withdrawal status changes, send notifications:

```dart
// In WithdrawalService methods

// When withdrawal is approved
await _firestore.collection('notifications').add({
  'userId': trainerId,
  'type': 'withdrawal_approved',
  'title': 'Withdrawal Approved',
  'message': 'Your withdrawal request for Rs. ${amount.toStringAsFixed(2)} has been approved. Funds will be transferred shortly.',
  'withdrawalId': withdrawalId,
  'createdAt': FieldValue.serverTimestamp(),
  'read': false,
});

// When withdrawal is completed
await _firestore.collection('notifications').add({
  'userId': trainerId,
  'type': 'withdrawal_completed',
  'title': 'Withdrawal Completed',
  'message': 'Your withdrawal has been successfully transferred to your bank account.',
  'withdrawalId': withdrawalId,
  'transactionId': transactionId,
  'createdAt': FieldValue.serverTimestamp(),
  'read': false,
});

// When withdrawal is rejected
await _firestore.collection('notifications').add({
  'userId': trainerId,
  'type': 'withdrawal_rejected',
  'title': 'Withdrawal Rejected',
  'message': 'Your withdrawal request was rejected. Reason: ${rejectionReason}',
  'withdrawalId': withdrawalId,
  'createdAt': FieldValue.serverTimestamp(),
  'read': false,
});
```

## Testing Checklist

- [ ] Trainer can add bank account
- [ ] Bank account shows "Pending" until verified
- [ ] Trainer cannot request withdrawal with unverified bank
- [ ] Admin can view pending withdrawal requests
- [ ] Admin can approve withdrawal
- [ ] Admin can reject withdrawal with reason
- [ ] Admin can mark as completed with transaction ID
- [ ] Trainer sees updated balance after rejection
- [ ] Payment ledger shows all transactions
- [ ] Available balance calculation is correct
- [ ] Notifications are sent at each status change
- [ ] Account numbers are masked in UI

## File Locations

- Models:
  - `/lib/models/withdrawal_request_model.dart` (NEW)
  - `/lib/models/bank_details_model.dart` (EXISTING)

- Services:
  - `/lib/services/withdrawal_service.dart` (NEW)

- Screens:
  - `/lib/screens/trainer/trainer_earnings_screen.dart` (NEW)
  - `/lib/screens/admin/admin_withdrawal_management_screen.dart` (NEW)

- Documentation:
  - `/WITHDRAWAL_SYSTEM_ARCHITECTURE.md` (NEW)

## Key Features

✅ **Complete Payment Workflow**: Request → Approve → Process → Complete
✅ **Bank Account Management**: Add, edit, verify accounts
✅ **Payment History**: Full audit trail of all transactions
✅ **Available Balance**: Real-time calculation excluding pending withdrawals
✅ **Admin Controls**: Approve, reject, and process withdrawals
✅ **Security**: Account number masking, Firestore rules
✅ **Ledger System**: Track all financial activities
✅ **Status Tracking**: Multiple withdrawal request statuses

## Next Steps

1. Update Firestore security rules
2. Add notifications integration
3. Add bank details verification UI for admins
4. Test withdrawal workflow end-to-end
5. Add payment processing integration if needed
