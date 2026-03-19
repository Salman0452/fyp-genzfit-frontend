import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';

/// Design Utilities for Fitstreak App
/// Provides reusable widgets and styling components following the design system

class DesignUtils {
  // Card & Container Styling
  static BoxDecoration modernCardDecoration({
    Color backgroundColor = const Color(0xFFFFFFFF),
    double borderRadius = 16,
    bool hasShadow = true,
    Color shadowColor = const Color(0x1F000000),
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow:
          hasShadow
              ? [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
              : null,
    );
  }

  static BoxDecoration gradientCardDecoration({
    required List<Color> colors,
    List<double>? stops,
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
    double borderRadius = 16,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        stops: stops,
        begin: begin,
        end: end,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: colors.first.withOpacity(0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration accentBorderDecoration({
    Color borderColor = AppColors.brandGreen,
    double borderWidth = 2,
    Color backgroundColor = Colors.transparent,
    double borderRadius = 12,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      border: Border.all(color: borderColor, width: borderWidth),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  // Gradient Backgrounds
  static BoxDecoration greenGradientBackground({double borderRadius = 0}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.brandGreen, AppColors.brandGreen.withOpacity(0.8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  static BoxDecoration blueGradientBackground({double borderRadius = 0}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.brandBlue, AppColors.brandBlue.withOpacity(0.8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  static BoxDecoration darkGradientBackground({double borderRadius = 0}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.textPrimary, AppColors.textPrimary.withOpacity(0.7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  // Text Styles
  static TextStyle headingStyle({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.textPrimary,
    double? height,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle bodyStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.textSecondary,
    double? height,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle labelStyle({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.textSecondary,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}

/// Reusable Card Widget
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool hasShadow;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final List<Color>? gradientColors;

  const CustomCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.hasShadow = true,
    this.backgroundColor,
    this.onTap,
    this.gradientColors,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration:
          gradientColors != null
              ? DesignUtils.gradientCardDecoration(
                colors: gradientColors!,
                borderRadius: borderRadius,
              )
              : DesignUtils.modernCardDecoration(
                backgroundColor: backgroundColor ?? Colors.white,
                borderRadius: borderRadius,
                hasShadow: hasShadow,
              ),
      child: child,
    );

    if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }

    return Container(margin: margin ?? EdgeInsets.zero, child: card);
  }
}

/// Reusable Stat Card Widget
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool useGradient;

  const StatCard({
    Key? key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.iconColor,
    this.onTap,
    this.useGradient = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors =
        useGradient
            ? [AppColors.brandGreen, AppColors.brandGreen.withOpacity(0.7)]
            : null;

    return CustomCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      gradientColors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: DesignUtils.labelStyle(
                    fontSize: 12,
                    color:
                        useGradient ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
              ),
              if (icon != null)
                Icon(
                  icon,
                  color:
                      iconColor ??
                      (useGradient ? Colors.white : AppColors.brandGreen),
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: DesignUtils.headingStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: useGradient ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: DesignUtils.bodyStyle(
                      fontSize: 12,
                      color:
                          useGradient
                              ? Colors.white70
                              : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress Card Widget
class ProgressCard extends StatelessWidget {
  final String title;
  final double progress; // 0.0 to 1.0
  final String progressText;
  final Color? progressColor;

  const ProgressCard({
    Key? key,
    required this.title,
    required this.progress,
    required this.progressText,
    this.progressColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: DesignUtils.headingStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                progressText,
                style: DesignUtils.labelStyle(
                  fontSize: 12,
                  color: progressColor ?? AppColors.brandGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                progressColor ?? AppColors.brandGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Achievement Badge Widget
class AchievementBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? backgroundColor;
  final Color? iconColor;

  const AchievementBadge({
    Key? key,
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.brandGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor ?? AppColors.brandGreen, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: DesignUtils.labelStyle(fontSize: 11),
        ),
      ],
    );
  }
}

/// Action Button with Icon
class ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;

  const ActionButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isPrimary = true,
    this.isLoading = false,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon:
            isLoading
                ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : Icon(icon ?? Icons.check),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          backgroundColor: AppColors.brandGreen,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: Icon(icon ?? Icons.add),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          foregroundColor: AppColors.brandGreen,
          side: const BorderSide(color: AppColors.brandGreen, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

/// Info Box with Icon
class InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;

  const InfoBox({
    Key? key,
    required this.icon,
    required this.title,
    required this.message,
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.brandGreen.withOpacity(0.05),
        border: Border.all(
          color: borderColor ?? AppColors.brandGreen.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? AppColors.brandGreen, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DesignUtils.labelStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: DesignUtils.bodyStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Divider with Label
class DividerWithLabel extends StatelessWidget {
  final String label;
  final Color? color;

  const DividerWithLabel({Key? key, required this.label, this.color})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: color ?? AppColors.surfaceVariant, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: DesignUtils.labelStyle(
              fontSize: 12,
              color: color ?? AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: color ?? AppColors.surfaceVariant, height: 1),
        ),
      ],
    );
  }
}

/// Section Header Widget
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onActionPressed;
  final String? actionLabel;
  final IconData? actionIcon;

  const SectionHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.onActionPressed,
    this.actionLabel,
    this.actionIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DesignUtils.headingStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: DesignUtils.bodyStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            if (onActionPressed != null)
              TextButton.icon(
                onPressed: onActionPressed,
                icon: Icon(actionIcon ?? Icons.arrow_forward),
                label: Text(actionLabel ?? 'View All'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandGreen,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
