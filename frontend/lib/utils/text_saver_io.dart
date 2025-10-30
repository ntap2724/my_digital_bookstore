import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String?> saveTextFileImpl(String filename, String content) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(content);
    return file.path;
  } catch (e) {
    return null;
  }
}
