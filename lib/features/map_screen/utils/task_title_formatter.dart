String capitalizeFirstCharacter(String value) {
  if (value.isEmpty) return value;

  final runes = value.runes;
  return '${String.fromCharCode(runes.first).toUpperCase()}'
      '${String.fromCharCodes(runes.skip(1))}';
}
