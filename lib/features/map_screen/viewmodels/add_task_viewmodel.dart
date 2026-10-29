import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../viewmodels/auth_viewmodel.dart';
import '../models/floating_sheet_type.dart';
import '../models/task.dart';
import '../utils/task_constants.dart';
import '../utils/priority_reminder.dart';
import '../utils/task_week_helpers.dart';
import 'map_screen_viewmodel.dart';

class AddTaskViewModel extends ChangeNotifier {
  static const int maxTaskTitleLength = 100;

  final Map<FloatingSheetType, String?> _metadata = {};
  final List<FloatingSheetType> _metadataOrder = [];
  List<FloatingSheetType> _buttonOrder = List.from(
    TaskConstants.defaultButtonOrder,
  );
  bool _isMonthlyGoal = false;

  List<FloatingSheetType> get buttonOrder => List.unmodifiable(_buttonOrder);

  String? valueFor(FloatingSheetType type) => _metadata[type];

  List<FloatingSheetType> get metadataOrder =>
      List.unmodifiable(_metadataOrder);

  String? get priority => valueFor(FloatingSheetType.priority);
  String? get reminder => valueFor(FloatingSheetType.remind);
  String? get assignee => valueFor(FloatingSheetType.assign);
  String? get deadline => valueFor(FloatingSheetType.deadline);
  String? get workType => valueFor(FloatingSheetType.workType);
  String? get folder => valueFor(FloatingSheetType.folder);
  String? get clientName => valueFor(FloatingSheetType.clientName);
  String? get refProject => valueFor(FloatingSheetType.refProject);
  String? get weekKey => valueFor(FloatingSheetType.goal);
  bool get isMonthlyGoal => _isMonthlyGoal;

  List<String> get goalWeekOptions {
    final now = DateTime.now();
    final selected = dateRangeForWeek(weekKey ?? weekKeyFor(now));
    final monthKeys = <String>{
      ...weeksOfMonth(now.year, now.month).map((week) => week.key),
      if (selected != null)
        ...weeksOfMonth(selected.year, selected.month).map((week) => week.key),
    };
    return monthKeys.toList()..sort();
  }

  List<String> get selectedAssignees => (assignee ?? '')
      .split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toList();

  Future<void> loadButtonOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('map_button_order');

    if (saved == null) {
      _buttonOrder = List.from(TaskConstants.defaultButtonOrder);
    } else {
      _buttonOrder = saved
          .map(
            (e) => FloatingSheetType.values.firstWhere(
              (v) => v.name == e,
              orElse: () => TaskConstants.defaultButtonOrder.first,
            ),
          )
          .where((type) => type != FloatingSheetType.folder)
          .toList();
    }
    notifyListeners();
  }

  Future<void> saveButtonOrder(List<FloatingSheetType> newOrder) async {
    _buttonOrder = List.from(newOrder);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'map_button_order',
      _buttonOrder.map((e) => e.name).toList(),
    );
  }

  bool setValue(FloatingSheetType type, String? value) {
    if (type == FloatingSheetType.priority) {
      final reminder = reminderForPriority(value);
      if (reminder != null) {
        _setMetadataValue(FloatingSheetType.remind, reminder.toIso8601String());
      }
    }

    return _setMetadataValue(type, value);
  }

  bool _setMetadataValue(FloatingSheetType type, String? value) {
    final wasSelected = _metadata[type]?.trim().isNotEmpty ?? false;
    _metadata[type] = value;
    if (value == null || value.trim().isEmpty) {
      _metadataOrder.remove(type);
    } else {
      _metadataOrder
        ..remove(type)
        ..insert(0, type);
    }
    notifyListeners();
    return !wasSelected && value != null && _metadataOrder.length == 3;
  }

  void addAssignee(String name) {
    final current = selectedAssignees;
    if (!current.any(
      (element) => element.toLowerCase() == name.toLowerCase(),
    )) {
      current.add(name);
      setValue(FloatingSheetType.assign, current.join(', '));
    }
  }

  void removeAssignee(String name) {
    final current = selectedAssignees;
    current.removeWhere(
      (element) => element.toLowerCase() == name.toLowerCase(),
    );
    setValue(
      FloatingSheetType.assign,
      current.isEmpty ? null : current.join(', '),
    );
  }

  void setMonthlyGoal(bool value) {
    _isMonthlyGoal = value;
    notifyListeners();
  }

  Future<bool> submitTask({
    required String title,
    required AuthViewModel authViewModel,
    required MapScreenViewModel mapViewModel,
    Future<void> Function(Task task)? onTaskSaved,
    Task? taskDraft,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || cleanTitle.length > maxTaskTitleLength) {
      return false;
    }

    final added = await mapViewModel.addTask(
      title: cleanTitle,
      authViewModel: authViewModel,
      onTaskSaved: onTaskSaved,
      taskDraft: taskDraft,
      weekKey: weekKey,
      isMonthlyGoal: isMonthlyGoal,
      priority: priority,
      reminder: reminder,
      assignee: assignee,
      deadline: deadline,
      workType: workType,
      folder: folder,
      clientName: clientName,
      refProject: refProject,
    );

    if (added) {
      clear();
    }
    return added;
  }

  void clear() {
    _metadata.clear();
    _metadataOrder.clear();
    _isMonthlyGoal = false;
    notifyListeners();
  }
}
