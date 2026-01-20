import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// FairShare Gen Z Inspired Theme
/// Design System: Dark mode with vibrant neon accents and glassmorphism
class AppTheme {
  // ============================================
  // GEN Z INSPIRED COLOR PALETTE
  // Vibrant, energetic, and modern
  // ============================================

  // Background colors - Deep, rich dark palette
  static const Color bgPrimary = Color(0xFF0A0A0F);
  static const Color bgSecondary = Color(0xFF12121A);
  static const Color bgTertiary = Color(0xFF1A1A25);
  static const Color bgCard = Color(0xFF151520);
  static const Color bgCardLight = Color(0xFF1E1E2D);
  static const Color bgSurface = Color(0xFF13131D);

  // Neon accent colors - Vibrant Gen Z palette
  static const Color accentPrimary = Color(0xFF00F5A0); // Neon mint
  static const Color accentSecondary = Color(0xFF00D9FF); // Neon cyan
  static const Color accentBlue = Color(0xFF6366F1); // Electric indigo
  static const Color accentGreen = Color(0xFF10B981); // Emerald
  static const Color accentOrange = Color(0xFFFF6B35); // Hot coral
  static const Color accentPink = Color(0xFFFF2D92); // Hot pink
  static const Color accentPurple = Color(0xFFA855F7); // Electric purple
  static const Color accentYellow = Color(0xFFFBBF24); // Bright yellow
  static const Color accentRed = Color(0xFFFF4757); // Coral red

  // Gradient colors for Gen Z vibes
  static const Color gradientPurpleStart = Color(0xFF8B5CF6);
  static const Color gradientPurpleEnd = Color(0xFFEC4899);
  static const Color gradientBlueStart = Color(0xFF06B6D4);
  static const Color gradientBlueEnd = Color(0xFF3B82F6);
  static const Color gradientGreenStart = Color(0xFF00F5A0);
  static const Color gradientGreenEnd = Color(0xFF00D9FF);
  static const Color gradientSunsetStart = Color(0xFFFF6B35);
  static const Color gradientSunsetEnd = Color(0xFFFF2D92);

  // Text colors - High contrast for readability
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70% white
  static const Color textMuted = Color(0x80FFFFFF); // 50% white
  static const Color textDim = Color(0x4DFFFFFF); // 30% white

