import '../models/floating_sheet_type.dart';

class TaskMention {
  const TaskMention({
    required this.start,
    required this.symbol,
    required this.query,
  });

  final int start;
  final String symbol;
  final String query;
}

class TaskMentionParser {
  TaskMentionParser._();

  static const String allowedSymbols = '@-!*+#^';

  static TaskMention? parseMention(String text, int cursor) {
    final c = cursor.clamp(0, text.length);
    for (var i = c - 1; i >= 0; i--) {
      final ch = text[i];
      if (allowedSymbols.contains(ch)) {
        if (i == 0 || RegExp(r'\s').hasMatch(text[i - 1])) {
          final suffix = text.substring(i + 1, c);
          final query = suffix.trimLeft();
          if (RegExp(r'\s').hasMatch(query)) return null;
          return TaskMention(start: i, symbol: ch, query: query);
        }
        return null;
      }
    }
    return null;
  }

  static FloatingSheetType? typeForSymbol(String symbol) {
    return switch (symbol) {
      '-' => FloatingSheetType.priority,
      '@' => FloatingSheetType.assign,
      '!' => FloatingSheetType.deadline,
      '*' => FloatingSheetType.remind,
      '+' => FloatingSheetType.workType,
      '#' => FloatingSheetType.clientName,
      '^' => FloatingSheetType.refProject,
      _ => null,
    };
  }

  static bool matchesSearchQuery(String option, String query) {
    final normalizedOption = option.toLowerCase();
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    if (normalizedOption.contains(normalizedQuery)) return true;

    var queryIndex = 0;
    for (
      var optionIndex = 0;
      optionIndex < normalizedOption.length;
      optionIndex++
    ) {
      if (normalizedOption[optionIndex] == normalizedQuery[queryIndex]) {
        queryIndex++;
        if (queryIndex == normalizedQuery.length) return true;
      }
    }
    return false;
  }

  static String removeMetadataMentions({
    required String text,
    required String? assignee,
    required String? clientName,
    required String? workType,
  }) {
    var cleaned = text;
    for (final (symbol, value) in [
      ('@', assignee),
      ('#', clientName),
      ('+', workType),
    ]) {
      final normalizedValue = value?.trim();
      if (normalizedValue == null || normalizedValue.isEmpty) continue;

      final token = RegExp(
        '(^|\\s)${RegExp.escape(symbol)}\\s*${RegExp.escape(normalizedValue)}(?=\\s|\$)',
        caseSensitive: false,
      );
      cleaned = cleaned.replaceAllMapped(token, (match) => match[1] ?? '');
    }
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(^|\s)@\s*[\w.-]+'),
      (match) => match[1] ?? '',
    );
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static ({String newText, int newCursor}) removeMentionToken({
    required String text,
    required int start,
    int? end,
  }) {
    if (start < 0 || start >= text.length) {
      return (newText: text, newCursor: text.length);
    }
    var mentionEnd = end ?? start;
    while (mentionEnd < text.length &&
        !RegExp(r'\s').hasMatch(text[mentionEnd])) {
      mentionEnd++;
    }

    final before = text.substring(0, start).trimRight();
    final after = text.substring(mentionEnd).trimLeft();
    final hasBefore = before.isNotEmpty;
    final hasAfter = after.isNotEmpty;
    final updated = hasBefore && hasAfter
        ? '$before $after'
        : hasBefore
        ? before
        : after;
    final cursor = hasBefore ? before.length + (hasAfter ? 1 : 0) : 0;
    return (newText: updated, newCursor: cursor);
  }
}
