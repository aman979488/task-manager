import 'package:flutter/material.dart';

Color taskPriorityColor(String? priority) {
  switch (priority?.trim().toLowerCase()) {
    case 'u1':
    case 'u2':
    case 'u3':
    case 'urgent':
    case 'monitor':
      return const Color(0xFF9B5965);
    case 'imp':
      return const Color(0xFFB38600);
    case 'today':
    case 'tomorrow':
      return const Color(0xFF2E7D32);
    case 'hold':
      return const Color(0xFF99765B);
    case 'process':
      return const Color(0xFF667F89);
    default:
      return const Color(0xFF71808D);
  }
}
