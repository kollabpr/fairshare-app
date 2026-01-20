/// App secrets template
/// Copy this file to secrets.dart and fill in your API keys
/// secrets.dart is gitignored for security

class AppSecrets {
  /// Brevo API key for email notifications
  /// Get yours free at https://www.brevo.com
  static const String brevoApiKey = 'YOUR_BREVO_API_KEY_HERE';

  /// Sender email for notifications
  /// IMPORTANT: This email MUST be verified in your Brevo account!
  /// Go to: Brevo Dashboard > Senders, Domains & Dedicated IPs > Add a sender
  /// You can use your personal email (e.g., yourname@gmail.com)
  static const String senderEmail = 'YOUR_VERIFIED_EMAIL_HERE';

  /// Sender name (displayed in email)
  static const String senderName = 'FairShare';
}
