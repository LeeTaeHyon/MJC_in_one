import "dart:typed_data";

import "package:file_picker/file_picker.dart";

Future<Uint8List> readPlatformFileBytes(PlatformFile file) async {
  if (file.bytes != null && file.bytes!.isNotEmpty) {
    return file.bytes!;
  }
  return Uint8List(0);
}
