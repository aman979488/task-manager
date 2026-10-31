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
    'Monitor',
    'Free',
  ];

  static const List<String> defaultWorkTypes = [
    'Call',
    'Message',
    'WhatsApp',
    '1st Visit',
    'Revisit',
    'Follow Up Call',
    'Others',
  ];

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
