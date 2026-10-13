import 'package:flutter/foundation.dart';

import '../models/floating_sheet_type.dart';

class AddTaskViewModel extends ChangeNotifier {
  final Map<FloatingSheetType, String?> _metadata = {};
  final List<FloatingSheetType> _metadataOrder = [];

  String? valueFor(FloatingSheetType type) => _metadata[type];

  List<FloatingSheetType> get metadataOrder =>
      List.unmodifiable(_metadataOrder);

  bool setValue(FloatingSheetType type, String? value) {
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

  void clear() {
    _metadata.clear();
    _metadataOrder.clear();
    notifyListeners();
  }
}
