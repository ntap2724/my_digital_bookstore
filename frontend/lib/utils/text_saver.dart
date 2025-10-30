import 'text_saver_stub.dart'
    if (dart.library.io) 'text_saver_io.dart'
    if (dart.library.html) 'text_saver_web.dart';

Future<String?> saveTextToFile(String filename, String content) {
  return saveTextFileImpl(filename, content);
}
