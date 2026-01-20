/**
 * FairShare Cloud Functions
 * Handles email notifications for friend requests and other events
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// Configure email transporter
// For production, use environment variables:
// firebase functions:config:set email.user="your-email@gmail.com" email.pass="your-app-password"
const getMailTransporter = () => {
  const emailConfig = functions.config().email;

  if (!emailConfig || !emailConfig.user || !emailConfig.pass) {
    console.warn("Email configuration not set. Use: firebase functions:config:set email.user=\"your-email\" email.pass=\"your-app-password\"");
    return null;
  }

  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: emailConfig.user,
      pass: emailConfig.pass,
    },
  });
};

/**
 * Send email notification when a friend request is received
 * Triggers when a new document is created in /users/{userId}/friends
 */
exports.onFriendRequestCreated = functions.firestore
  .document("users/{userId}/friends/{friendId}")
  .onCreate(async (snap, context) => {
    const friendData = snap.data();
    const recipientUserId = context.params.userId;

    // Only send email for incoming pending requests
    if (friendData.status !== "pending" || friendData.requestedBy === recipientUserId) {
      console.log("Not a new incoming request, skipping email");
      return null;
    }

    try {
      // Get recipient user's email
      const recipientDoc = await admin.firestore()
        .collection("users")
        .doc(recipientUserId)
        .get();

      if (!recipientDoc.exists) {
        console.log("Recipient user not found");
        return null;
      }

      const recipientEmail = recipientDoc.data().email;
      const recipientName = recipientDoc.data().displayName || recipientEmail.split("@")[0];

      // Get sender's info from the friend request
      const senderName = friendData.friendName || friendData.friendEmail.split("@")[0];
      const senderEmail = friendData.friendEmail;

      // Send the email
      const transporter = getMailTransporter();
      if (!transporter) {
        console.log("Email transporter not configured, skipping email");
        return null;
      }

      const mailOptions = {
        from: "FairShare App <noreply@fairshare.app>",
        to: recipientEmail,
        subject: `${senderName} wants to be your friend on FairShare! 🎉`,
        html: `
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
              .cta:hover { opacity: 0.9; }
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
                <div class="emoji">👋</div>
                <div class="avatar">${senderName.charAt(0).toUpperCase()}</div>
                <p class="message">
                  Hey ${recipientName}!<br><br>
                  <span class="sender">${senderName}</span> (${senderEmail}) wants to connect with you on FairShare!
                  <br><br>
                  Accept their friend request to start splitting expenses together.
                </p>
                <a href="https://fairshare-expense-split.web.app" class="cta">Open FairShare</a>
              </div>
              <div class="footer">
                You received this email because someone sent you a friend request on FairShare.<br>
                © 2024 FairShare App
              </div>
            </div>
          </body>
          </html>
        `,
        text: `Hey ${recipientName}!\n\n${senderName} (${senderEmail}) wants to connect with you on FairShare!\n\nAccept their friend request to start splitting expenses together.\n\nOpen FairShare: https://fairshare-expense-split.web.app`,
      };

      await transporter.sendMail(mailOptions);
      console.log(`Friend request email sent to ${recipientEmail}`);

      return null;
    } catch (error) {
      console.error("Error sending friend request email:", error);
      return null;
    }
  });

/**
 * Send email notification when a friend request is accepted
 */
