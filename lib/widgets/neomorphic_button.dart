import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'neomorphic_box.dart';

/// Mirrors ui/components/NeomorphicButton.kt: a tappable NeomorphicBox that halves its shadow
/// elevation while pressed (Kotlin: `if (isPressed) elevation / 2 else elevation`) instead of
/// fading opacity, to simulate the surface being "pushed in".
class NeomorphicButton extends StatefulWidget {
  const NeomorphicButton({
    super.key,
    required this.onPressed,
    required this.child,
    // primaryAccentStrong, not primaryAccent (softBlue): softBlue is a background/shadow
    // pastel and reads at ~1.8:1 with the white button text this widget is normally paired
    // with, well under the 4.5:1 WCAG AA minimum. Screens that intentionally want a different
    // color (Post Pantun's mint green, etc.) still override this explicitly.
    this.backgroundColor = AppColors.primaryAccentStrong,
    this.borderRadius = 16,
    this.elevation = 4,
    this.enabled = true,
    this.width,
    this.height = 56,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color backgroundColor;
  final double borderRadius;
  final double elevation;
  final bool enabled;
  final double? width;
  final double? height;

  @override
  State<NeomorphicButton> createState() => _NeomorphicButtonState();
}

class _NeomorphicButtonState extends State<NeomorphicButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final currentElevation = _isPressed ? widget.elevation / 2 : widget.elevation;
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: widget.enabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.enabled ? widget.onPressed : null,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: NeomorphicBox(
          backgroundColor: widget.backgroundColor,
          borderRadius: widget.borderRadius,
          elevation: currentElevation,
          padding: EdgeInsets.zero,
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}
