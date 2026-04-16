import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class PickedFileBytes {
  final Uint8List bytes;
  final String name;

  const PickedFileBytes({
    required this.bytes,
    required this.name,
  });
}

Future<PickedFileBytes?> pickImageBytes() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
    withReadStream: true,
  );
  final file = result?.files.single;
  if (file == null) return null;

  final bytes = file.bytes ?? await _readStream(file);
  if (bytes == null || bytes.isEmpty) return null;

  return PickedFileBytes(bytes: bytes, name: file.name);
}

Future<Uint8List?> _readStream(PlatformFile file) async {
  final stream = file.readStream;
  if (stream == null) return null;

  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}
