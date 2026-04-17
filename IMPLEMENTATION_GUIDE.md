// IMPLEMENTATION SUMMARY: Admin Panel, Notifications & Earnings Tracking
// ========================================================================

/*
ARCHITECTURE OVERVIEW:
======================

1. NOTIFICATION SYSTEM
   - When admin approves payment:
     * Client receives: "Session Approved! {TrainerName} has been connected to you"
     * Trainer receives: "New Client Connected! You are now connected with {ClientName}"
     * Notifications stored in: firestore/notifications collection

2. SESSION CREATION
   - Sessions automatically created when:
     * Admin verifies payment
     * Status changes from "requested" → "active"
     * Start date set to: now
     * End date set to: now + 30 days
     * Both client & trainer get notifications

3. EARNINGS TRACKING
   - Ledger system records every transaction:
     * Collection: firestore/earnings_ledger
     * Tracks: trainer amount, platform fee, total, status
     * Admin can view: who earned how much, from whom

4. TRAINER DASHBOARD
   - Shows real-time:
     * Active clients count
     * Active sessions count
     * Total earnings
     * Pending requests

5. ADMIN DASHBOARD
   - Pending payments with proof images
   - Verified sessions list
   - Earnings ledger with filters
   - Platform revenue calculation
   - Trainer earnings breakdown

FIRESTORE COLLECTIONS:
======================

notifications:
  - userId: string
  - type: string ('session_approved', 'payment_rejected')
  - title: string
  - message: string
  - sessionId: string (optional)
  - trainerId: string (optional)
  - clientId: string (optional)
  - createdAt: timestamp
  - read: boolean

earnings_ledger:
  - trainerId: string
  - clientId: string
  - sessionId: string
  - transactionId: string
  - amount: number (trainer's share)
  - platformFee: number (platform's share)
  - totalAmount: number (client paid)
  - createdAt: timestamp
  - status: string ('active', 'completed', 'cancelled')
  - type: string ('session_payment')

sessions (updated):
  - startDate: timestamp
  - endDate: timestamp

users (updated):
  - activeSessionCount: number (incremented)
  - totalEarnings: number (incremented)

IMPLEMENTATION STEPS:
====================

1. ADMIN PANEL (to implement):
   ✓ View pending payments
   ✓ See payment proof images
   ✓ Approve/Reject payments
   ✓ View active sessions
   ✓ View earnings ledger
   ✓ Calculate platform revenue

2. NOTIFICATIONS (ready to use):
   ✓ NotificationModel - DONE
   ✓ NotificationsService - DONE
   ✓ Auto-send on payment approval - DONE (in PaymentService)
   ✓ Auto-send on payment rejection - DONE (in PaymentService)

3. EARNINGS TRACKING (ready to use):
   ✓ Ledger creation on payment approval - DONE
   ✓ Trainer amount tracking - DONE
   ✓ Platform fee tracking - DONE
   ✓ Query ledger by trainer - DONE (AdminPaymentService)
   ✓ Query ledger by client - DONE (AdminPaymentService)

4. TRAINER DASHBOARD UPDATES:
   ✓ Count active clients - Already implemented
   ✓ Count active sessions - Already implemented
   ✓ Calculate total earnings - Already implemented

KEY SERVICES TO USE:
====================

// For Payment Approval (in Admin Panel):
PaymentService paymentService = PaymentService();
await paymentService.verifyPayment(
  transactionId: transactionId,
  approved: true,
  adminId: adminId,
);

// This automatically:
// 1. Updates transaction status to 'verified'
// 2. Sets session to 'active'
// 3. Creates notifications for trainer & client
// 4. Creates earnings ledger entry
// 5. Updates trainer/client user counts

// For Getting Pending Payments:
AdminPaymentVerificationService adminService = AdminPaymentVerificationService();
Stream<List<PendingPaymentModel>> pending = adminService.getPendingPayments();

// For Getting Earnings Ledger:
Stream<List<EarningsLedgerModel>> ledger = adminService.getTrainerEarningsLedger(trainerId);

// For Notifications:
NotificationsService notifService = NotificationsService();
Stream<List<NotificationModel>> notifications = notifService.getUserNotifications(userId);
Stream<int> unreadCount = notifService.getUnreadNotificationsCount(userId);

NOTIFICATION FLOW:
==================

Client Side:
1. User submits payment with receipt image
2. Admin views pending payments
3. Admin approves payment
4. Client automatically receives notification: "Session Approved!"
5. Session becomes "active"
6. Client can now see "Active Session" button
7. Can message/start session with trainer

Trainer Side:
1. Client submits hiring request + payment
2. Admin reviews and approves
3. Trainer automatically receives notification: "New Client Connected!"
4. Trainer sees increased active clients count on dashboard
5. Trainer sees new earnings in dashboard
6. Earnings ledger tracks this payment

Admin Side:
1. Receives pending payment for review
2. Reviews payment proof image from Cloudinary
3. Approves or rejects payment
4. Earnings ledger automatically updated
5. Can generate reports on platform revenue
6. Can see trainer earnings breakdown

DATABASE INTEGRITY:
===================

When payment is approved, the system ensures:
✓ Transaction marked as 'verified'
✓ Session marked as 'active' with date range (30 days)
✓ Trainer's activeSessionCount incremented
✓ Client's activeSessionCount incremented
✓ Trainer's totalEarnings incremented
✓ Earnings ledger entry created
✓ Both parties notified
✓ Admin can track who paid what

READY TO IMPLEMENT:
===================

All backend services are ready:
✓ NotificationModel - Create, store, fetch notifications
✓ NotificationsService - Stream notifications, mark read
✓ AdminPaymentService - All admin queries and models
✓ PaymentService.verifyPayment - Complete with notifications

Next step: Implement Admin Panel UI to use these services!
*/
