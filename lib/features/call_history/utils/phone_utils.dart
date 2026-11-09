class PhoneUtils {
  /// Formats a number for WhatsApp's wa.me URL, which does not accept a plus.
  static String normalize(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    if (number.trimLeft().startsWith('+')) return digits;
    if (digits.startsWith('00')) return digits.substring(2);
    if (digits.length == 10) return '91$digits';
    if (digits.length == 11 && digits.startsWith('0')) {
      return '91${digits.substring(1)}';
    }

    return digits;
  }

  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m ${secs}s';
    if (minutes > 0) return '${minutes}m ${secs}s';
    return '${secs}s';
  }
}