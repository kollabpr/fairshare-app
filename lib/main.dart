import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'services/services.dart';
import 'screens/auth/login_screen.dart';
import 'screens/groups/group_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.bgPrimary,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const FairShareApp());
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
          return const GroupListScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
