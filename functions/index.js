const functions = require("firebase-functions");
const nodemailer = require("nodemailer");

// Configure your email service here
// Option 1: Gmail
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_APP_PASSWORD, // Use app-specific password, not main password
  },
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
      from: '"GenZFit" <noreply@genzfit.com>',
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
