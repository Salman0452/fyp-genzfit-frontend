# Plan & Subscription Module Overview

## Firestore Collections
- `plans`: Stores available plans (free, monthly, yearly, etc.)
- `user_subscriptions`: Tracks each user's plan, status, and payment receipt
- `chatbot_usage`: Tracks daily AI chatbot message usage per user
- `settings/admin`: Stores admin bank details for payments

## Main Screens/Widgets
- `PlanSelectionScreen`: For clients to view/select plans, see usage, and purchase
- `AdminPlanSettingsScreen`: For admin to manage plans and set bank details
- `AdminSubscriptionRequestsScreen`: For admin to verify/reject client purchase requests
- `PlanUsageGuard`: Widget to block AI chatbot input if daily limit reached
- `PlanUsageCounter`: Widget to show usage counter in UI

## Providers/Services
- `PlanProvider`: Loads plans, user subscription, and usage; handles purchase requests
- `PlanService`: Firestore logic for plans, subscriptions, and usage
- `ChatbotGuardService`: Checks/enforces message limits for AI chatbot

## Usage Flow
1. **Admin** sets up plans and bank details in admin panel.
2. **Client** selects a plan, views bank details, uploads payment receipt.
3. **Admin** reviews requests, verifies payment, activates subscription.
4. **Client** gets message quota per plan; usage is tracked and enforced.

## Integration
- Use `PlanUsageGuard` to wrap AI chatbot input.
- Use `PlanUsageCounter` to show usage in chatbot UI.
- Use `PlanProvider` in settings/profile to show plan status and allow upgrades.

---

**All core files and Firestore structure are now scaffolded for the plan-based AI chatbot access module.**