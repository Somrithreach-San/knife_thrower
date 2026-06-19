import 'package:flutter/material.dart';

class BackArrowButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double? scale;

  const BackArrowButton({
    super.key,
    this.onTap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40 * scale!,
        height: 40 * scale!,
        color: Colors.transparent,
        child: Center(
          child: Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 22 * scale!,
          ),
        ),
      ),
    );
  }
}