exports.onFriendRequestAccepted = functions.firestore
  .document("users/{userId}/friends/{friendId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Check if status changed from pending to accepted
    if (before.status !== "pending" || after.status !== "accepted") {
      return null;
    }

    const accepterUserId = context.params.userId;

    try {
      // Get the person who originally sent the request (the one being notified)
      const originalSenderId = after.friendUserId;

      // Get accepter's info
      const accepterDoc = await admin.firestore()
        .collection("users")
        .doc(accepterUserId)
        .get();

      if (!accepterDoc.exists) return null;

      const accepterName = accepterDoc.data().displayName || accepterDoc.data().email.split("@")[0];

      // Get original sender's info
      const senderDoc = await admin.firestore()
        .collection("users")
        .doc(originalSenderId)
        .get();

      if (!senderDoc.exists) return null;

      const senderEmail = senderDoc.data().email;
      const senderName = senderDoc.data().displayName || senderEmail.split("@")[0];

      const transporter = getMailTransporter();
      if (!transporter) return null;

      const mailOptions = {
        from: "FairShare App <noreply@fairshare.app>",
        to: senderEmail,
        subject: `${accepterName} accepted your friend request! 🎊`,
        html: `
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
                <h1>You're now friends! 🎉</h1>
              </div>
              <div class="content">
                <div class="emoji">🤝</div>
                <p class="message">
                  Great news, ${senderName}!<br><br>
                  <span class="friend-name">${accepterName}</span> has accepted your friend request on FairShare!
                  <br><br>
                  You can now easily split expenses together.
                </p>
                <a href="https://fairshare-expense-split.web.app" class="cta">Start Splitting Expenses</a>
              </div>
              <div class="footer">
                © 2024 FairShare App
              </div>
            </div>
          </body>
          </html>
        `,
        text: `Great news, ${senderName}!\n\n${accepterName} has accepted your friend request on FairShare!\n\nYou can now easily split expenses together.\n\nOpen FairShare: https://fairshare-expense-split.web.app`,
      };

      await transporter.sendMail(mailOptions);
      console.log(`Friend accepted email sent to ${senderEmail}`);

      return null;
    } catch (error) {
      console.error("Error sending friend accepted email:", error);
      return null;
    }
  });

/**
 * Send email notification for new expenses
 */
exports.onDirectExpenseCreated = functions.firestore
  .document("directExpenses/{expenseId}")
  .onCreate(async (snap, context) => {
    const expense = snap.data();

    try {
      // Notify the participant (not the payer) about the new expense
      const participantId = expense.participantId;
      const payerId = expense.payerId;

      // Get participant's email
      const participantDoc = await admin.firestore()
        .collection("users")
        .doc(participantId)
        .get();

      if (!participantDoc.exists) return null;

      const participantEmail = participantDoc.data().email;
      const participantName = participantDoc.data().displayName || participantEmail.split("@")[0];

      const payerName = expense.payerName || expense.payerEmail.split("@")[0];
      const amount = expense.participantOwedAmount.toFixed(2);
      const currency = expense.currencyCode || "USD";
      const currencySymbol = currency === "USD" ? "$" : currency === "EUR" ? "€" : currency === "GBP" ? "£" : "$";

      const transporter = getMailTransporter();
      if (!transporter) return null;

      const mailOptions = {
        from: "FairShare App <noreply@fairshare.app>",
        to: participantEmail,
        subject: `${payerName} added an expense: ${expense.description}`,
        html: `
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
              .expense-meta { color: #6b7280; font-size: 14px; margin-top: 10px; }
              .message { font-size: 16px; color: #333; line-height: 1.6; }
              .cta { display: block; background: linear-gradient(135deg, #6366F1 0%, #8B5CF6 100%); color: white; text-decoration: none; padding: 14px 28px; border-radius: 12px; text-align: center; font-weight: 600; margin: 20px auto; max-width: 200px; }
              .footer { background: #f9fafb; padding: 20px 30px; text-align: center; color: #6b7280; font-size: 14px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h1>💸 New Expense Added</h1>
              </div>
              <div class="content">
                <p class="message">Hey ${participantName}, ${payerName} added a new expense:</p>
                <div class="expense-card">
                  <div class="expense-desc">${expense.description}</div>
                  <div class="expense-amount">You owe ${currencySymbol}${amount}</div>
                  <div class="expense-meta">Category: ${expense.category || "Other"}</div>
                </div>
                <a href="https://fairshare-expense-split.web.app" class="cta">View Details</a>
              </div>
              <div class="footer">
                © 2024 FairShare App
              </div>
            </div>
          </body>
          </html>
        `,
        text: `Hey ${participantName}, ${payerName} added a new expense:\n\n${expense.description}\nYou owe: ${currencySymbol}${amount}\n\nOpen FairShare: https://fairshare-expense-split.web.app`,
      };

      await transporter.sendMail(mailOptions);
      console.log(`Expense notification sent to ${participantEmail}`);

      return null;
    } catch (error) {
      console.error("Error sending expense notification:", error);
      return null;
    }
  });
