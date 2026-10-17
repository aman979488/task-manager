import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/task.dart';

class TaskSharePrintService {
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
        build: (context) => [
          pw.Text(
            '$title - Task list',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          if (tasks.isEmpty)
            pw.Text('No tasks in this list.')
          else
            ...tasks.map(
              (task) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  '${task.isDone ? '[Done]' : '[Pending]'} ${task.title}'
                  '${task.assignee?.isNotEmpty == true ? ' - ${task.assignee}' : ''}'
                  '${task.deadline?.isNotEmpty == true ? ' (Due: ${task.deadline})' : ''}',
                ),
              ),
            ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => document.save());
  }
}
