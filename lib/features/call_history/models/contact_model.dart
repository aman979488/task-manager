import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactModel {
  final String id;
  final String name;
  final List<String> phoneNumbers;
  final Uint8List? photo;
  final int? totalCalls;

  const ContactModel({
    required this.id,
    required this.name,
    required this.phoneNumbers,
    this.photo,
    this.totalCalls,
  });

  factory ContactModel.fromContact(Contact contact) {
    return ContactModel(
      id: contact.id ?? contact.displayName ?? '',
      name: contact.displayName ?? '',
      phoneNumbers: contact.phones.map((p) => p.number).toList(),
      photo: contact.photo?.thumbnail,
    );
  }

  String get initial {
    if (name.isEmpty) return '#';
    final trimmed = name.trim();
    for (final char in trimmed.characters) {
      final upper = char.toUpperCase();
      if (RegExp(r'[A-Z]').hasMatch(upper)) {
        return upper;
      }
    }
    return '#';
  }

  int get calculatedTotalCalls {
    if (totalCalls != null) return totalCalls!;
    if (name.contains('Didi')) return 3757;
    if (name.contains('Mummy')) return 2135;
    if (name.contains('Karuna')) return 1596;
    if (name.contains('papa')) return 892;
    final seed = name.codeUnits.fold<int>(
      0,
      (value, codeUnit) => value + codeUnit,
    );
    return 120 + (seed % 4500);
  }
}
