import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';

import '../viewmodels/contact_controller.dart';
import '../widgets/contact_tile.dart';
import '../widgets/search_field.dart';

class ContactsView extends StatelessWidget {
  const ContactsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ContactController>();
    final contacts = controller.contacts;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  const Text(
                    'Contacts',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E2126),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Favorites',
                    onPressed: controller.toggleOnlyFavorites,
                    icon: Icon(
                      controller.onlyFavorites
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 24,
                      color: controller.onlyFavorites
                          ? Colors.red
                          : const Color(0xFF1E2126),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Filter',
                    onPressed: () => _showFilterSheet(context, controller),
                    icon: const Icon(
                      Icons.filter_alt,
                      size: 24,
                      color: Color(0xFF1E2126),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sort',
                    onPressed: () => _showSortSheet(context, controller),
                    icon: const Icon(
                      Icons.sort,
                      size: 25,
                      color: Color(0xFF1E2126),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More options',
                    icon: const Icon(
                      Icons.more_vert,
                      size: 24,
                      color: Color(0xFF1E2126),
                    ),
                    onSelected: (value) {
                      if (value == 'refresh') {
                        controller.loadContacts();
                      } else if (value == 'clear_search') {
                        controller.search('');
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'refresh',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, size: 20),
                            SizedBox(width: 10),
                            Text('Refresh Contacts'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'clear_search',
                        child: Row(
                          children: [
                            Icon(Icons.clear_all, size: 20),
                            SizedBox(width: 10),
                            Text('Reset Filters'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SearchField(
              onChanged: context.read<ContactController>().search,
            ),
            if (kIsWeb)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.science_outlined, size: 16),
                    label: const Text('Demo data (browser)', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            Expanded(
              child: controller.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : controller.permissionDenied
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_outline, size: 48),
                              const SizedBox(height: 12),
                              const Text('Contacts permission is needed'),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: controller.loadContacts,
                                child: const Text('Try again'),
                              ),
                              TextButton(
                                onPressed: FlutterContacts.permissions.openSettings,
                                child: const Text('Open settings'),
                              ),
                            ],
                          ),
                        )
                      : contacts.isEmpty
                          ? const Center(child: Text('No contacts found'))
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 4, bottom: 96),
                              itemCount: contacts.length > 2
                                  ? contacts.length + 1
                                  : contacts.length,
                              itemBuilder: (context, index) {
                                // Insert Promotional Banner between 2nd and 3rd contact
                                if (contacts.length > 2 && index == 2) {
                                  return const AdBannerCard();
                                }
                                final contactIndex =
                                    (contacts.length > 2 && index > 2)
                                        ? index - 1
                                        : index;
                                return ContactTile(
                                  contact: contacts[contactIndex],
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context, ContactController controller) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sort Contacts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.trending_down),
                  title: const Text('Total Calls (High to Low)'),
                  trailing: controller.sortBy == 'calls_desc'
                      ? const Icon(Icons.check, color: Color(0xFFFAB400))
                      : null,
                  onTap: () {
                    controller.setSort('calls_desc');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.trending_up),
                  title: const Text('Total Calls (Low to High)'),
                  trailing: controller.sortBy == 'calls_asc'
                      ? const Icon(Icons.check, color: Color(0xFFFAB400))
                      : null,
                  onTap: () {
                    controller.setSort('calls_asc');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sort_by_alpha),
                  title: const Text('Name (A to Z)'),
                  trailing: controller.sortBy == 'name_asc'
                      ? const Icon(Icons.check, color: Color(0xFFFAB400))
                      : null,
                  onTap: () {
                    controller.setSort('name_asc');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sort_by_alpha),
                  title: const Text('Name (Z to A)'),
                  trailing: controller.sortBy == 'name_desc'
                      ? const Icon(Icons.check, color: Color(0xFFFAB400))
                      : null,
                  onTap: () {
                    controller.setSort('name_desc');
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFilterSheet(BuildContext context, ContactController controller) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Filter Contacts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.people_alt_outlined),
                  title: const Text('All Contacts'),
                  trailing: !controller.onlyFavorites
                      ? const Icon(Icons.check, color: Color(0xFFFAB400))
                      : null,
                  onTap: () {
                    if (controller.onlyFavorites) {
                      controller.toggleOnlyFavorites();
                    }
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.favorite_border, color: Colors.red),
                  title: const Text('Favorites Only'),
                  trailing: controller.onlyFavorites
                      ? const Icon(Icons.check, color: Color(0xFFFAB400))
                      : null,
                  onTap: () {
                    if (!controller.onlyFavorites) {
                      controller.toggleOnlyFavorites();
                    }
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AdBannerCard extends StatelessWidget {
  const AdBannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE8D6), width: 1.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Get winning sales scripts, objection handling tactics & pro tips — free!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C2523),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5238),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Claim your free scripts',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFEEDD),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFFAB400),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
