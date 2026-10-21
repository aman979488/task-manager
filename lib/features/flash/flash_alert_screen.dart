import 'dart:async';

import 'package:flutter/material.dart';

class FlashAlertScreen extends StatefulWidget {
  const FlashAlertScreen({
    super.key,
    required this.senderName,
    required this.text,
    required this.onDismiss,
  });

  final String senderName;
  final String text;
  final VoidCallback onDismiss;

  @override
  State<FlashAlertScreen> createState() => _FlashAlertScreenState();
}

class _FlashAlertScreenState extends State<FlashAlertScreen>
    with SingleTickerProviderStateMixin {
  static const _yellow = Color(0xFFFBE64E);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final minute = _now.minute.toString().padLeft(2, '0');
    final amPm = _now.hour >= 12 ? 'PM' : 'AM';

    return Positioned.fill(
      child: Material(
        color: const Color(0xFF14110A),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              children: [
                const Text(
                  '⚡ FLASH MESSAGE',
                  style: TextStyle(
                    color: _yellow,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$hour:$minute',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 76,
                        fontWeight: FontWeight.w200,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      amPm,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ScaleTransition(
                  scale: Tween(begin: 0.9, end: 1.1).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _yellow.withValues(alpha: 0.15),
                      border: Border.all(color: _yellow, width: 2),
                    ),
                    child: const Icon(Icons.bolt, size: 56, color: _yellow),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Message from ${widget.senderName}',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _yellow,
                      foregroundColor: const Color(0xFF6B5800),
                    ),
                    onPressed: widget.onDismiss,
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
