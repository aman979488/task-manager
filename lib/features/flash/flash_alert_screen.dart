import 'dart:async';

import 'package:flutter/material.dart';

class FlashAlertScreen extends StatefulWidget {
  const FlashAlertScreen({
    super.key,
    required this.senderName,
    required this.text,
    required this.onRespond,
  });

  final String senderName;
  final String text;
  final Future<void> Function({String? response, String? responseText})
  onRespond;

  @override
  State<FlashAlertScreen> createState() => _FlashAlertScreenState();
}

class _FlashAlertScreenState extends State<FlashAlertScreen>
    with SingleTickerProviderStateMixin {
  static const _yellow = Color(0xFFFBE64E);
  static const _responses = [
    'Finished',
    'In process',
    'Will take time',
    'Forgot',
  ];
  final _otherResponseController = TextEditingController();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final Timer _clock;
  DateTime _now = DateTime.now();
  bool _isSubmitting = false;
  bool _showOtherResponse = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _otherResponseController.addListener(_refresh);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clock.cancel();
    _pulse.dispose();
    _otherResponseController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  Future<void> _submitResponse({String? response, String? responseText}) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      await widget.onRespond(response: response, responseText: responseText);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = 'Could not send your response. Please try again.';
      });
    }
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
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$hour:$minute',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.w200,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          amPm,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ScaleTransition(
                      scale: Tween(begin: 0.9, end: 1.1).animate(
                        CurvedAnimation(
                          parent: _pulse,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _yellow.withValues(alpha: 0.15),
                          border: Border.all(color: _yellow, width: 2),
                        ),
                        child: const Icon(Icons.bolt, size: 48, color: _yellow),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Message from ${widget.senderName}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Choose a response',
                      style: TextStyle(
                        color: _yellow,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final response in _responses)
                          OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => _submitResponse(response: response),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: _yellow),
                            ),
                            child: Text(response),
                          ),
                        OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(() {
                                  _showOtherResponse = true;
                                  _submitError = null;
                                }),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: _yellow),
                          ),
                          child: const Text('Others'),
                        ),
                      ],
                    ),
                    if (_showOtherResponse) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _otherResponseController,
                        maxLength: 500,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Type your response',
                          hintStyle: TextStyle(color: Colors.white60),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white54),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: _yellow),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              _isSubmitting ||
                                  _otherResponseController.text.trim().isEmpty
                              ? null
                              : () => _submitResponse(
                                  response: 'Others',
                                  responseText: _otherResponseController.text
                                      .trim(),
                                ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _yellow,
                            foregroundColor: const Color(0xFF6B5800),
                          ),
                          child: const Text('Send response'),
                        ),
                      ),
                    ],
                    if (_submitError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _submitError!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _yellow,
                          foregroundColor: const Color(0xFF6B5800),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () => _submitResponse(),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Got it',
                                style: TextStyle(
                                  fontSize: 18,
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
        ),
      ),
    );
  }
}
