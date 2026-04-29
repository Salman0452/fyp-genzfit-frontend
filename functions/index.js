const functions = require("firebase-functions");
const nodemailer = require("nodemailer");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const runtimeConfig = functions.config();
const gmailUser = process.env.GMAIL_USER || runtimeConfig.gmail?.user;
const gmailAppPassword =
  process.env.GMAIL_APP_PASSWORD || runtimeConfig.gmail?.app_password;

// Configure your email service here
// Option 1: Gmail
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: gmailUser,
    pass: gmailAppPassword, // Use app-specific password, not main password
  },
});

const bootstrapAdminSecret =
  process.env.BOOTSTRAP_ADMIN_SECRET || runtimeConfig.bootstrap?.secret;

exports.bootstrapAdmin = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  try {
    if (!bootstrapAdminSecret) {
      return res.status(500).json({
        success: false,
        message: "Bootstrap secret is not configured",
      });
    }

    const { secret, email, password, name, role = "super_admin" } = req.body || {};

    if (secret !== bootstrapAdminSecret) {
      return res.status(403).json({
        success: false,
        message: "Invalid bootstrap secret",
      });
    }

    if (!email || !password || !name) {
      return res.status(400).json({
        success: false,
        message: "Email, password, and name are required",
      });
    }

    let userRecord;
    try {
      userRecord = await admin.auth().getUserByEmail(email);
    } catch (error) {
      if (error.code !== "auth/user-not-found") {
        throw error;
      }
      userRecord = await admin.auth().createUser({
        email,
        password,
        displayName: name,
        emailVerified: true,
      });
    }

    const allowedRoles = new Set(["admin", "super_admin", "finance_admin", "moderator", "support"]);
    const normalizedRole = allowedRoles.has(role) ? role : "super_admin";

    await admin.auth().setCustomUserClaims(userRecord.uid, {
      admin: true,
      role: normalizedRole,
    });

    await admin.firestore().collection("users").doc(userRecord.uid).set(
      {
        id: userRecord.uid,
        email,
        name,
        role: normalizedRole,
        roleKey: normalizedRole,
        status: "active",
        emailVerified: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return res.status(200).json({
      success: true,
      message: `Admin account is ready with role ${normalizedRole}`,
      uid: userRecord.uid,
    });
  } catch (error) {
    console.error("Error bootstrapping admin:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to bootstrap admin",
      error: error.message,
    });
  }
});

// Option 2: Mailtrap (uncomment to use instead)
// const transporter = nodemailer.createTransport({
//   host: "smtp.mailtrap.io",
//   port: 2525,
//   auth: {
//     user: process.env.MAILTRAP_USERNAME,
//     pass: process.env.MAILTRAP_PASSWORD,
//   },
// });

// Cloud Function to send OTP via email
exports.sendOTPEmail = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  try {
    if (!gmailUser || !gmailAppPassword) {
      return res.status(500).json({
        success: false,
        message: "Email sender is not configured",
      });
    }

    const { email, otp } = req.body;

    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        message: "Email and OTP are required",
      });
    }

    // Email HTML template
    const htmlContent = `
      <html>
        <body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
          <div style="max-width: 500px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #00C853; font-size: 28px; margin: 0;">GenZFit</h1>
              <p style="color: #999; font-size: 12px; margin: 5px 0 0 0;">Fitness & Coaching Platform</p>
            </div>
            
            <h2 style="color: #333; text-align: center; margin: 20px 0;">Email Verification</h2>
            <p style="color: #666; font-size: 16px; text-align: center;">Your OTP code is:</p>
            
            <div style="text-align: center; margin: 30px 0;">
              <div style="font-size: 48px; font-weight: bold; color: #00C853; letter-spacing: 8px; background-color: #f0f0f0; padding: 20px; border-radius: 8px; font-family: 'Courier New', monospace;">
                ${otp}
              </div>
            </div>
            
            <p style="color: #999; font-size: 14px; text-align: center;">
              ⏱️ This code expires in <strong>5 minutes</strong>
            </p>
            
            <div style="background-color: #f9f9f9; border-left: 4px solid #00C853; padding: 15px; margin: 20px 0; border-radius: 4px;">
              <p style="color: #666; font-size: 14px; margin: 0;">
                🔐 <strong>Security Note:</strong> Never share this code with anyone. GenZFit staff will never ask for your OTP.
              </p>
            </div>
            
            <p style="color: #999; font-size: 12px; text-align: center; margin-top: 30px; border-top: 1px solid #eee; padding-top: 20px;">
              If you didn't request this code, please ignore this email or contact support immediately.
            </p>
            
            <p style="color: #999; font-size: 11px; text-align: center; margin: 10px 0 0 0;">
              © 2026 GenZFit. All rights reserved.
            </p>
          </div>
        </body>
      </html>
    `;

    // Send email
    await transporter.sendMail({
      from: `"GenZFit" <${gmailUser}>`,
      to: email,
      subject: "Your GenZFit Verification Code: " + otp,
      html: htmlContent,
    });

    console.log(`✅ OTP email sent successfully to ${email}`);

    return res.status(200).json({
      success: true,
      message: "OTP email sent successfully",
    });
  } catch (error) {
    console.error("Error sending email:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to send OTP email",
      error: error.message,
    });
  }
});

