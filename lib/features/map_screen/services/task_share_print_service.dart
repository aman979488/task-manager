import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/task.dart';

class TaskSharePrintService {
  static const _ink = pdf.PdfColor.fromInt(0xFF263238);
  static const _mutedInk = pdf.PdfColor.fromInt(0xFF607D8B);
  static const _brand = pdf.PdfColor.fromInt(0xFF6B5800);
  static const _line = pdf.PdfColor.fromInt(0xFFE4E8EA);
  static const _surface = pdf.PdfColor.fromInt(0xFFF7F8F8);

  Future<void> shareTasks(String title, List<Task> tasks) async {
    final contents = tasks.isEmpty
        ? 'No tasks in this list.'
        : tasks
              .map(
                (task) =>
                    '${task.isDone ? '[Done]' : '[Pending]'} ${task.title}'
                    '${task.assignee?.isNotEmpty == true ? ' — ${task.assignee}' : ''}'
                    '${task.deadline?.isNotEmpty == true ? ' (Due: ${task.deadline})' : ''}',
              )
              .join('\n');
    await SharePlus.instance.share(
      ShareParams(subject: 'Task list', text: '$title\n\n$contents'),
    );
  }

  Future<void> printTasks(String title, List<Task> tasks) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 42),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(
            title,
            style: pw.TextStyle(color: _mutedInk, fontSize: 9),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _line)),
          ),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(color: _mutedInk, fontSize: 9),
          ),
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: pw.BoxDecoration(
              color: _surface,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: _line),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 4,
                  height: 42,
                  decoration: pw.BoxDecoration(
                    color: _brand,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          color: _ink,
                          fontSize: 19,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}  |  Printed ${_formattedDate(DateTime.now())}',
                        style: pw.TextStyle(color: _mutedInk, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          if (tasks.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: _surface,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: _line),
              ),
              child: pw.Center(
                child: pw.Text(
                  'No tasks in this list.',
                  style: pw.TextStyle(color: _mutedInk, fontSize: 11),
                ),
              ),
            )
          else
            ...tasks.indexed.map((entry) => _taskRow(entry.$1 + 1, entry.$2)),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => document.save());
  }

  pw.Widget _taskRow(int index, Task task) {
    final title = _withoutEmoji(task.title).trim();
    final metadata = <String>[
      if (_withoutEmoji(task.priority ?? '').trim().isNotEmpty)
        'Priority: ${_withoutEmoji(task.priority ?? '').trim()}',
      if (_withoutEmoji(task.assignee ?? '').trim().isNotEmpty)
        'Assigned to: ${_withoutEmoji(task.assignee ?? '').trim()}',
      if (_withoutEmoji(task.deadline ?? '').trim().isNotEmpty)
        'Due: ${_formattedTaskDate(_withoutEmoji(task.deadline ?? '').trim())}',
      if (_withoutEmoji(task.workType ?? '').trim().isNotEmpty)
        'Type: ${_withoutEmoji(task.workType ?? '').trim()}',
      if (_withoutEmoji(task.clientName ?? '').trim().isNotEmpty)
        'Client: ${_withoutEmoji(task.clientName ?? '').trim()}',
    ];
    final note = _withoutEmoji(task.note).trim();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: pdf.PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _line),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 23,
            height: 23,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _surface,
              borderRadius: pw.BorderRadius.circular(7),
            ),
            child: pw.Text(
              '$index',
              style: pw.TextStyle(
                color: _mutedInk,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        title.isEmpty ? 'Untitled task' : title,
                        style: pw.TextStyle(
                          color: _ink,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      task.isDone ? 'DONE' : 'PENDING',
                      style: pw.TextStyle(
                        color: task.isDone
                            ? const pdf.PdfColor.fromInt(0xFF2E7D32)
                            : _brand,
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (metadata.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(
                    metadata.join('   |   '),
                    style: pw.TextStyle(color: _mutedInk, fontSize: 8),
                  ),
                ],
                if (note.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(
                    note,
                    style: pw.TextStyle(color: _mutedInk, fontSize: 8),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formattedDate(DateTime date) =>
      '${_monthName(date.month)} ${date.day}, ${date.year}';

  String _formattedTaskDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${_monthName(date.month)} ${date.day}, ${date.year}';
  }

  String _withoutEmoji(String value) => String.fromCharCodes(
    value.runes.where((rune) => !_isEmojiCodePoint(rune)),
  );

  bool _isEmojiCodePoint(int rune) =>
      rune == 0x00A9 ||
      rune == 0x00AE ||
      rune == 0x203C ||
      rune == 0x2049 ||
      rune == 0x2122 ||
      rune == 0x2139 ||
      (rune >= 0x2194 && rune <= 0x2199) ||
      (rune >= 0x21A9 && rune <= 0x21AA) ||
      (rune >= 0x231A && rune <= 0x231B) ||
      rune == 0x2328 ||
      rune == 0x23CF ||
      (rune >= 0x23E9 && rune <= 0x23F3) ||
      (rune >= 0x23F8 && rune <= 0x23FA) ||
      rune == 0x24C2 ||
      (rune >= 0x25AA && rune <= 0x25AB) ||
      rune == 0x25B6 ||
      rune == 0x25C0 ||
      (rune >= 0x25FB && rune <= 0x25FE) ||
      (rune >= 0x2600 && rune <= 0x27BF) ||
      (rune >= 0x2934 && rune <= 0x2935) ||
      (rune >= 0x2B05 && rune <= 0x2B07) ||
      (rune >= 0x2B1B && rune <= 0x2B1C) ||
      rune == 0x2B50 ||
      rune == 0x2B55 ||
      rune == 0x3030 ||
      rune == 0x303D ||
      rune == 0x3297 ||
      rune == 0x3299 ||
      (rune >= 0x1F000 && rune <= 0x1FAFF) ||
      (rune >= 0x1FC00 && rune <= 0x1FFFD) ||
      (rune >= 0xE0020 && rune <= 0xE007F) ||
      rune == 0x200D ||
      rune == 0x20E3 ||
      rune == 0xFE0E ||
      rune == 0xFE0F;

  String _monthName(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}
