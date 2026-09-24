import 'dart:convert';
import 'dart:io';

/// Run after `flutter build windows --release`. Keep the SQLite runtime used
/// by sqflite_common_ffi with the app instead of depending on Windows' copy.
Future<void> main(List<String> arguments) async {
  final config = File('.dart_tool/package_config.json').absolute;
  final json = jsonDecode(await config.readAsString()) as Map<String, dynamic>;
  final packages = json['packages'] as List;
  final package = packages
      .cast<Map<String, dynamic>>()
      .singleWhere((entry) => entry['name'] == 'sqflite_common_ffi');
  final root = config.uri.resolve('${package['rootUri']}/');
  final source = File.fromUri(root.resolve('lib/src/windows/sqlite3.dll'));
  if (arguments.contains('--check')) {
    if (!await source.exists()) {
      throw StateError('Missing SQLite runtime: ${source.path}');
    }
    stdout.writeln('SQLite runtime is available: ${source.path}');
    return;
  }
  final release = Directory('build/windows/x64/runner/Release');
  if (!await source.exists() ||
      !await File('${release.path}/HISAAB.exe').exists()) {
    throw StateError(
        'Build the Windows release and resolve sqflite_common_ffi before bundling SQLite.');
  }
  await source.copy('${release.path}/sqlite3.dll');
  stdout.writeln('Bundled SQLite runtime: ${release.path}/sqlite3.dll');
}
