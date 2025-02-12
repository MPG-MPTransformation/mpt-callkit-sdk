import 'package:flutter/material.dart';

class BubbleActionButton extends StatelessWidget {
  const BubbleActionButton({
    super.key,
    this.buttonSize,
    this.bgColor,
    required this.child,
    required this.onTap,
  });

  final double? buttonSize;
  final Color? bgColor;
  final Widget child;
  final Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor ?? Colors.blue,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: buttonSize ?? 40,
          width: buttonSize ?? 60,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: child,
          ),
        ),
      ),
    );
  }
}
