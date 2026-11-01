import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FrequentOptionUsage {
  static const _keyPrefix = 'frequent_option_usage_v1';

  static Future<List<String>> orderOptions(
    String listKey,
    List<String> options, {
    List<String> selectedValues = const [],
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final indexedOptions = options.indexed.toList();

    indexedOptions.sort((first, second) {
      final firstSelected = selectedValues.contains(first.$2);
      final secondSelected = selectedValues.contains(second.$2);
      if (firstSelected != secondSelected) {
        return firstSelected ? -1 : 1;
      }

      final firstUsage =
          preferences.getInt(_preferenceKey(listKey, first.$2)) ?? 0;
      final secondUsage =
          preferences.getInt(_preferenceKey(listKey, second.$2)) ?? 0;
      final usageOrder = secondUsage.compareTo(firstUsage);
      if (usageOrder != 0) return usageOrder;

      return first.$1.compareTo(second.$1);
    });

    return indexedOptions.map((option) => option.$2).toList();
  }

  static Future<void> recordSelection(String listKey, String value) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _preferenceKey(listKey, value);
    await preferences.setInt(key, (preferences.getInt(key) ?? 0) + 1);
  }

  static String _preferenceKey(String listKey, String value) {
    final encodedListKey = base64Url.encode(utf8.encode(listKey));
    final encodedValue = base64Url.encode(utf8.encode(value));
    return '$_keyPrefix:$encodedListKey:$encodedValue';
  }
}
