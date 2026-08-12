import fs from "fs";
import path from "path";

export class NotificationService {
  private logPath = path.resolve(process.cwd(), "../../invitations_sent.txt");

  async sendInvitation(params: {
    email: string;
    phone?: string;
    role: string;
    inviteLink: string;
  }) {
    const timestamp = new Date().toISOString();
    const emailBody = `
========================================
EMAIL INVITATION [${timestamp}]
To: ${params.email}
Role: ${params.role}
Message: Welcome to Schore! Please click the link below to set up your account credentials.
Activation Link: ${params.inviteLink}
========================================
`;

    const smsBody = params.phone
      ? `
----------------------------------------
SMS INVITATION [${timestamp}]
To: ${params.phone}
Message: Welcome to Schore! Activate your account here: ${params.inviteLink}
----------------------------------------
`
      : "";

    const logEntry = `${emailBody}${smsBody}\n`;

    // Print to server console
    console.log(logEntry);

    // Append to file in workspace root
    try {
      fs.appendFileSync(this.logPath, logEntry, "utf8");
    } catch (err) {
      console.error("Failed to write invitation log to file:", err);
    }
  }
}
