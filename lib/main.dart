import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'config/app_theme.dart';
import 'config/secrets.dart';
import 'services/services.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/main_screen.dart';

/// Global error message for displaying startup errors
String? _startupError;

void main() async {
  // Catch all errors during initialization
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Set up Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('Failed to load font') ||
          details.exceptionAsString().contains('network')) {
        debugPrint('Font loading error (handled gracefully): ${details.exception}');
        return;
      }
      FlutterError.presentError(details);
      _startupError = details.exceptionAsString();
    };

    try {
      // Initialize Firebase with generated options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize Brevo email service (300 emails/day free)
      // IMPORTANT: senderEmail MUST be verified in Brevo dashboard
      EmailService.initialize(
        AppSecrets.brevoApiKey,
        senderEmail: AppSecrets.senderEmail,
        senderName: AppSecrets.senderName,
      );
    } catch (e) {
      debugPrint('Firebase init error: $e');
      // Don't crash - app will show error on login attempt
    }

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.bgPrimary,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    runApp(const FairShareApp());
  }, (error, stackTrace) {
    // Handle errors gracefully
    final errorStr = error.toString();
    if (errorStr.contains('Failed to load font') ||
        errorStr.contains('network') ||
        errorStr.contains('SocketException')) {
      debugPrint('Network error during startup (handled gracefully): $error');
      runApp(const FairShareApp());
      return;
    }

    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stackTrace');
    _startupError = error.toString();
    runApp(ErrorApp(error: error.toString()));
  });
}

/// Error app to display when startup fails
class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: AppTheme.bgPrimary,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'App Startup Error',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      error,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FairShareApp extends StatelessWidget {
  const FairShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core services
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => GroupsService()),
        ChangeNotifierProvider(create: (_) => ExpensesService()),
        ChangeNotifierProvider(create: (_) => ActivityService()),

        // Non-notifier services
        Provider(create: (_) => SplittingService()),
        Provider(create: (_) => OCRService()),

        // CSV Import Service (depends on others)
        ProxyProvider3<GroupsService, ExpensesService, SplittingService, CSVImportService>(
          update: (_, groups, expenses, splitting, __) => CSVImportService(
            groupsService: groups,
            expensesService: expenses,
            splittingService: splitting,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'FairShare',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Wrapper that shows login or home based on auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        // Show loading while checking auth state
        if (auth.firebaseUser == null && auth.isLoading) {
          return const Scaffold(
            backgroundColor: AppTheme.bgPrimary,
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.accentPrimary,
              ),
            ),
          );
        }

        // Show home if authenticated, login if not
        if (auth.isAuthenticated) {
          return const MainScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
