import 'package:flutter/material.dart';

class ShellCard extends StatelessWidget {
  const ShellCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.backgroundColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      child: Padding(padding: padding, child: child),
    );
  }
}
