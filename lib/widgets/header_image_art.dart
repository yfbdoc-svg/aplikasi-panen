import 'package:flutter/material.dart';

class HeaderImageArt extends StatelessWidget {
  final Widget child;
  final String assetPath;
  final double widthFactor;
  final double opacity;
  final Alignment alignment;
  final BoxFit fit;

  const HeaderImageArt({
    super.key,
    required this.child,
    required this.assetPath,
    this.widthFactor = .52,
    this.opacity = 1,
    this.alignment = Alignment.centerRight,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: Align(
            alignment: alignment,
            child: FractionallySizedBox(
              widthFactor: widthFactor,
              heightFactor: 1,
              alignment: alignment,
              child: Opacity(
                opacity: opacity,
                child: Image.asset(
                  assetPath,
                  fit: fit,
                  alignment: Alignment.centerRight,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
