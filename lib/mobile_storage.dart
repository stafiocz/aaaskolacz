import 'dart:convert';
import 'dart:io';

class MobilePracticeStorage {
  MobilePracticeStorage(this.file);
  final File file;

  String? read(String key) {
    if (!file.existsSync()) return null;
    return (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)[key]
        as String?;
  }

  void write(String key, String? value) {
    final data = file.existsSync()
        ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic>
        : <String, dynamic>{};
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
    final temporary = File('${file.path}.tmp');
    temporary.writeAsStringSync(jsonEncode(data), flush: true);
    temporary.renameSync(file.path);
  }
}
