import 'package:flutter/material.dart';

class BackArrowButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double scale;

  const BackArrowButton({super.key, this.onTap, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44 * scale,
          height: 44 * scale,
          color: Colors.transparent,
          child: Center(
            child: Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 26 * scale,
            ),
          ),
        ),
      ),
    );
  }
}
