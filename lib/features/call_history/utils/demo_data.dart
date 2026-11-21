import '../models/call_log_model.dart';
import '../models/contact_model.dart';

class DemoData {
  static const List<ContactModel> contacts = [
    ContactModel(
      id: '1',
      name: 'Test Contact 1',
      phoneNumbers: ['+91 90000 00001'],
      totalCalls: 10,
    ),
    ContactModel(
      id: '2',
      name: 'Test Contact 2',
      phoneNumbers: ['+91 90000 00002'],
      totalCalls: 5,
    ),
  ];

  static List<CallLogModel> callLogsFor(ContactModel contact) {
    final number = contact.phoneNumbers.isEmpty
        ? ''
        : contact.phoneNumbers.first;
    final seed = contact.name.codeUnits.fold<int>(0, (a, b) => a + b);
    const kinds = [CallKind.incoming, CallKind.outgoing, CallKind.missed];
    final now = DateTime.now();

    return List.generate(3, (i) {
      final kind = kinds[(seed + i) % 3];
      return CallLogModel(
        number: number,
        name: contact.name,
        kind: kind,
        durationSeconds: kind == CallKind.missed ? 0 : 30,
        time: now.subtract(Duration(hours: i + 1)),
      );
    });
  }
}
