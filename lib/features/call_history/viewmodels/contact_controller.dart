import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../models/contact_model.dart';
import '../utils/demo_data.dart';

class ContactController extends ChangeNotifier {
  List<ContactModel> _allContacts = [];
  String _query = '';
  bool isLoading = false;
  bool permissionDenied = false;
  final Set<String> _favoriteIds = {};
  String _sortBy = 'calls_desc';
  bool _onlyFavorites = false;

  bool get onlyFavorites => _onlyFavorites;
  String get sortBy => _sortBy;
  bool isFavorite(String id) => _favoriteIds.contains(id);

  void toggleFavorite(String id) {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    notifyListeners();
  }

  void toggleOnlyFavorites() {
    _onlyFavorites = !_onlyFavorites;
    notifyListeners();
  }

  void setSort(String sort) {
    _sortBy = sort;
    notifyListeners();
  }

  List<ContactModel> get contacts {
    List<ContactModel> list = _allContacts;
    if (_onlyFavorites) {
      list = list.where((c) => _favoriteIds.contains(c.id)).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.phoneNumbers.any((n) => n.contains(_query)),
          )
          .toList();
    }

    final sorted = List<ContactModel>.from(list);
    switch (_sortBy) {
      case 'calls_desc':
        sorted.sort(
          (a, b) => b.calculatedTotalCalls.compareTo(a.calculatedTotalCalls),
        );
      case 'calls_asc':
        sorted.sort(
          (a, b) => a.calculatedTotalCalls.compareTo(b.calculatedTotalCalls),
        );
      case 'name_asc':
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case 'name_desc':
        sorted.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
    }
    return sorted;
  }

  Future<void> loadContacts() async {
    isLoading = true;
    permissionDenied = false;
    notifyListeners();

    if (kIsWeb) {
      _allContacts = [...DemoData.contacts];
      _favoriteIds.add('1'); // Didi
      _favoriteIds.add('2'); // Mummy
      isLoading = false;
      notifyListeners();
      return;
    }

    final permissionStatus = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (permissionStatus != PermissionStatus.granted &&
        permissionStatus != PermissionStatus.limited) {
      permissionDenied = true;
      isLoading = false;
      notifyListeners();
      return;
    }

    final raw = await FlutterContacts.getAll(
      properties: {ContactProperty.phone, ContactProperty.photoThumbnail},
    );
    final mapped = raw
        .map(ContactModel.fromContact)
        .where((c) => c.name.trim().isNotEmpty)
        .toList();

    if (mapped.isEmpty) {
      _allContacts = [...DemoData.contacts];
    } else {
      _allContacts = mapped;
    }

    isLoading = false;
    notifyListeners();
  }

  void search(String query) {
    _query = query.trim();
    notifyListeners();
  }
}
