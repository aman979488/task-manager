DateTime? reminderForPriority(String? priority, {DateTime? now}) {
  final dayOffset = switch (priority?.trim().toLowerCase()) {
    'today' => 0,
    'tomorrow' => 1,
    'day later' => 2,
    'later' => 3,
    _ => null,
  };
  if (dayOffset == null) return null;

  final today = now ?? DateTime.now();
  final reminderDate = DateTime(today.year, today.month, today.day + dayOffset);
  final reminderAt = DateTime(
    reminderDate.year,
    reminderDate.month,
    reminderDate.day,
    21,
  );
  if (dayOffset == 0 && !reminderAt.isAfter(today)) {
    return DateTime(today.year, today.month, today.day + 1, 21);
  }
  return reminderAt;
}
