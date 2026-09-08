import fs from "fs";
import path from "path";
import nodemailer from "nodemailer";

export class NotificationService {
  private logPath = path.resolve(process.cwd(), "../../invitations_sent.txt");

  private async getTransporter() {
    const host = process.env.SMTP_HOST || "smtp.gmail.com";
    const port = process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT, 10) : 587;
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;

    if (user && pass && user !== "placeholder@gmail.com") {
      return nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        auth: { user, pass },
      });
    }

    // Dynamic Ethereal mail account creation for local testing/development fallback
    try {
      const testAccount = await nodemailer.createTestAccount();
      return nodemailer.createTransport({
        host: "smtp.ethereal.email",
        port: 587,
        secure: false,
        auth: {
          user: testAccount.user,
          pass: testAccount.pass,
        },
      });
    } catch (e) {
      console.warn("Failed to create Ethereal test SMTP account. Falling back to console-only logs:", e);
      return null;
    }
  }

  async sendInvitation(params: {
    email: string;
    phone?: string;
    role: string;
    inviteLink: string;
  }) {
    const timestamp = new Date().toISOString();
    const emailBodyText = `
========================================
EMAIL INVITATION [${timestamp}]
To: ${params.email}
Role: ${params.role}
Message: Welcome to Schore! Please click the link below to set up your account credentials.
Activation Link: ${params.inviteLink}
========================================
`;

    const smsBodyText = params.phone
      ? `
----------------------------------------
SMS INVITATION [${timestamp}]
To: ${params.phone}
Message: Welcome to Schore! Activate your account here: ${params.inviteLink}
----------------------------------------
`
      : "";

    const logEntry = `${emailBodyText}${smsBodyText}\n`;

    // 1. Print to server console
    console.log(logEntry);

    // 2. Append to workspaces file logs
    try {
      fs.appendFileSync(this.logPath, logEntry, "utf8");
    } catch (err) {
      console.error("Failed to write invitation log to file:", err);
    }

    // 3. Deliver actual SMTP email via Nodemailer
    try {
      const transporter = await this.getTransporter();
      if (!transporter) return;

      const fromAddress = process.env.SMTP_FROM || '"Schore Support" <no-reply@schore.internal>';

      const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Welcome to Schore</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 40px 20px; }
    .card { max-width: 580px; background-color: #ffffff; border-radius: 16px; padding: 40px; box-shadow: 0 4px 20px rgba(0,0,0,0.04); margin: 0 auto; border: 1px solid #f1f5f9; }
    .logo { text-align: center; font-size: 28px; font-weight: 800; color: #1e3a8a; letter-spacing: -0.5px; margin-bottom: 30px; }
    .header { font-size: 22px; font-weight: 700; color: #0f172a; margin-bottom: 16px; text-align: center; }
    .body { font-size: 15px; color: #475569; line-height: 1.6; margin-bottom: 24px; text-align: center; }
    .button-container { text-align: center; margin: 35px 0; }
    .button { background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%); color: #ffffff !important; padding: 14px 35px; text-decoration: none; border-radius: 10px; font-weight: 600; font-size: 15px; display: inline-block; box-shadow: 0 4px 12px rgba(37, 99, 235, 0.2); }
    .link-display { font-size: 13px; color: #64748b; background-color: #f8fafc; padding: 12px; border-radius: 8px; border: 1px dashed #e2e8f0; margin-top: 25px; word-break: break-all; text-align: center; }
    .footer { font-size: 12px; color: #94a3b8; text-align: center; margin-top: 40px; border-top: 1px solid #f1f5f9; padding-top: 20px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">SCHORE</div>
    <div class="header">Activate Your Account</div>
    <div class="body">
      Hello,<br><br>
      You have been registered as a <strong>${params.role}</strong> on the Schore portal. Click the button below to set up your password and complete your secure profile onboarding.
    </div>
    <div class="button-container">
      <a href="${params.inviteLink}" target="_blank" class="button">Activate Account</a>
    </div>
    <div class="body">
      If the button above does not work, please copy and paste the link below directly into your web browser:
    </div>
    <div class="link-display">
      <a href="${params.inviteLink}" style="color: #2563eb; text-decoration: none;">${params.inviteLink}</a>
    </div>
    <div class="footer">
      This is an automated system message. Please do not reply to this email.
    </div>
  </div>
</body>
</html>
`;

      const mailOptions = {
        from: fromAddress,
        to: params.email,
        subject: "Welcome to Schore! Activate Your Account",
        text: `Welcome to Schore! Please click the link to activate your account as a ${params.role}: ${params.inviteLink}`,
        html: htmlContent,
      };

      const info = await transporter.sendMail(mailOptions);
      console.log(`[SMTP Email Sent] Message ID: ${info.messageId}`);
      
      // If using ethereal email test account, output preview URL
      const previewUrl = nodemailer.getTestMessageUrl(info);
      if (previewUrl) {
        console.log(`[Ethereal Sandbox Email Preview URL]: ${previewUrl}`);
      }
    } catch (smtpErr) {
      console.error("Failed to send invitation email via Nodemailer:", smtpErr);
    }
  }
}
