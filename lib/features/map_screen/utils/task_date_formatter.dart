class TaskDateFormatter {
  TaskDateFormatter._();

  static String formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final date = DateTime(dt.year, dt.month, dt.day);

      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final time = dt.minute == 0
          ? '$hour${dt.hour >= 12 ? 'p' : 'a'}'
          : '$hour:${dt.minute.toString().padLeft(2, '0')}${dt.hour >= 12 ? 'p' : 'a'}';

      if (date == today) return 'Today $time';
      if (date == tomorrow) return 'Tmrw $time';
      return '${dt.day}/${dt.month} $time';
    } catch (_) {
      return 'Set';
    }
  }

  static DateTime? scheduledDate(String? deadline, String? reminder) {
    return DateTime.tryParse(deadline ?? reminder ?? '');
  }
}
