import 'package:flutter/material.dart';

class SheetOptionButton extends StatelessWidget {
  const SheetOptionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.displayText,
    required this.selected,
    required this.compact,
    required this.onTap,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final String displayText;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: compact ? 112 : null,
      height: compact ? 40 : null,
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFFBE64E).withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(compact ? 10 : 20),
        border: Border.all(
          color: selected ? const Color(0xFF6B5800) : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(compact ? 10 : 20),
          onTap: onTap,
          child: Padding(
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 4, vertical: 4)
                : const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
            child: compact
                ? Row(
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: selected
                            ? const Color(0xFF6B5800)
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          displayText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? const Color(0xFF6B5800)
                                : Colors.grey.shade700,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: selected
                            ? IconButton(
                                tooltip: 'Clear $label',
                                onPressed: onClear,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 20,
                                  height: 20,
                                ),
                                icon: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Color(0xFF6B5800),
                                ),
                              )
                            : null,
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: selected
                            ? const Color(0xFF6B5800)
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          displayText,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? const Color(0xFF6B5800)
                                : Colors.grey.shade700,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (selected)
                        IconButton(
                          tooltip: 'Clear $label',
                          onPressed: onClear,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: Color(0xFF6B5800),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}
