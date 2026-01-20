import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Email service using Brevo (formerly Sendinblue) API
/// Free tier: 300 emails/day
///
/// Setup instructions:
/// 1. Create free account at https://www.brevo.com
/// 2. Go to SMTP & API > API Keys
/// 3. Create a new API key
/// 4. Set the API key using EmailService.initialize('your-api-key')
class EmailService {
  static String? _apiKey;
  static String? _senderEmail;
  static String? _senderName;
  static const String _baseUrl = 'https://api.brevo.com/v3';
  static const String _defaultSenderName = 'FairShare';

  /// Initialize the email service with your Brevo API key
  /// Call this in main.dart before runApp()
  ///
  /// IMPORTANT: The senderEmail MUST be verified in your Brevo account!
  /// Go to Brevo Dashboard > Senders, Domains & Dedicated IPs > Add a sender
  static void initialize(String apiKey, {String? senderEmail, String? senderName}) {
    _apiKey = apiKey;
    _senderEmail = senderEmail;
    _senderName = senderName ?? _defaultSenderName;
    debugPrint('EmailService: Initialized with sender: ${_senderEmail ?? "not set"}');
  }

  /// Check if the service is configured
  static bool get isConfigured =>
      _apiKey != null && _apiKey!.isNotEmpty &&
      _senderEmail != null && _senderEmail!.isNotEmpty;

