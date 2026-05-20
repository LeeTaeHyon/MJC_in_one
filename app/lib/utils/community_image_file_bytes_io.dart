import "dart:io";
import "dart:typed_data";

import "package:file_picker/file_picker.dart";

Future<Uint8List> readPlatformFileBytes(PlatformFile file) async {
  if (file.bytes != null && file.bytes!.isNotEmpty) {
    return file.bytes!;
  }
  final String? path = file.path;
  if (path != null && path.isNotEmpty) {
    return File(path).readAsBytes();
  }
  return Uint8List(0);
}
