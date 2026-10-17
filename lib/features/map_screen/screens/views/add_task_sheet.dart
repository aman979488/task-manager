import 'package:flutter/material.dart';

class AddTaskSheet extends StatelessWidget {
  const AddTaskSheet({
    super.key,
    required this.bottomPadding,
    required this.child,
  });

  final double bottomPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const ClampingScrollPhysics(),
    child: Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      child: child,
    ),
  );
}
