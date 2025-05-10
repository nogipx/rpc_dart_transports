import 'src/bidirectional/bidirectional.dart' as bidirectional;
import 'src/client_streaming/client_streaming.dart' as client_streaming;
import 'src/server_streaming/server_streaming.dart' as server_streaming;
import 'src/unary/unary.dart' as unary;

Future<void> main() async {
  const delay = Duration(seconds: 5);

  await Future.delayed(delay);
  await bidirectional.main();
  print('--------------------------------');

  await Future.delayed(delay);
  await client_streaming.main();
  print('--------------------------------');

  await Future.delayed(delay);
  await server_streaming.main();
  print('--------------------------------');

  await Future.delayed(delay);
  await unary.main();
}
