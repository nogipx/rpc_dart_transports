#!/usr/bin/env dart

import 'dart:io';

const targets = {
  'macos': 'rpc_dart_router-macos',
  'linux': 'rpc_dart_router-linux',
  'windows': 'rpc_dart_router-windows.exe',
};

void main() async {
  print('🚀 Собираем RPC Dart Router для всех платформ...\n');

  // Создаем папку build
  final buildDir = Directory('build');
  if (!buildDir.existsSync()) {
    buildDir.createSync();
  }

  // Собираем для текущей платформы
  await _buildCurrent();

  // Собираем для Linux через Docker (если Docker доступен)
  if (Platform.isMacOS || Platform.isWindows) {
    await _buildLinuxWithDocker();
  }

  print('\n✅ Сборка завершена! Файлы в папке build/');
  _listBuiltFiles();
}

Future<void> _buildCurrent() async {
  String targetName;
  if (Platform.isMacOS) {
    targetName = targets['macos']!;
  } else if (Platform.isLinux) {
    targetName = targets['linux']!;
  } else if (Platform.isWindows) {
    targetName = targets['windows']!;
  } else {
    targetName = 'rpc_dart_router-${Platform.operatingSystem}';
  }

  print('📦 Собираем для ${Platform.operatingSystem}...');

  final result = await Process.run(
    'dart',
    ['compile', 'exe', 'bin/rpc_dart_router.dart', '-o', 'build/$targetName'],
  );

  if (result.exitCode == 0) {
    print('✅ ${Platform.operatingSystem}: build/$targetName');
  } else {
    print('❌ Ошибка сборки для ${Platform.operatingSystem}:');
    print(result.stderr);
  }
}

Future<void> _buildLinuxWithDocker() async {
  print('🐳 Проверяем Docker для сборки Linux версии...');

  // Проверяем доступность Docker
  final dockerCheck = await Process.run('docker', ['--version']);
  if (dockerCheck.exitCode != 0) {
    print('⚠️  Docker недоступен, пропускаем сборку Linux версии');
    return;
  }

  print('📦 Собираем Linux версию через Docker...');

  // Создаем Dockerfile для сборки
  final dockerfile = '''
FROM dart:stable

WORKDIR /app
COPY . .
RUN dart pub get
RUN dart compile exe bin/rpc_dart_router.dart -o rpc_dart_router-linux

CMD ["./rpc_dart_router-linux"]
''';

  await File('Dockerfile.build').writeAsString(dockerfile);

  try {
    // Собираем образ
    final buildResult = await Process.run(
      'docker',
      ['build', '-f', 'Dockerfile.build', '-t', 'rpc-dart-router-builder', '.'],
    );

    if (buildResult.exitCode != 0) {
      print('❌ Ошибка сборки Docker образа');
      return;
    }

    // Извлекаем бинарь из контейнера
    final copyResult = await Process.run(
      'docker',
      [
        'run',
        '--rm',
        '-v',
        '${Directory.current.path}/build:/output',
        'rpc-dart-router-builder',
        'cp',
        'rpc_dart_router-linux',
        '/output/'
      ],
    );

    if (copyResult.exitCode == 0) {
      print('✅ Linux: build/rpc_dart_router-linux');
    } else {
      print('❌ Ошибка извлечения Linux бинаря');
    }
  } finally {
    // Убираем временный Dockerfile
    final dockerfileTemp = File('Dockerfile.build');
    if (dockerfileTemp.existsSync()) {
      dockerfileTemp.deleteSync();
    }
  }
}

void _listBuiltFiles() {
  final buildDir = Directory('build');
  if (!buildDir.existsSync()) return;

  print('\n📂 Собранные файлы:');
  for (final file in buildDir.listSync()) {
    if (file is File) {
      final stat = file.statSync();
      final size = (stat.size / 1024 / 1024).toStringAsFixed(1);
      print('  ${file.path} ($size MB)');
    }
  }
}
