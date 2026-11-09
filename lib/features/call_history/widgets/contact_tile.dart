import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/contact_model.dart';
import '../screens/call_history_view.dart';
import '../viewmodels/call_log_controller.dart';
import 'contact_avatar.dart';

class ContactTile extends StatelessWidget {
  final ContactModel contact;

  const ContactTile({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    final phone = contact.phoneNumbers.isEmpty
        ? 'No number'
        : contact.phoneNumbers.first;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => CallLogController()..loadFor(contact),
                  child: CallHistoryView(contact: contact),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ContactAvatar(contact: contact, radius: 27),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contact.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E2126),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _AddGroupButton(
                            onTap: () =>
                                _showAddToGroupDialog(context, contact),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              phone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF4A4F5B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Total Calls : ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E2126),
                                  ),
                                ),
                                TextSpan(
                                  text: '${contact.calculatedTotalCalls}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E2126),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _ActionIconButton(
                            tooltip: 'Copy Number',
                            icon: const Icon(
                              Icons.copy_outlined,
                              size: 22,
                              color: Color(0xFF8A93A0),
                            ),
                            onTap: () => _copyNumber(context, phone),
                          ),
                          _ActionIconButton(
                            tooltip: 'Send SMS',
                            icon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 22,
                              color: Color(0xFF0096C7),
                            ),
                            onTap: () => _sendSms(context, phone),
                          ),
                          _ActionIconButton(
                            tooltip: 'WhatsApp',
                            icon: const WhatsAppOutlineIcon(
                              size: 22,
                              color: Color(0xFF25D366),
                            ),
                            onTap: () => _openWhatsApp(context, phone),
                          ),
                          _ActionIconButton(
                            tooltip: 'Call',
                            icon: const Icon(
                              Icons.call_outlined,
                              size: 22,
                              color: Color(0xFF00838F),
                            ),
                            onTap: () => _makeCall(context, phone),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _copyNumber(BuildContext context, String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied $phone to clipboard'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static Future<void> _sendSms(BuildContext context, String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'sms', path: clean);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open SMS app')));
    }
  }

  static Future<void> _openWhatsApp(BuildContext context, String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  static Future<void> _makeCall(BuildContext context, String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not place call')));
    }
  }

  static Future<void> _showAddToGroupDialog(
    BuildContext context,
    ContactModel contact,
  ) async {
    final groups = ['Family', 'Work', 'Friends', 'Clients', 'VIP'];
    String? selectedGroup;
    final customController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
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
                Text(
                  'Add "${contact.name}" to Group',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final group in groups)
                      ChoiceChip(
                        label: Text(group),
                        selected: selectedGroup == group,
                        onSelected: (val) {
                          setSheetState(() {
                            selectedGroup = val ? group : null;
                          });
                        },
                        selectedColor: const Color(0xFFFAB400),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: customController,
                  decoration: InputDecoration(
                    hintText: 'Or enter custom group name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFAB400),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      final groupName = customController.text.trim().isNotEmpty
                          ? customController.text.trim()
                          : selectedGroup;
                      Navigator.pop(ctx);
                      if (groupName != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added "${contact.name}" to $groupName',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Add to Group',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddGroupButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddGroupButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFAB400), width: 1.2),
          color: Colors.transparent,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: Color(0xFFEAA61A)),
            SizedBox(width: 3),
            Text(
              'Add to Group',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEAA61A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final Widget icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: icon,
        ),
      ),
    );
  }
}

class WhatsAppOutlineIcon extends StatelessWidget {
  final double size;
  final Color color;

  const WhatsAppOutlineIcon({
    super.key,
    this.size = 22,
    this.color = const Color(0xFF25D366),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _WhatsAppOutlinePainter(color: color),
    );
  }
}

class _WhatsAppOutlinePainter extends CustomPainter {
  final Color color;

  const _WhatsAppOutlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final bubble = Path();
    final center = Offset(w * 0.5, h * 0.46);
    final r = w * 0.43;

    bubble.addArc(Rect.fromCircle(center: center, radius: r), 0.65, 5.35);
    bubble.lineTo(w * 0.16, h * 0.88);
    bubble.lineTo(w * 0.32, h * 0.78);
    canvas.drawPath(bubble, paint);

    final handset = Path();
    handset.moveTo(w * 0.38, h * 0.56);
    handset.cubicTo(w * 0.38, h * 0.44, w * 0.44, h * 0.38, w * 0.56, h * 0.38);
    handset.lineTo(w * 0.62, h * 0.43);
    handset.lineTo(w * 0.55, h * 0.48);
    handset.lineTo(w * 0.52, h * 0.45);
    handset.cubicTo(w * 0.47, h * 0.47, w * 0.45, h * 0.52, w * 0.46, h * 0.56);
    handset.lineTo(w * 0.42, h * 0.61);
    handset.close();

    final handsetPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(handset, handsetPaint);
  }

  @override
  bool shouldRepaint(covariant _WhatsAppOutlinePainter oldDelegate) =>
      oldDelegate.color != color;
}
