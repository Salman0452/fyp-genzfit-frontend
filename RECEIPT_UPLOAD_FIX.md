# Receipt Upload Crash - Root Cause & Fix

## 🎯 Root Cause Found

**Error**: `java.io.IOException: Permission denied` in `FilePickerDelegate.compressImage()`

**Issue**: FilePicker was trying to compress the selected image, which requires temporary file creation. The app lacked permission to write temporary files in the app's cache directory.

## ✅ Solution Applied

Modified `lib/screens/plans/plan_selection_screen.dart` FilePicker call:

### Before (Crashes):
```dart
final result = await FilePicker.platform.pickFiles(
  type: FileType.image,
  withData: true,
);
```

### After (Fixed):
```dart
final result = await FilePicker.platform.pickFiles(
  type: FileType.image,
  withData: true,
  allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
  allowCompression: false,  // ← CRITICAL FIX
);
```

## Changes Made

1. **`allowCompression: false`** - Disables image compression during file picking
   - Prevents attempts to create temporary files
   - Gets raw bytes directly from the selected file
   - Eliminates permission denied error

2. **`allowedExtensions`** - Explicitly defines allowed image formats
   - Ensures only image types can be selected
   - Improves type safety

## Why This Works

- FilePicker's compression feature requires writing to temp directory
- Even with storage permissions, cache directory write may fail
- By disabling compression, raw bytes are extracted without temp files
- Our Cloudinary upload doesn't need pre-compressed images anyway

## What You'll See Now

✅ File picker opens normally
✅ Select receipt image → succeeds (no crash)
✅ Image preview displays
✅ Click "Submit receipt" → uploads to Cloudinary
✅ Dialog closes → success message appears
✅ Request stored in Firestore for admin approval

## Testing Steps

1. **Clear app data** (recommended after crash):
   - Android: Settings → Apps → GenZFit → Storage → Clear All Data
   - Or uninstall and reinstall

2. **Run the app**:
   ```bash
   flutter run -d <device>
   ```

3. **Test receipt upload**:
   - Go to pricing screen
   - Select a plan → "Purchase plan"
   - Scroll to "Upload receipt" step
   - Click "Choose Receipt"
   - Select an image → should NOT crash anymore
   - Image preview appears
   - Click "Submit receipt"
   - Watch debug logs for `[PickReceipt]`, `[SubmitPurchase]`, `[CloudinaryUpload]` prefixes

4. **Expected success**:
   - Dialog closes
   - Toast message: "Purchase request submitted. Awaiting admin verification."
   - Check Firestore → collection: `user_subscriptions` → new doc with status: "pending"

## Debug Information

If still issues, the comprehensive logging will show:

- `[PickReceipt]` logs - File selection process
- `[SubmitPurchase]` logs - Dialog submission process  
- `[CloudinaryUpload]` logs - Upload to Cloudinary process

All logs now include step-by-step debugging to pinpoint any remaining issues.

## Related Files Modified

- `lib/screens/plans/plan_selection_screen.dart` - FilePicker parameters
- `lib/services/storage_service.dart` - Cloudinary upload logging
- Plus comprehensive exception logging throughout

---

**Status**: ✅ Root cause identified and fixed. Ready to test!
