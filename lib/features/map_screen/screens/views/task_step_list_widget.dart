import 'package:flutter/material.dart';

import '../../models/task.dart';

class TaskStepListWidget extends StatefulWidget {
  final Task task;
  final VoidCallback onChanged;
  final Future<void> Function() onSave;
  final Color secondaryColor;

  const TaskStepListWidget({
    super.key,
    required this.task,
    required this.onChanged,
    required this.onSave,
    this.secondaryColor = const Color(0xFF6B5800),
  });

  @override
  State<TaskStepListWidget> createState() => _TaskStepListWidgetState();
}

class _TaskStepListWidgetState extends State<TaskStepListWidget> {
  late TextEditingController _stepController;
  final FocusNode _stepFocusNode = FocusNode();
  bool _isAddingStep = false;
  int? _editingStepIndex;

  Task get task => widget.task;

  @override
  void initState() {
    super.initState();
    _stepController = TextEditingController();
  }

  @override
  void dispose() {
    _stepController.dispose();
    _stepFocusNode.dispose();
    super.dispose();
  }

  void _saveStep(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      _stepFocusNode.requestFocus();
      return;
    }
    setState(() {
      task.steps.add(TaskStep(title: text));
      _stepController.clear();
    });
    widget.onChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isAddingStep) _stepFocusNode.requestFocus();
    });
  }

  void _startEditStep(int index) {
    setState(() {
      _editingStepIndex = index;
      _isAddingStep = false;
      _stepController.text = task.steps[index].title;
    });
  }

  void _saveEditedStep(int index, String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    setState(() {
      task.steps[index].title = text;
      _editingStepIndex = null;
      _stepController.clear();
    });
    widget.onChanged();
  }

  Future<void> _confirmDeleteStep(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete step'),
          scrollable: true,
          content: const Text('Are you sure you want to delete this sub-step?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true || index < 0 || index >= task.steps.length) return;

    final removedStep = task.steps.removeAt(index);
    setState(() {});
    widget.onChanged();

    try {
      await widget.onSave();
    } catch (error) {
      if (!mounted) return;
      setState(() => task.steps.insert(index, removedStep));
      widget.onChanged();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not delete substep: $error')),
        );
    }
  }

  Widget _buildStepTile(TaskStep step, int index) {
    final isEditing = _editingStepIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() => step.isDone = !step.isDone);
              widget.onChanged();
            },
            child: Icon(
              step.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isEditing
                ? TextField(
                    controller: _stepController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (val) => _saveEditedStep(index, val),
                  )
                : GestureDetector(
                    onTap: () => _startEditStep(index),
                    child: Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 15,
                        decoration: step.isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
          ),
          if (isEditing)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                setState(() {
                  _editingStepIndex = null;
                  _stepController.clear();
                });
              },
            )
          else
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.redAccent,
              ),
              onPressed: () => _confirmDeleteStep(index),
              tooltip: 'Delete sub-step',
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (task.steps.isNotEmpty)
          ...task.steps.asMap().entries.map(
            (e) => _buildStepTile(e.value, e.key),
          ),
        if (_isAddingStep)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(
                  Icons.radio_button_unchecked,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _stepController,
                    focusNode: _stepFocusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: "Add step",
                      border: InputBorder.none,
                    ),
                    onSubmitted: _saveStep,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _stepFocusNode.unfocus();
                    setState(() {
                      _isAddingStep = false;
                      _stepController.clear();
                    });
                  },
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: () {
              setState(() {
                _editingStepIndex = null;
                _isAddingStep = true;
                _stepController.clear();
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(
                    Icons.add,
                    color: widget.secondaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Add step",
                    style: TextStyle(
                      color: widget.secondaryColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
