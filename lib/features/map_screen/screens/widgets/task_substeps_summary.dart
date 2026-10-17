import 'package:flutter/material.dart';

import '../../models/task.dart';

class TaskSubstepsSummary extends StatelessWidget {
  const TaskSubstepsSummary({
    super.key,
    required this.steps,
    this.dense = false,
  });

  final List<TaskStep> steps;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: dense ? 2 : 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final step in steps)
            Padding(
              padding: EdgeInsets.only(bottom: dense ? 1 : 3),
              child: Row(
                children: [
                  Icon(
                    step.isDone
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: dense ? 11 : 13,
                    color: step.isDone
                        ? Colors.green
                        : Colors.blueGrey.shade300,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      step.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: dense ? 9 : 11,
                        color: step.isDone
                            ? Colors.grey.shade500
                            : Colors.blueGrey.shade600,
                        decoration: step.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
