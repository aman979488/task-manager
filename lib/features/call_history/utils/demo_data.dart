import '../models/call_log_model.dart';
import '../models/contact_model.dart';

class DemoData {
  static const List<ContactModel> contacts = [
    ContactModel(
      id: '1',
      name: 'Didi 😘',
      phoneNumbers: ['+918237969266'],
      totalCalls: 3757,
    ),
    ContactModel(
      id: '2',
      name: 'Mummy ❤️',
      phoneNumbers: ['+919209985689'],
      totalCalls: 2135,
    ),
    ContactModel(
      id: '3',
      name: 'Karuna Sycs',
      phoneNumbers: ['+917058033351'],
      totalCalls: 1596,
    ),
    ContactModel(
      id: '4',
      name: '🌍papa ❤️',
      phoneNumbers: ['+918452952616'],
      totalCalls: 892,
    ),
    ContactModel(
      id: '5',
      name: 'Aarav Sharma',
      phoneNumbers: ['+91 98765 43210'],
      totalCalls: 432,
    ),
    ContactModel(
      id: '6',
      name: 'Ananya Iyer',
      phoneNumbers: ['+91 98200 11223'],
      totalCalls: 184,
    ),
    ContactModel(
      id: '7',
      name: 'Bhavesh Patil',
      phoneNumbers: ['+91 99877 65432'],
      totalCalls: 671,
    ),
  ];

  static List<CallLogModel> callLogsFor(ContactModel contact) {
    final number = contact.phoneNumbers.isEmpty
        ? ''
        : contact.phoneNumbers.first;
    final seed = contact.name.codeUnits.fold<int>(0, (a, b) => a + b);
    const kinds = [CallKind.incoming, CallKind.outgoing, CallKind.missed];
    final now = DateTime.now();

    return List.generate(8, (i) {
      final kind = kinds[(seed + i) % 3];
      return CallLogModel(
        number: number,
        name: contact.name,
        kind: kind,
        durationSeconds: kind == CallKind.missed
            ? 0
            : 20 + ((seed * (i + 3)) % 600),
        time: now.subtract(
          Duration(hours: i * 11 + (seed % 5), minutes: (i * 17) % 60),
        ),
      );
    });
  }
}
