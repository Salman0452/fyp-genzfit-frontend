# Trainer Payment Withdrawal System Architecture

## Overview
Complete payment withdrawal system allowing trainers to request payouts, admins to manage approvals, and full payment history tracking.

## System Components

### 1. Data Models

#### WithdrawalRequestModel
- **ID**: Unique identifier
- **trainerId**: Reference to trainer
- **amount**: Withdrawal amount
- **status**: requested → approved → processing → completed (or rejected/failed)
- **bankDetailsId**: Reference to verified bank account
- **rejectionReason**: If rejected by admin
- **transactionId**: Bank transaction ID after completion
- **createdAt**: Request submission time
- **processedAt**: Admin action time
- **completedAt**: Final completion time

#### BankDetailsModel
- **ID**: Unique identifier
- **trainerId**: Reference to trainer
- **accountName**: Account holder name
- **accountNumber**: Bank account number (masked in UI)
- **bankName**: Bank name
- **bankCode**: Bank routing/SWIFT code
- **verified**: Admin verification status
- **createdAt**: Addition date
- **updatedAt**: Last modification date

### 2. Services

#### WithdrawalService
Methods:
- `requestWithdrawal()` - Trainer initiates withdrawal request
- `getWithdrawalHistory()` - Get trainer's withdrawal history
- `getPendingWithdrawals()` - Admin view all pending requests
- `approveWithdrawal()` - Admin approves request
- `rejectWithdrawal()` - Admin rejects with reason
- `completeWithdrawal()` - Mark as sent with transaction ID
- `getBankDetails()` - Retrieve bank account details
- `updateBankDetails()` - Modify account details
- `addBankDetails()` - Add new bank account
- `getAvailableBalance()` - Calculate balance (earnings - pending withdrawals)
- `getPaymentHistory()` - Get full ledger for trainer

### 3. Payment Ledger
Tracks all financial transactions:
- **type**: session_completed, withdrawal_requested, withdrawal_approved, withdrawal_rejected, withdrawal_completed
- **amount**: +/- amount affected
- **description**: Human-readable description
- **referenceId**: Link to withdrawal or session
- **createdAt**: Transaction timestamp

### 4. UI Screens

#### TrainerEarningsScreen
Three-tab interface:
1. **Overview Tab**
   - Available balance card
   - Quick action: Request Withdrawal button
   - Shows real-time balance calculation

2. **Bank Details Tab**
   - List of added bank accounts
   - Verification status indicator
   - Add/Edit/Delete buttons
   - Unverified accounts are disabled for withdrawal

3. **History Tab**
   - Complete payment ledger
   - All transactions with dates and amounts
   - Type indicators (earnings, withdrawals, rejections)
   - Color-coded status

#### AdminWithdrawalManagementScreen
- Lists all pending withdrawal requests
- For each request shows:
  - Trainer name and email
  - Withdrawal amount
  - Bank details (partially masked)
  - Request timestamp
- Actions:
  - **Approve**: Sets to "approved" status
  - **Reject**: Requires reason, returns funds to balance
  - **Complete**: Requires transaction ID, marks completed

### 5. Workflow

#### Trainer Side
1. Trainer adds bank account in settings
2. Bank account shows "Pending" until admin verifies
3. Once verified, trainer can request withdrawal
4. Enters amount, selects verified bank account
5. Withdrawal request created with "requested" status
6. Trainer can view request status in history
7. Once completed, funds marked as transferred

#### Admin Side
1. Admin sees pending withdrawal requests
2. Reviews trainer details and bank information
3. Can approve → triggers completion process
4. Can reject → provides reason, funds returned
5. After approval, admin enters bank transaction ID
6. Marks as completed → trainer receives notification

#### System Side
- Each action creates ledger entry
- Balance calculation excludes pending/approved withdrawals
- Notifications sent at each status change
- Complete audit trail maintained

### 6. Security Considerations

#### Firestore Rules (To be implemented)
```
- Trainers can read/write own bank details and withdrawal requests
- Trainers can view own payment ledger
- Admins can read/write all withdrawal requests and bank details
- No one can modify completed withdrawal requests
- Bank details verified field only modifiable by admins
```

#### Data Protection
- Account numbers displayed masked (only last 4 digits visible)
- Full numbers only visible to admin on approval screen
- Sensitive data protected by Firestore rules

### 7. Notifications
At each status change:
- withdrawal_requested: Trainer notified request submitted
- withdrawal_approved: Trainer notified admin approved
- withdrawal_completed: Trainer notified funds transferred
- withdrawal_rejected: Trainer notified with reason

### 8. Balance Calculation Formula
```
Available Balance = Total Completed Sessions Amount 
                 - (Pending + Approved + Processing Withdrawals)
```

## Database Structure

```
withdrawal_requests/
  {withdrawalId}/
    - trainerId
    - amount
    - status
    - bankDetailsId
    - rejectionReason
    - transactionId
    - createdAt
    - processedAt
    - completedAt

trainers/{trainerId}/bank_details/
  {bankDetailsId}/
    - trainerId
    - accountName
    - accountNumber
    - bankName
    - bankCode
    - verified
    - createdAt
    - updatedAt

payment_ledger/
  {entryId}/
    - trainerId
    - type
    - amount
    - description
    - referenceId
    - createdAt
```

## Features Implemented
✅ Withdrawal request model and service
✅ Bank details management
✅ Payment ledger and history
✅ Trainer earnings UI with 3 tabs
✅ Admin withdrawal management screen
✅ Available balance calculation
✅ Request approval/rejection workflow
✅ Transaction ID tracking
✅ Secure account number masking

## TODO
- [ ] Firestore security rules
- [ ] Notification system integration
- [ ] Admin bank details verification UI
- [ ] Payment processing integration (if using external payment gateway)
- [ ] Withdrawal request status tracking in trainer dashboard
- [ ] Email notifications for status changes
