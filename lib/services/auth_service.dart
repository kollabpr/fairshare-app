import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'email_service.dart';

/// Authentication service using Firebase Auth
/// Adapted from finance_app for FairShare
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _firebaseUser;
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _pendingEmailVerification = false;
  String? _pendingEmail;
  String? _pendingDisplayName;

  // Getters
  User? get firebaseUser => _firebaseUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _firebaseUser != null && !_pendingEmailVerification;
  bool get isPendingVerification => _pendingEmailVerification;
  String? get pendingEmail => _pendingEmail;
  String? get userId => _firebaseUser?.uid;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  /// Handle auth state changes
  Future<void> _onAuthStateChanged(User? user) async {
    _firebaseUser = user;

    if (user != null) {
      await _fetchUserProfile(user);
    } else {
      _currentUser = null;
    }

    notifyListeners();
  }

  /// Fetch user profile from Firestore
  Future<void> _fetchUserProfile(User user) async {
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc);
        // Update last login
        await _firestore.collection('users').doc(user.uid).update({
          'lastLogin': Timestamp.now(),
        });
      } else {
        // Create new user profile
        _currentUser = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
        );
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(_currentUser!.toFirestore());
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  /// Sign up with email and password
  /// Returns true if OTP was sent successfully, user needs to verify
  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Validate inputs
      if (email.isEmpty || !email.contains('@')) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Please enter a valid email address',
        );
      }

      // Password validation (relaxed for consumer app)
      final passwordError = _validatePassword(password);
      if (passwordError != null) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: passwordError,
        );
      }

      // IMPORTANT: Set pending verification state BEFORE creating user
      // This prevents the race condition where authStateChanges triggers
      // before we can set the pending flag
      _pendingEmailVerification = true;
      _pendingEmail = email.trim();
      _pendingDisplayName = displayName;

      // Create user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Failed to create user');
      }

      // Update display name if provided
      if (displayName != null && displayName.isNotEmpty) {
        try {
          await user.updateDisplayName(displayName);
        } catch (e) {
          debugPrint('Failed to update display name: $e');
        }
      }

      // Generate and store OTP
      final otp = EmailService.generateOTP();
      final otpExpiry = DateTime.now().add(const Duration(minutes: 10));

      await _firestore.collection('users').doc(user.uid).set({
        'email': email.trim(),
        'displayName': displayName,
        'emailVerified': false,
        'otp': otp,
        'otpExpiry': Timestamp.fromDate(otpExpiry),
        'createdAt': Timestamp.now(),
        'lastLogin': Timestamp.now(),
      });

      // Send OTP email
      final emailSent = await EmailService.sendOTPEmail(
        recipientEmail: email.trim(),
        recipientName: displayName ?? email.split('@').first,
        otp: otp,
      );

      if (!emailSent) {
        debugPrint('Warning: OTP email could not be sent');
      }

      // Pending verification state already set before user creation
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      // Reset pending verification state on error
      _pendingEmailVerification = false;
      _pendingEmail = null;
      _pendingDisplayName = null;
      _error = _getAuthErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      // Reset pending verification state on error
      _pendingEmailVerification = false;
      _pendingEmail = null;
      _pendingDisplayName = null;
      _error = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify OTP and complete registration
  Future<bool> verifyOTP(String enteredOTP) async {
    if (_firebaseUser == null) {
      _error = 'No user session found. Please sign up again.';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Get stored OTP from Firestore
      final userDoc = await _firestore.collection('users').doc(_firebaseUser!.uid).get();

      if (!userDoc.exists) {
        _error = 'User data not found. Please sign up again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final data = userDoc.data()!;
      final storedOTP = data['otp'] as String?;
      final otpExpiry = (data['otpExpiry'] as Timestamp?)?.toDate();

      // Check if OTP exists
      if (storedOTP == null || otpExpiry == null) {
        _error = 'No verification code found. Please request a new one.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check if OTP expired
      if (DateTime.now().isAfter(otpExpiry)) {
        _error = 'Verification code has expired. Please request a new one.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Verify OTP
      if (enteredOTP != storedOTP) {
        _error = 'Invalid verification code. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // OTP is valid - mark email as verified
      await _firestore.collection('users').doc(_firebaseUser!.uid).update({
        'emailVerified': true,
        'otp': FieldValue.delete(),
        'otpExpiry': FieldValue.delete(),
      });

      // Clear pending verification state
      _pendingEmailVerification = false;
      _pendingEmail = null;
      _pendingDisplayName = null;

      // Fetch full user profile
      await _fetchUserProfile(_firebaseUser!);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Verification failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Resend OTP verification email
  Future<bool> resendOTP() async {
    if (_firebaseUser == null || _pendingEmail == null) {
      _error = 'No pending verification. Please sign up again.';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Generate new OTP
      final otp = EmailService.generateOTP();
      final otpExpiry = DateTime.now().add(const Duration(minutes: 10));

      // Update OTP in Firestore
      await _firestore.collection('users').doc(_firebaseUser!.uid).update({
        'otp': otp,
        'otpExpiry': Timestamp.fromDate(otpExpiry),
      });

      // Send OTP email
      final emailSent = await EmailService.sendOTPEmail(
        recipientEmail: _pendingEmail!,
        recipientName: _pendingDisplayName ?? _pendingEmail!.split('@').first,
        otp: otp,
      );

      _isLoading = false;
      notifyListeners();

      if (!emailSent) {
        _error = 'Failed to send verification email. Please try again.';
        return false;
      }

      return true;
    } catch (e) {
      _error = 'Failed to resend code. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cancel pending verification and sign out
  Future<void> cancelVerification() async {
    if (_firebaseUser != null) {
      try {
        // Delete the unverified user document
        await _firestore.collection('users').doc(_firebaseUser!.uid).delete();
        // Delete the Firebase Auth user
        await _firebaseUser!.delete();
      } catch (e) {
        debugPrint('Error cleaning up unverified user: $e');
      }
    }

    _pendingEmailVerification = false;
    _pendingEmail = null;
    _pendingDisplayName = null;
    await signOut();
  }

  /// Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final trimmedEmail = email.trim();

      // First, check if the user exists by fetching sign-in methods
      // This helps provide more specific error messages
      final signInMethods = await _auth.fetchSignInMethodsForEmail(trimmedEmail);

      if (signInMethods.isEmpty) {
        // No account exists with this email
        _error = 'No account exists with this email.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Account exists, try to sign in
      await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      // If we get here after checking user exists, it's likely a wrong password
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS') {
        _error = 'Incorrect password. Please try again.';
      } else if (e.code == 'user-not-found') {
        _error = 'No account exists with this email.';
      } else {
        _error = _getAuthErrorMessage(e.code);
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _auth.signOut();

      _firebaseUser = null;
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to sign out. Please try again.';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _auth.sendPasswordResetEmail(email: email.trim());

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getAuthErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to send reset email. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? displayName,
    String? photoUrl,
    String? defaultCurrency,
  }) async {
    if (_currentUser == null) return false;

    try {
      _isLoading = true;
      notifyListeners();

      final updates = <String, dynamic>{};
      if (displayName != null) updates['displayName'] = displayName;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      if (defaultCurrency != null) updates['defaultCurrency'] = defaultCurrency;

      await _firestore.collection('users').doc(_currentUser!.uid).update(updates);

      // Update local model
      _currentUser = _currentUser!.copyWith(
        displayName: displayName ?? _currentUser!.displayName,
        defaultCurrency: defaultCurrency ?? _currentUser!.defaultCurrency,
      );

      // Update Firebase Auth display name
      if (displayName != null) {
        await _firebaseUser?.updateDisplayName(displayName);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update profile.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Validate password with security requirements
  String? _validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    // Check for common weak passwords
    final weakPasswords = ['password', '12345678', 'qwerty123', 'letmein'];
    if (weakPasswords.any((weak) => password.toLowerCase().contains(weak))) {
      return 'Please choose a stronger password';
    }
    return null;
  }

  /// Get user-friendly error message
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account exists with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'operation-not-allowed':
        return 'Email/password sign in is not enabled.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Invalid email or password.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        debugPrint('Unknown auth error code: $code');
        return 'Authentication failed. Please try again.';
    }
  }
}
