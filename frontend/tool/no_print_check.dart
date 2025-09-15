import 'dart:io';

final _printRe = RegExp(r'(^|[^A-Za-z_])print\s*\(');

void main() {
  final roots = [Directory('lib'), Directory('test')];
  final offenders = <String>[];
  for (final root in roots) {
    if (!root.existsSync()) continue;
    for (final file
        in root
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//')) continue; // ignore comments
        if (trimmed.contains('debugPrint')) continue; // allow debugPrint
        if (_printRe.hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
  }
  if (offenders.isNotEmpty) {
    stderr.writeln('Found disallowed print(...) statements:');
    for (final o in offenders) {
      stderr.writeln('  $o');
    }
    stderr.writeln('Use AppLogger.(d|i|w|e) or debugPrint instead.');
    exit(1);
  }
}
