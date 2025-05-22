import 'package:rpc_dart/rpc_dart.dart';

import '../_index.dart';

void main() async {
  // Выберите один из примеров для запуска, раскомментировав нужную строку

  // Пример с изолятами
  await IsolateRpcExample.run();

  // Пример с транспортом в памяти (без изолятов)
  // await InMemoryRpcExample.run();
}
