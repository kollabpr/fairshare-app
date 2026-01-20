import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../config/app_animations.dart';

/// A Gen Z inspired stylish avatar with gradient ring, status indicator,
/// and tap animations.
class FriendAvatar extends StatefulWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final bool showOnlineStatus;
  final bool isOnline;
  final bool showGradientRing;
  final Gradient? ringGradient;
  final VoidCallback? onTap;
  final bool enableTapAnimation;
  final Color? backgroundColor;
  final double? balance;

  const FriendAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 56,
    this.showOnlineStatus = false,
    this.isOnline = false,
    this.showGradientRing = true,
    this.ringGradient,
    this.onTap,
    this.enableTapAnimation = true,
    this.backgroundColor,
    this.balance,
  });

  @override
  State<FriendAvatar> createState() => _FriendAvatarState();
}

class _FriendAvatarState extends State<FriendAvatar>
    with TickerProviderStateMixin {
  late AnimationController _tapController;
  late AnimationController _ringController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();

    _tapController = AnimationController(
      vsync: this,
      duration: AppAnimations.fast,
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );

    _ringAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.linear),
    );

    if (widget.showGradientRing) {
      _ringController.repeat();
    }
  }

  @override
  void didUpdateWidget(FriendAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showGradientRing && !_ringController.isAnimating) {
      _ringController.repeat();
    } else if (!widget.showGradientRing && _ringController.isAnimating) {
      _ringController.stop();
    }
  }

  @override
  void dispose() {
    _tapController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  String get _initials {
    final parts = widget.name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
  }

  Color _getBackgroundColor() {
    if (widget.backgroundColor != null) return widget.backgroundColor!;

    // Generate consistent color based on name
    final colors = [
      AppTheme.accentPurple,
      AppTheme.accentPink,
      AppTheme.accentBlue,
      AppTheme.accentOrange,
      AppTheme.accentSecondary,
      AppTheme.accentGreen,
    ];

    final index = widget.name.hashCode.abs() % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor();
    final ringGradient = widget.ringGradient ??
        LinearGradient(
          colors: [
            bgColor,
            bgColor.withOpacity(0.5),
            AppTheme.accentPink,
            bgColor,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        );

    return GestureDetector(
      onTapDown: widget.enableTapAnimation && widget.onTap != null
          ? (_) => _tapController.forward()
          : null,
      onTapUp: widget.enableTapAnimation && widget.onTap != null
          ? (_) => _tapController.reverse()
          : null,
      onTapCancel: widget.enableTapAnimation && widget.onTap != null
          ? () => _tapController.reverse()
          : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _ringAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: widget.enableTapAnimation ? _scaleAnimation.value : 1.0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Gradient ring
                if (widget.showGradientRing)
                  _buildGradientRing(ringGradient)
                else
                  _buildSimpleRing(bgColor),

                // Avatar content
                Positioned(
                  left: 3,
                  top: 3,
                  child: _buildAvatarContent(bgColor),
                ),

                // Online status indicator
                if (widget.showOnlineStatus)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: _buildStatusIndicator(),
                  ),

                // Balance indicator
                if (widget.balance != null && widget.balance!.abs() > 0.01)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: _buildBalanceIndicator(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradientRing(Gradient gradient) {
    return Container(
      width: widget.size + 6,
      height: widget.size + 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          startAngle: _ringAnimation.value * 2 * 3.14159,
          colors: AppTheme.animatedBorderColors,
        ),
        boxShadow: [
          BoxShadow(
            color: _getBackgroundColor().withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleRing(Color color) {
    return Container(
      width: widget.size + 6,
      height: widget.size + 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildAvatarContent(Color bgColor) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bgColor.withOpacity(0.3),
            bgColor.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: AppTheme.bgPrimary,
          width: 2,
        ),
      ),
      child: widget.imageUrl != null
          ? ClipOval(
              child: Image.network(
                widget.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildInitials(bgColor),
              ),
            )
          : _buildInitials(bgColor),
    );
  }

  Widget _buildInitials(Color bgColor) {
    return Center(
      child: Text(
        _initials,
        style: GoogleFonts.spaceGrotesk(
          fontSize: widget.size * 0.35,
          fontWeight: FontWeight.w700,
          color: bgColor,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isOnline ? AppTheme.successColor : AppTheme.settledColor,
        border: Border.all(
          color: AppTheme.bgPrimary,
          width: 2,
        ),
        boxShadow: widget.isOnline
            ? [
                BoxShadow(
                  color: AppTheme.successColor.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildBalanceIndicator() {
    final isPositive = widget.balance! > 0;
    final color = isPositive ? AppTheme.getBackColor : AppTheme.owesColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Text(
        isPositive ? '+' : '-',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Stack of friend avatars for group display
class FriendAvatarStack extends StatelessWidget {
  final List<String> names;
  final List<String?>? imageUrls;
  final int maxDisplay;
  final double size;
  final double overlap;
  final VoidCallback? onTap;

  const FriendAvatarStack({
    super.key,
    required this.names,
    this.imageUrls,
    this.maxDisplay = 4,
    this.size = 40,
    this.overlap = 0.4,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayCount = names.length > maxDisplay ? maxDisplay : names.length;
    final overflow = names.length - maxDisplay;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: size + 6,
        width: (size + 6) + ((displayCount - 1) * size * (1 - overlap)) +
            (overflow > 0 ? size * (1 - overlap) : 0),
        child: Stack(
          children: [
            for (int i = 0; i < displayCount; i++)
              Positioned(
                left: i * size * (1 - overlap),
                child: FriendAvatar(
                  name: names[i],
                  imageUrl: imageUrls != null && imageUrls!.length > i
                      ? imageUrls![i]
                      : null,
                  size: size,
                  showGradientRing: false,
                  enableTapAnimation: false,
                ),
              ),
            if (overflow > 0)
              Positioned(
                left: displayCount * size * (1 - overlap),
                child: Container(
                  width: size + 6,
                  height: size + 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.bgCardLight,
                    border: Border.all(
                      color: AppTheme.borderLight,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '+$overflow',
                      style: GoogleFonts.inter(
                        fontSize: size * 0.3,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
