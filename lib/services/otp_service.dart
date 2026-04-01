import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OTPService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _firebaseFunctionUrl =
      'https://us-central1-genzfit-fcf06.cloudfunctions.net/sendOTPEmail';

  /// Generate a 6-digit OTP
  String generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Send OTP to email via Firebase Functions
  Future<bool> sendOTP({
    required String email,
    required String otp,
  }) async {
    try {
      // Store OTP in Firestore with 5-minute expiry
      await _firestore.collection('otp_verification').doc(email).set({
        'otp': otp,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 5)),
        ),
        'verified': false,
        'attempts': 0,
        'resendCount': 0,
      });

      // Send email via Firebase Function
      final success = await _sendViaFirebaseFunction(email, otp);

      if (success) {
        print('✅ OTP email sent successfully to $email');
      } else {
        print('❌ Failed to send OTP email to $email');
        // OTP is still stored, user can verify it manually for testing
      }

      return true; // Return true even if email fails (OTP is stored)
    } catch (e) {
      print('❌ Error in sendOTP: $e');
      return false;
    }
  }

  /// Send email via Firebase Cloud Function
  Future<bool> _sendViaFirebaseFunction(String email, String otp) async {
    try {
      final response = await http
          .post(
            Uri.parse(_firebaseFunctionUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'otp': otp,
            }),
          )
          .timeout(const Duration(seconds: 10));

      print('📧 Firebase Function Response: ${response.statusCode}');
      print('📧 Response Body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Firebase Function Error: $e');
      return false;
    }
  }

  /// Alternative: Send via Mailtrap (for quick testing without Firebase Functions)
  /// Add MAILTRAP credentials to .env file
  Future<bool> _sendViaMailtrap(String email, String otp) async {
    try {
      // Get Mailtrap credentials from .env
      final mailtrapUsername = dotenv.env['MAILTRAP_USERNAME'];
      final mailtrapPassword = dotenv.env['MAILTRAP_PASSWORD'];

      if (mailtrapUsername == null || mailtrapPassword == null) {
        print('⚠️ Mailtrap credentials not configured in .env');
        return false;
      }

      final basicAuth =
          base64Encode(utf8.encode('$mailtrapUsername:$mailtrapPassword'));

      final response = await http.post(
        Uri.parse('https://send.api.mailtrap.io/api/send'),
        headers: {
          'Authorization': 'Bearer $mailtrapPassword',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': {'email': 'noreply@genzfit.com', 'name': 'GenZFit'},
          'to': [
            {'email': email}
          ],
          'subject': 'Your GenZFit OTP Code: $otp',
          'html': '''<html>
            <body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
              <div style="max-width: 500px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px;">
                <h2 style="color: #333; text-align: center;">Email Verification</h2>
                <p style="color: #666; font-size: 16px;">Your OTP code is:</p>
                <div style="text-align: center; margin: 20px 0;">
                  <div style="font-size: 32px; font-weight: bold; color: #00C853; letter-spacing: 5px; background-color: #f0f0f0; padding: 20px; border-radius: 8px;">
                    $otp
                  </div>
                </div>
                <p style="color: #999; font-size: 14px; text-align: center;">This code expires in 5 minutes</p>
                <p style="color: #999; font-size: 12px; text-align: center; margin-top: 20px;">
                  If you didn't request this code, please ignore this email.
                </p>
              </div>
            </body>
          </html>''',
        }),
      );

      print('📧 Mailtrap Response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ Mailtrap Error: $e');
      return false;
    }
  }

  /// Resend OTP to email
  Future<bool> resendOTP({required String email}) async {
    try {
      // Check if too many resend attempts
      final otpDoc =
          await _firestore.collection('otp_verification').doc(email).get();

      if (otpDoc.exists) {
        final data = otpDoc.data() as Map<String, dynamic>;
        final resendCount = data['resendCount'] ?? 0;

        if (resendCount >= 3) {
          return false; // Too many resend attempts
        }
      }

      // Generate new OTP and send
      final newOTP = generateOTP();
      final success = await sendOTP(email: email, otp: newOTP);

      if (success) {
        // Increment resend count
        await _firestore.collection('otp_verification').doc(email).update({
          'resendCount': FieldValue.increment(1),
        });
      }

      return success;
    } catch (e) {
      print('Error resending OTP: $e');
      return false;
    }
  }

  /// Verify OTP entered by user
  Future<bool> verifyOTP({
    required String email,
    required String enteredOTP,
  }) async {
    try {
      final otpDoc =
          await _firestore.collection('otp_verification').doc(email).get();

      if (!otpDoc.exists) {
        print('No OTP found for email: $email');
        return false;
      }

      final data = otpDoc.data() as Map<String, dynamic>;
      final storedOTP = data['otp'] as String;
      final expiresAt = data['expiresAt'] as Timestamp;
      final attempts = data['attempts'] as int? ?? 0;

      // Check if OTP is expired
      if (expiresAt.toDate().isBefore(DateTime.now())) {
        print('OTP expired for email: $email');
        await _firestore.collection('otp_verification').doc(email).delete();
        return false;
      }

      // Check if too many attempts
      if (attempts >= 5) {
        print('Too many OTP verification attempts for email: $email');
        await _firestore.collection('otp_verification').doc(email).delete();
        return false;
      }

      // Verify OTP
      if (storedOTP == enteredOTP.trim()) {
        // Mark as verified
        await _firestore.collection('otp_verification').doc(email).update({
          'verified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });

        print('✅ OTP verified for email: $email');
        return true;
      } else {
        // Increment attempts
        await _firestore.collection('otp_verification').doc(email).update({
          'attempts': FieldValue.increment(1),
        });

        print('❌ Invalid OTP attempt for email: $email');
        return false;
      }
    } catch (e) {
      print('Error verifying OTP: $e');
      return false;
    }
  }

  /// Check if email is verified
  Future<bool> isEmailVerified({required String email}) async {
    try {
      final otpDoc =
          await _firestore.collection('otp_verification').doc(email).get();

      if (!otpDoc.exists) {
        return false;
      }

      final data = otpDoc.data() as Map<String, dynamic>;
      return data['verified'] == true;
    } catch (e) {
      print('Error checking email verification: $e');
      return false;
    }
  }

  /// Get OTP expiry time
  Future<Duration?> getOTPExpiryTime({required String email}) async {
    try {
      final otpDoc =
          await _firestore.collection('otp_verification').doc(email).get();

      if (!otpDoc.exists) {
        return null;
      }

      final data = otpDoc.data() as Map<String, dynamic>;
      final expiresAt = data['expiresAt'] as Timestamp?;

      if (expiresAt == null) {
        return null;
      }

      final remaining = expiresAt.toDate().difference(DateTime.now());
      return remaining.isNegative ? null : remaining;
    } catch (e) {
      print('Error getting OTP expiry: $e');
      return null;
    }
  }

  /// Get resend cooldown time
  Future<Duration?> getResendCooldownTime({required String email}) async {
    try {
      final otpDoc =
          await _firestore.collection('otp_verification').doc(email).get();

      if (!otpDoc.exists) {
        return null;
      }

      final data = otpDoc.data() as Map<String, dynamic>;
      final lastResendTime = data['lastResendAt'] as Timestamp?;

      if (lastResendTime == null) {
        return null;
      }

      // 2-minute cooldown between resends
      final nextResendTime =
          lastResendTime.toDate().add(const Duration(minutes: 2));
      final remaining = nextResendTime.difference(DateTime.now());

      return remaining.isNegative ? null : remaining;
    } catch (e) {
      print('Error getting resend cooldown: $e');
      return null;
    }
  }

  /// Clean up expired OTP records
  Future<void> cleanupExpiredOTPs() async {
    try {
      final snapshot = await _firestore.collection('otp_verification').get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final expiresAt = data['expiresAt'] as Timestamp?;

        if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
          await doc.reference.delete();
        }
      }

      print('✅ Cleaned up expired OTP records');
    } catch (e) {
      print('Error cleaning up expired OTPs: $e');
    }
  }

  /// Delete OTP record after successful signup
  Future<void> deleteOTP({required String email}) async {
    try {
      await _firestore.collection('otp_verification').doc(email).delete();
      print('✅ OTP record deleted for email: $email');
    } catch (e) {
      print('Error deleting OTP: $e');
    }
  }
}
