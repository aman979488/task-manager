import 'package:flutter/material.dart';

class AddTaskSheet extends StatelessWidget {
  const AddTaskSheet({
    super.key,
    required this.bottomPadding,
    required this.scrollController,
    required this.child,
  });

  final double bottomPadding;
  final ScrollController scrollController;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          child: child,
        ),
      );
}