  /// Generate a 6-digit OTP
  static String generateOTP() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Send OTP verification email for new account
  static Future<bool> sendOTPEmail({
    required String recipientEmail,
    required String recipientName,
    required String otp,
  }) async {
    if (!isConfigured) {
      debugPrint('EmailService: Not configured, skipping email');
      return false;
    }

    final subject = 'Your FairShare verification code: $otp';
    final htmlContent = _buildOTPEmailHtml(
      recipientName: recipientName,
      otp: otp,
    );

    return _sendEmail(
      toEmail: recipientEmail,
      toName: recipientName,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send a friend request notification email
  static Future<bool> sendFriendRequestEmail({
    required String recipientEmail,
    required String recipientName,
    required String senderName,
    required String senderEmail,
  }) async {
    if (!isConfigured) {
      debugPrint('EmailService: Not configured, skipping email');
      return false;
    }

    final subject = '$senderName wants to be your friend on FairShare!';
    final htmlContent = _buildFriendRequestEmailHtml(
      recipientName: recipientName,
      senderName: senderName,
      senderEmail: senderEmail,
    );

    return _sendEmail(
      toEmail: recipientEmail,
      toName: recipientName,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send a friend request accepted notification email
  static Future<bool> sendFriendAcceptedEmail({
    required String recipientEmail,
    required String recipientName,
    required String accepterName,
  }) async {
    if (!isConfigured) {
      debugPrint('EmailService: Not configured, skipping email');
      return false;
    }

    final subject = '$accepterName accepted your friend request!';
    final htmlContent = _buildFriendAcceptedEmailHtml(
      recipientName: recipientName,
      accepterName: accepterName,
    );

    return _sendEmail(
      toEmail: recipientEmail,
      toName: recipientName,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Send a new expense notification email
  static Future<bool> sendExpenseNotificationEmail({
    required String recipientEmail,
    required String recipientName,
    required String payerName,
    required String expenseDescription,
    required double amountOwed,
    required String currencySymbol,
  }) async {
    if (!isConfigured) {
      debugPrint('EmailService: Not configured, skipping email');
      return false;
    }

    final subject = '$payerName added an expense: $expenseDescription';
    final htmlContent = _buildExpenseEmailHtml(
      recipientName: recipientName,
      payerName: payerName,
      expenseDescription: expenseDescription,
      amountOwed: amountOwed,
      currencySymbol: currencySymbol,
    );

    return _sendEmail(
      toEmail: recipientEmail,
      toName: recipientName,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  /// Core email sending method using Brevo API
  static Future<bool> _sendEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String htmlContent,
  }) async {
    if (!isConfigured) {
      debugPrint('EmailService: Not configured properly!');
      debugPrint('  - API Key set: ${_apiKey != null && _apiKey!.isNotEmpty}');
      debugPrint('  - Sender Email set: ${_senderEmail != null && _senderEmail!.isNotEmpty}');
      return false;
    }

    try {
      debugPrint('EmailService: Sending email to $toEmail from $_senderEmail');
      debugPrint('EmailService: Subject: $subject');

      final response = await http.post(
        Uri.parse('$_baseUrl/smtp/email'),
        headers: {
          'accept': 'application/json',
          'api-key': _apiKey!,
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'sender': {
            'name': _senderName,
            'email': _senderEmail,
          },
          'to': [
            {
              'email': toEmail,
              'name': toName,
            }
          ],
          'subject': subject,
          'htmlContent': htmlContent,
        }),
      );

      if (response.statusCode == 201) {
        debugPrint('EmailService: Email sent successfully to $toEmail');
        return true;
      } else {
        debugPrint('EmailService: Failed to send email!');
        debugPrint('  - Status code: ${response.statusCode}');
        debugPrint('  - Response body: ${response.body}');
        debugPrint('  - This usually means the sender email is not verified in Brevo');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('EmailService: Exception sending email: $e');
      debugPrint('EmailService: Stack trace: $stackTrace');
      return false;
    }
  }

  /// Build HTML for friend request email
  static String _buildFriendRequestEmailHtml({
    required String recipientName,
    required String senderName,
    required String senderEmail,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 0; background-color: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
    .header { background: linear-gradient(135deg, #6366F1 0%, #8B5CF6 100%); padding: 40px 30px; text-align: center; }
    .header h1 { color: white; margin: 0; font-size: 28px; }
    .header p { color: rgba(255,255,255,0.9); margin: 10px 0 0 0; }
    .content { padding: 40px 30px; }
    .avatar { width: 80px; height: 80px; border-radius: 50%; background: linear-gradient(135deg, #10B981 0%, #059669 100%); color: white; font-size: 32px; line-height: 80px; text-align: center; margin: 0 auto 20px; }
    .message { font-size: 18px; color: #333; line-height: 1.6; text-align: center; }
    .sender { font-weight: 600; color: #6366F1; }
    .cta { display: block; background: linear-gradient(135deg, #6366F1 0%, #8B5CF6 100%); color: white; text-decoration: none; padding: 16px 32px; border-radius: 12px; text-align: center; font-weight: 600; font-size: 16px; margin: 30px auto; max-width: 250px; }
    .footer { background: #f9fafb; padding: 20px 30px; text-align: center; color: #6b7280; font-size: 14px; }
    .emoji { font-size: 48px; margin-bottom: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>FairShare</h1>
      <p>Split expenses with friends, effortlessly</p>
    </div>
    <div class="content">
      <div class="emoji">&#128075;</div>
      <div class="avatar">${senderName[0].toUpperCase()}</div>
      <p class="message">
        Hey $recipientName!<br><br>
        <span class="sender">$senderName</span> ($senderEmail) wants to connect with you on FairShare!
        <br><br>
        Accept their friend request to start splitting expenses together.
      </p>
      <a href="https://fairshare-expense-split.web.app" class="cta">Open FairShare</a>
    </div>
    <div class="footer">
      You received this email because someone sent you a friend request on FairShare.<br>
      &copy; 2024 FairShare App
    </div>
  </div>
</body>
</html>
''';
  }

  /// Build HTML for friend accepted email
  static String _buildFriendAcceptedEmailHtml({
    required String recipientName,
    required String accepterName,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 0; background-color: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
    .header { background: linear-gradient(135deg, #10B981 0%, #059669 100%); padding: 40px 30px; text-align: center; }
    .header h1 { color: white; margin: 0; font-size: 28px; }
    .content { padding: 40px 30px; text-align: center; }
    .emoji { font-size: 64px; margin-bottom: 20px; }
    .message { font-size: 18px; color: #333; line-height: 1.6; }
    .friend-name { font-weight: 600; color: #10B981; }
    .cta { display: block; background: linear-gradient(135deg, #10B981 0%, #059669 100%); color: white; text-decoration: none; padding: 16px 32px; border-radius: 12px; text-align: center; font-weight: 600; font-size: 16px; margin: 30px auto; max-width: 280px; }
    .footer { background: #f9fafb; padding: 20px 30px; text-align: center; color: #6b7280; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>You're now friends! &#127881;</h1>
    </div>
    <div class="content">
      <div class="emoji">&#129309;</div>
      <p class="message">
        Great news, $recipientName!<br><br>
        <span class="friend-name">$accepterName</span> has accepted your friend request on FairShare!
        <br><br>
        You can now easily split expenses together.
      </p>
      <a href="https://fairshare-expense-split.web.app" class="cta">Start Splitting Expenses</a>
    </div>
    <div class="footer">
      &copy; 2024 FairShare App
    </div>
  </div>
</body>
</html>
''';
  }

  /// Build HTML for expense notification email
  static String _buildExpenseEmailHtml({
    required String recipientName,
    required String payerName,
    required String expenseDescription,
    required double amountOwed,
    required String currencySymbol,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 0; background-color: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
    .header { background: linear-gradient(135deg, #F59E0B 0%, #D97706 100%); padding: 30px; text-align: center; }
    .header h1 { color: white; margin: 0; font-size: 24px; }
    .content { padding: 30px; }
    .expense-card { background: #f9fafb; border-radius: 12px; padding: 20px; margin-bottom: 20px; }
    .expense-desc { font-size: 20px; font-weight: 600; color: #333; margin-bottom: 10px; }
    .expense-amount { font-size: 32px; font-weight: 700; color: #DC2626; }
    .message { font-size: 16px; color: #333; line-height: 1.6; }
    .cta { display: block; background: linear-gradient(135deg, #6366F1 0%, #8B5CF6 100%); color: white; text-decoration: none; padding: 14px 28px; border-radius: 12px; text-align: center; font-weight: 600; margin: 20px auto; max-width: 200px; }
    .footer { background: #f9fafb; padding: 20px 30px; text-align: center; color: #6b7280; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>&#128184; New Expense Added</h1>
    </div>
    <div class="content">
      <p class="message">Hey $recipientName, $payerName added a new expense:</p>
      <div class="expense-card">
        <div class="expense-desc">$expenseDescription</div>
        <div class="expense-amount">You owe $currencySymbol${amountOwed.toStringAsFixed(2)}</div>
      </div>
      <a href="https://fairshare-expense-split.web.app" class="cta">View Details</a>
    </div>
    <div class="footer">
      &copy; 2024 FairShare App
    </div>
  </div>
</body>
</html>
''';
  }

  /// Build HTML for OTP verification email
  static String _buildOTPEmailHtml({
    required String recipientName,
    required String otp,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 0; background-color: #f5f5f5; }
    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
    .header { background: linear-gradient(135deg, #6366F1 0%, #8B5CF6 100%); padding: 40px 30px; text-align: center; }
    .header h1 { color: white; margin: 0; font-size: 28px; }
    .header p { color: rgba(255,255,255,0.9); margin: 10px 0 0 0; }
    .content { padding: 40px 30px; text-align: center; }
    .message { font-size: 16px; color: #333; line-height: 1.6; margin-bottom: 30px; }
    .otp-box { background: linear-gradient(135deg, #6366F1 0%, #8B5CF6 100%); border-radius: 16px; padding: 30px; margin: 20px 0; }
    .otp-code { font-size: 42px; font-weight: 700; color: white; letter-spacing: 12px; font-family: monospace; }
    .expires { color: #6b7280; font-size: 14px; margin-top: 20px; }
    .warning { background: #FEF3C7; border: 1px solid #F59E0B; border-radius: 12px; padding: 16px; margin-top: 20px; color: #92400E; font-size: 14px; }
    .footer { background: #f9fafb; padding: 20px 30px; text-align: center; color: #6b7280; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>FairShare</h1>
      <p>Verify your email address</p>
    </div>
    <div class="content">
      <p class="message">
        Hey $recipientName!<br><br>
        Welcome to FairShare! Please use the verification code below to complete your registration:
      </p>
      <div class="otp-box">
        <div class="otp-code">$otp</div>
      </div>
      <p class="expires">This code expires in 10 minutes</p>
      <div class="warning">
        &#9888; If you didn't create a FairShare account, please ignore this email.
      </div>
    </div>
    <div class="footer">
      &copy; 2024 FairShare App
    </div>
  </div>
</body>
</html>
''';
  }
}
