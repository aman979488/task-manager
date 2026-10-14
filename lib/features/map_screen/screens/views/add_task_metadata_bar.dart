import 'package:flutter/material.dart';

import '../../models/floating_sheet_type.dart';

class AddTaskMetadataBar extends StatelessWidget {
  const AddTaskMetadataBar({
    super.key,
    required this.buttonOrder,
    required this.metadataOrder,
    required this.scrollController,
    required this.compact,
    required this.buttonBuilder,
  });

  final List<FloatingSheetType> buttonOrder;
  final List<FloatingSheetType> metadataOrder;
  final ScrollController scrollController;
  final bool compact;
  final Widget Function(FloatingSheetType type, bool compact) buttonBuilder;

  @override
  Widget build(BuildContext context) {
    final orderedButtons = [
      ...metadataOrder.where(buttonOrder.contains),
      ...buttonOrder.where((type) => !metadataOrder.contains(type)),
    ];

    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: orderedButtons
            .map(
              (type) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: buttonBuilder(type, compact),
              ),
            )
            .toList(),
      ),
    );
  }
}
