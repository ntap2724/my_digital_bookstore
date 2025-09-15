import 'dart:io';

void main(List<String> args) {
  final roots = [Directory('lib'), Directory('test')];
  for (final root in roots) {
    if (!root.existsSync()) continue;
    for (final file in root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      _processFile(file);
    }
  }
}

void _processFile(File file) {
  final original = file.readAsStringSync();
  final lines = original.split('\n');

  // Find first and last import directive block
  int? firstImport;
  int? lastImport;
  bool isImport(String line) => line.trimLeft().startsWith('import ');
  for (var i = 0; i < lines.length; i++) {
    if (isImport(lines[i])) {
      firstImport ??= i;
      lastImport = i;
    } else if (firstImport != null && lines[i].trim().isNotEmpty && !lines[i].trim().startsWith('//')) {
      break;
    }
  }
  if (firstImport == null || lastImport == null) return;

  final before = lines.sublist(0, firstImport);
  final middle = lines.sublist(firstImport, lastImport + 1);
  final after = lines.sublist(lastImport + 1);

  final dart = <String>[];
  final pkg = <String>[];
  final rel = <String>[];

  String? uriFrom(String l) {
    final s = l;
    var i1 = s.indexOf("'");
    var i2 = s.indexOf('"');
    int start;
    String quote;
    if (i1 == -1 && i2 == -1) return null;
    if (i2 != -1 && (i1 == -1 || i2 < i1)) {
      start = i2;
      quote = '"';
    } else {
      start = i1;
      quote = "'";
    }
    final end = s.indexOf(quote, start + 1);
    if (end == -1) return null;
    return s.substring(start + 1, end);
  }

  for (final l in middle) {
    if (!isImport(l)) continue;
    final uri = uriFrom(l) ?? '';
    if (uri.startsWith('dart:')) {
      dart.add(l);
    } else if (uri.startsWith('package:')) {
      pkg.add(l);
    } else {
      rel.add(l);
    }
  }

  dart.sort();
  pkg.sort();
  rel.sort();

  final newMiddle = <String>[];
  if (dart.isNotEmpty) newMiddle.addAll(dart);
  if (pkg.isNotEmpty) {
    if (newMiddle.isNotEmpty) newMiddle.add('');
    newMiddle.addAll(pkg);
  }
  if (rel.isNotEmpty) {
    if (newMiddle.isNotEmpty) newMiddle.add('');
    newMiddle.addAll(rel);
  }

  final updated = [
    ...before,
    ...newMiddle,
    ...after,
  ].join('\n');

  if (updated != original) {
    file.writeAsStringSync(updated);
  }
}