  // Status colors
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFFF4757);
  static const Color warningColor = Color(0xFFFBBF24);
  static const Color infoColor = Color(0xFF06B6D4);

  // Split colors - Who owes / who gets back
  static const Color owesColor = Color(0xFFFF4757); // Red - you owe
  static const Color getBackColor = Color(0xFF00F5A0); // Neon green - you get back
  static const Color settledColor = Color(0xFF6B7280); // Gray - settled

  // Income/Expense colors
  static const Color incomeColor = Color(0xFF00F5A0);
  static const Color expenseColor = Color(0xFFFF4757);

  // Border colors
  static const Color borderColor = Color(0x14FFFFFF); // 8% white
  static const Color borderLight = Color(0x1FFFFFFF); // 12% white

  // Glassmorphism colors
  static const Color glassColor = Color(0x1AFFFFFF); // 10% white
  static const Color glassBorder = Color(0x33FFFFFF); // 20% white

  // Legacy aliases
  static const Color primaryColor = accentPrimary;
  static const Color backgroundColor = bgPrimary;
  static const Color cardColor = bgCard;
  static const Color surfaceColor = bgSurface;

  // ============================================
  // GEN Z GRADIENTS
  // ============================================

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentPrimary, accentSecondary],
  );

  /// Purple to pink gradient (TikTok vibes)
  static const LinearGradient purplePinkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientPurpleStart, gradientPurpleEnd],
  );

  /// Blue to cyan gradient (Instagram vibes)
  static const LinearGradient blueCyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientBlueStart, gradientBlueEnd],
  );

  /// Neon green gradient
  static const LinearGradient neonGreenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientGreenStart, gradientGreenEnd],
  );

  /// Sunset gradient (coral to pink)
  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientSunsetStart, gradientSunsetEnd],
  );

  /// Gradient for balance card and primary buttons
  static LinearGradient get balanceGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgSecondary, bgTertiary],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgPrimary, bgSecondary],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgCard, bgCardLight],
  );

  /// Glassmorphism gradient overlay
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x20FFFFFF),
      Color(0x08FFFFFF),
    ],
  );

  /// Animated border gradient colors
  static const List<Color> animatedBorderColors = [
    accentPurple,
    accentPink,
    accentOrange,
    accentYellow,
    accentGreen,
    accentSecondary,
    accentBlue,
    accentPurple,
  ];

  static LinearGradient glowGradient(Color color) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
  );

  // ============================================
  // SHADOWS & GLOW EFFECTS
  // ============================================

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get cardShadowLight => [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.4),
      blurRadius: 30,
      spreadRadius: -5,
    ),
  ];

  /// Neon glow effect
  static List<BoxShadow> neonGlow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.6),
      blurRadius: 20,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: color.withOpacity(0.3),
      blurRadius: 40,
      spreadRadius: -5,
    ),
  ];

  static List<BoxShadow> get accentGlow => [
    BoxShadow(
      color: accentPrimary.withOpacity(0.4),
      blurRadius: 40,
      spreadRadius: -5,
    ),
  ];

  // ============================================
  // BORDER RADIUS CONSTANTS
  // ============================================
  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 20;
  static const double radiusXL = 24;
  static const double radiusXXL = 32;

  // ============================================
  // THEME DATA
  // ============================================

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: accentPrimary,
        secondary: accentBlue,
        surface: bgSurface,
        error: errorColor,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      scaffoldBackgroundColor: bgPrimary,
      appBarTheme: AppBarTheme(
        backgroundColor: bgPrimary,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardTheme(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: borderColor),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -1.5,
          height: 1.1,
        ),
        displayMedium: GoogleFonts.spaceGrotesk(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -1,
          height: 1.1,
        ),
        displaySmall: GoogleFonts.spaceGrotesk(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
          height: 1.1,
        ),
        headlineLarge: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.25,
        ),
        headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textSecondary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textMuted,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textMuted,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentPrimary,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ).copyWith(
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 0;
            return 0;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgCardLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: accentPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: GoogleFonts.inter(
          color: textMuted,
          fontSize: 15,
        ),
        labelStyle: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgCard,
        selectedItemColor: accentPrimary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgCard,
        indicatorColor: accentPrimary.withOpacity(0.1),
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bgCardLight,
        selectedColor: accentPrimary.withOpacity(0.15),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgCardLight,
        contentTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: bgCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXL),
        ),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bgCard,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentPrimary,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: CircleBorder(),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentPrimary,
        linearTrackColor: borderColor,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentPrimary,
        inactiveTrackColor: borderLight,
        thumbColor: accentPrimary,
        overlayColor: accentPrimary.withOpacity(0.1),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentPrimary;
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentPrimary.withOpacity(0.3);
          }
          return borderLight;
        }),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: accentPrimary,
        unselectedLabelColor: textMuted,
        indicatorColor: accentPrimary,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static ThemeData get lightTheme => darkTheme;

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Get color based on balance (positive = get back, negative = owes)
  static Color getBalanceColor(double balance) {
    if (balance > 0.01) return getBackColor;
    if (balance < -0.01) return owesColor;
    return settledColor;
  }

  /// Format balance with "you owe" or "you get back"
  static String getBalanceText(double balance) {
    if (balance > 0.01) return 'gets back';
    if (balance < -0.01) return 'owes';
    return 'settled up';
  }

  /// Get emoji for balance status (Gen Z style)
  static String getBalanceEmoji(double balance) {
    if (balance > 100) return '🤑';
    if (balance > 0.01) return '💰';
    if (balance < -100) return '😱';
    if (balance < -0.01) return '💸';
    return '✨';
  }

  /// Get color for expense category
  static Color getCategoryColor(String category) {
    final categoryColors = {
      'food': accentOrange,
      'dining': accentOrange,
      'groceries': accentGreen,
      'shopping': accentPink,
      'entertainment': accentPurple,
      'transportation': accentBlue,
      'travel': accentSecondary,
      'utilities': gradientBlueStart,
      'rent': accentPrimary,
      'bills': accentPrimary,
      'health': accentRed,
      'other': textMuted,
    };

    final key = category.toLowerCase();
    for (final entry in categoryColors.entries) {
      if (key.contains(entry.key)) {
        return entry.value;
      }
    }
    return textMuted;
  }

  /// Get icon for expense category
  static IconData getCategoryIcon(String category) {
    final categoryIcons = {
      'food': Icons.restaurant_rounded,
      'dining': Icons.restaurant_rounded,
      'groceries': Icons.shopping_cart_rounded,
      'shopping': Icons.shopping_bag_rounded,
      'entertainment': Icons.movie_rounded,
      'transportation': Icons.directions_car_rounded,
      'travel': Icons.flight_rounded,
      'utilities': Icons.bolt_rounded,
      'rent': Icons.home_rounded,
      'bills': Icons.receipt_long_rounded,
      'health': Icons.health_and_safety_rounded,
      'other': Icons.category_rounded,
    };

    final key = category.toLowerCase();
    for (final entry in categoryIcons.entries) {
      if (key.contains(entry.key)) {
        return entry.value;
      }
    }
    return Icons.category_rounded;
  }

  /// Get a random gradient for visual variety
  static LinearGradient getRandomGradient(int seed) {
    final gradients = [
      purplePinkGradient,
      blueCyanGradient,
      neonGreenGradient,
      sunsetGradient,
    ];
    return gradients[seed % gradients.length];
  }
}

// ============================================
// PREMIUM UI COMPONENTS
// ============================================
// NOTE: GlassCard and BalanceBadge widgets moved to lib/widgets/common/
// Import from '../../widgets/widgets.dart' instead

/// Gradient text
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient? gradient;

  const GradientText({
    super.key,
    required this.text,
    this.style,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => (gradient ?? const LinearGradient(
        colors: [AppTheme.accentPrimary, AppTheme.accentSecondary],
      )).createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style),
    );
  }
}