// Cloud Function to verify OTP
exports.verifyOTP = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  try {
    const { email, otp } = req.body;

    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        message: "Email and OTP are required",
      });
    }

    // Verify OTP (this is now handled on the client-side with Firestore)
    // This function can be extended if needed for server-side verification

    return res.status(200).json({
      success: true,
      message: "OTP verification initiated",
    });
  } catch (error) {
    console.error("Error verifying OTP:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to verify OTP",
      error: error.message,
    });
  }
});

// Push notification for support chat messages (trainer/client <-> admin)
exports.onSupportMessageCreated = functions.firestore
  .document("support_threads/{threadId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    try {
      const message = snapshot.data() || {};
      const threadId = context.params.threadId;
      const messageId = context.params.messageId;

      if (!message.senderId) {
        return null;
      }

      const db = admin.firestore();

      const threadDoc = await db.collection("support_threads").doc(threadId).get();
      if (!threadDoc.exists) {
        return null;
      }

      const thread = threadDoc.data() || {};
      const senderRole = String(message.senderRole || "").toLowerCase();

      let recipientIds = [];

      // Admin -> owner, Owner -> assigned admin (or fallback to active admins/support)
      if (senderRole === "admin") {
        if (thread.ownerId) {
          recipientIds = [thread.ownerId];
        }
      } else {
        if (thread.createdByAdminId) {
          recipientIds = [thread.createdByAdminId];
        } else {
          const adminsSnapshot = await db
            .collection("users")
            .where("role", "in", ["admin", "super_admin", "finance_admin", "moderator", "support"])
            .where("status", "==", "active")
            .limit(20)
            .get();

          recipientIds = adminsSnapshot.docs.map((doc) => doc.id);
        }
      }

      recipientIds = [...new Set(recipientIds)].filter(
        (id) => id && id !== message.senderId,
      );

      if (recipientIds.length === 0) {
        return null;
      }

      const senderDoc = await db.collection("users").doc(message.senderId).get();
      const senderName = senderDoc.data()?.name || "New message";

      const text = (message.text || "").toString().trim();
      const messageType = (message.type || "text").toString();
      let preview = text;
      if (!preview) {
        if (messageType === "image") preview = "📷 Sent an image";
        else if (messageType === "file") preview = "📎 Sent a file";
        else if (messageType === "video") preview = "🎥 Sent a video";
        else preview = "Sent a message";
      }
      if (preview.length > 140) {
        preview = `${preview.substring(0, 137)}...`;
      }

      const jobs = recipientIds.map(async (recipientId) => {
        const [userDoc, prefsDoc] = await Promise.all([
          db.collection("users").doc(recipientId).get(),
          db.collection("user_preferences").doc(recipientId).get(),
        ]);

        if (!userDoc.exists) {
          return;
        }

        const userData = userDoc.data() || {};
        const prefs = prefsDoc.data() || {};

        const notificationsEnabled = prefs.notifications_enabled !== false;
        const messageNotificationsEnabled = prefs.message_notifications !== false;

        if (!notificationsEnabled || !messageNotificationsEnabled) {
          return;
        }

        const fcmToken = userData.fcmToken;
        if (!fcmToken) {
          return;
        }

        try {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: senderName,
              body: preview,
            },
            data: {
              type: "support_chat",
              threadId,
              messageId,
              senderId: String(message.senderId),
              senderRole: String(message.senderRole || ""),
            },
          });
        } catch (sendError) {
          const code = sendError?.code || "";
          if (code === "messaging/registration-token-not-registered") {
            await db.collection("users").doc(recipientId).set(
              { fcmToken: admin.firestore.FieldValue.delete() },
              { merge: true },
            );
          }
          throw sendError;
        }

        await db.collection("notifications").add({
          userId: recipientId,
          type: "support_chat",
          title: senderName,
          message: preview,
          senderId: String(message.senderId),
          threadId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      const results = await Promise.allSettled(jobs);
      const failed = results.filter((r) => r.status === "rejected");
      if (failed.length > 0) {
        console.error("onSupportMessageCreated: some sends failed", failed);
      }

      return null;
    } catch (error) {
      console.error("onSupportMessageCreated error:", error);
      return null;
    }
  });
