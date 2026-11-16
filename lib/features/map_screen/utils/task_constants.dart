import 'package:flutter/material.dart';

import '../models/floating_sheet_type.dart';

class TaskConstants {
  TaskConstants._();

  static const Color primaryColor = Color(0xFFFBE64E);
  static const Color secondaryColor = Color(0xFF6B5800);

  static const List<FloatingSheetType> defaultButtonOrder = [
    FloatingSheetType.priority,
    FloatingSheetType.workType,
    FloatingSheetType.remind,
    FloatingSheetType.assign,
    FloatingSheetType.monitor,
    FloatingSheetType.clientName,
    FloatingSheetType.deadline,
    FloatingSheetType.goal,
    FloatingSheetType.refProject,
  ];

  static const List<String> priorityOptions = [
    'U1',
    'U2',
    'U3',
    'IMP',
    'Today',
    'Tomorrow',
    'Day Later',
    'Later',
    'Process',
    'Hold',
    'Free',
  ];

  static const List<String> defaultWorkTypes = [
    'Work',
    'Call',
    'Msg',
    'Meet',
    'Demo',
    'Others',
    'Travel',
    'Report',
    'Update',
    'Discuss',
    'Complain',
    'Timepass',
  ];

  static List<String> orderWorkTypes(Iterable<String> workTypes) {
    final preferredOrder = {
      for (var index = 0; index < defaultWorkTypes.length; index++)
        defaultWorkTypes[index].toLowerCase(): index,
      'message': defaultWorkTypes.indexOf('Msg'),
    };
    final indexedWorkTypes = workTypes.indexed.toList()
      ..sort((first, second) {
        final firstOrder =
            preferredOrder[first.$2.trim().toLowerCase()] ??
            defaultWorkTypes.length;
        final secondOrder =
            preferredOrder[second.$2.trim().toLowerCase()] ??
            defaultWorkTypes.length;
        final orderDifference = firstOrder.compareTo(secondOrder);
        if (orderDifference != 0) return orderDifference;
        final firstIsMsg = first.$2.trim().toLowerCase() == 'msg';
        final secondIsMsg = second.$2.trim().toLowerCase() == 'msg';
        if (firstIsMsg != secondIsMsg) return firstIsMsg ? -1 : 1;
        return first.$1.compareTo(second.$1);
      });
    return indexedWorkTypes.map((entry) => entry.$2).toList();
  }

  static const List<String> folderOptions = [
    'Personal',
    'Office',
    'Freelance',
    'Custom',
  ];

  static const List<(String, String, String)> shortcutsHelp = [
    ('@', 'Assign', 'Type @ to search and assign a person.'),
    ('-', 'Priority', 'Type - and a letter, such as -u, to filter priorities.'),
    ('!', 'Deadline', 'Type ! and a word, such as !tom, to filter deadlines.'),
    ('*', 'Remind Me', 'Type * and a word to filter reminder options.'),
    ('+', 'Work Type', 'Type + and a word to filter work types.'),
    ('#', 'Client Name', 'Type # and a name to filter clients.'),
    ('^', 'Ref Project', 'Type ^ and a name to filter projects.'),
  ];
}
