import 'package:flutter/material.dart';

Future<DateTime?> showDateTimePickerWithTabs(
  BuildContext context, {
  DateTime? initial,
}) async {
  var selectedDate = initial ?? DateTime.now();
  var selectedTime = TimeOfDay.fromDateTime(initial ?? DateTime.now());
  var tabIndex = 0;

  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            child: SizedBox(
              height: 430,
              child: Column(
                children: [
                  Row(
                    children: [
                      _DateTimeTabButton(
                        title: 'DATE',
                        selected: tabIndex == 0,
                        onTap: () => setState(() => tabIndex = 0),
                      ),
                      _DateTimeTabButton(
                        title: 'TIME',
                        selected: tabIndex == 1,
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            selectedTime = picked;
                            setState(() => tabIndex = 1);
                          }
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: tabIndex == 0
                        ? CalendarDatePicker(
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            onDateChanged: (date) => selectedDate = date,
                          )
                        : Center(
                            child: Text(
                              selectedTime.format(context),
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('CANCEL'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFBE64E),
                          ),
                          onPressed: () {
                            Navigator.pop(
                              dialogContext,
                              DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              ),
                            );
                          },
                          child: const Text(
                            'SAVE',
                            style: TextStyle(color: Color(0xFF6B5800)),
                          ),
                        ),
                      ],
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

class _DateTimeTabButton extends StatelessWidget {
  const _DateTimeTabButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFF6B5800) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? const Color(0xFF6B5800) : Colors.black54,
            ),
          ),
        ),
      ),
    ),
  );
}
