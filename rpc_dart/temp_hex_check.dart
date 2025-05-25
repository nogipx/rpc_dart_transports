void main() {
  final num = 1000000000000;
  print('Hex: ${num.toRadixString(16)}');

  // Проверка ожидаемого значения
  final expectedHex = '00000e8d4a51000';
  print('Expected: $expectedHex');

  // Проверка байтового представления
  final bytes = [];
  bytes.add((num >> 56) & 0xFF);
  bytes.add((num >> 48) & 0xFF);
  bytes.add((num >> 40) & 0xFF);
  bytes.add((num >> 32) & 0xFF);
  bytes.add((num >> 24) & 0xFF);
  bytes.add((num >> 16) & 0xFF);
  bytes.add((num >> 8) & 0xFF);
  bytes.add(num & 0xFF);

  print(
      'Bytes: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('')}');
}
