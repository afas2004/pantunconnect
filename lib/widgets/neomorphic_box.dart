import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Mirrors ui/components/NeomorphicBox.kt: a soft-UI container with a light shadow on the
/// top-left and a dark shadow on the bottom-right, giving the embossed "neumorphism" look used
/// throughout the app.
class NeomorphicBox extends StatelessWidget {
  const NeomorphicBox({
    super.key,
    required this.child,
    this.backgroundColor = AppColors.backgroundNeutral,
    this.borderRadius = 20,
    this.elevation = 6,
    this.lightShadowColor = AppColors.lightShadow,
    this.darkShadowColor = AppColors.darkShadow,
    this.padding,
  });

  final Widget child;
  final Color backgroundColor;
  final double borderRadius;
  final double elevation;
  final Color lightShadowColor;
  final Color darkShadowColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final offset = elevation / 1.5;
    return Container(
      padding: padding ?? EdgeInsets.all(elevation / 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: darkShadowColor.withOpacity(0.3),
            offset: Offset(offset, offset),
            blurRadius: elevation,
          ),
          BoxShadow(
            color: lightShadowColor,
            offset: Offset(-offset, -offset),
            blurRadius: elevation,
          ),
        ],
      ),
      child: child,
    );
  }
}
