enum CallKind { incoming, outgoing, missed, rejected, blocked, other }

class CallLogModel {
  final String number;
  final String? name;
  final CallKind kind;
  final int durationSeconds;
  final DateTime time;

  const CallLogModel({
    required this.number,
    this.name,
    required this.kind,
    required this.durationSeconds,
    required this.time,
  });

  factory CallLogModel.fromMap(Map<Object?, Object?> entry) {
    return CallLogModel(
      number: entry['number'] as String? ?? '',
      name: entry['name'] as String?,
      kind: _mapType(entry['type'] as int? ?? 0),
      durationSeconds: entry['duration'] as int? ?? 0,
      time: DateTime.fromMillisecondsSinceEpoch(
        entry['timestamp'] as int? ?? 0,
      ),
    );
  }

  static CallKind _mapType(int type) {
    switch (type) {
      case 1:
      case 7:
      case 101:
        return CallKind.incoming;
      case 2:
      case 100:
        return CallKind.outgoing;
      case 3:
        return CallKind.missed;
      case 5:
        return CallKind.rejected;
      case 6:
        return CallKind.blocked;
      default:
        return CallKind.other;
    }
  }
}
