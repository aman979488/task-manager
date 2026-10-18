import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/features/map_screen/utils/task_mention_parser.dart';

void main() {
  group('TaskMentionParser.parseMention', () {
    test('parses a query immediately after the symbol', () {
      final mention = TaskMentionParser.parseMention('@aman', 5);

      expect(mention?.start, 0);
      expect(mention?.symbol, '@');
      expect(mention?.query, 'aman');
    });

    test('parses a query after whitespace following the symbol', () {
      final mention = TaskMentionParser.parseMention('@ aman', 6);

      expect(mention?.start, 0);
      expect(mention?.symbol, '@');
      expect(mention?.query, 'aman');
    });

    test('parses a query after multiple spaces following the symbol', () {
      final mention = TaskMentionParser.parseMention('@  aman', 7);

      expect(mention?.start, 0);
      expect(mention?.symbol, '@');
      expect(mention?.query, 'aman');
    });

    test('does not parse a mention inside a word', () {
      expect(TaskMentionParser.parseMention('name@ aman', 10), isNull);
    });
  });

  test('matches assignee names without case sensitivity', () {
    expect(TaskMentionParser.matchesSearchQuery('Aman Yadav', 'aman'), isTrue);
  });
}
