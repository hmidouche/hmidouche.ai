import 'dart:io';
import 'package:crypto/crypto.dart';

const sdxsExpectedBytes = 682847200;
const sdxsExpectedSha256 = '409ab23582ee074c6b9d5395784fc0741b0599fb9d138686c69087c71678eb6a';

Future<void> checkGgufHeader(String path) async {
  final handle = await File(path).open();
  try {
    final bytes = await handle.read(4);
    if (bytes.length != 4 || bytes[0] != 0x47 || bytes[1] != 0x47 || bytes[2] != 0x55 || bytes[3] != 0x46) {
      throw StateError('الملف لا يحمل ترويسة GGUF صالحة.');
    }
  } finally { await handle.close(); }
}

/// Pinned to the SDXS Q8_0 public file at revision
/// 3144d898d61492f8382ffcabec055733fc5b2a0e, not to its filename.
Future<void> checkSdxsFile(String path, bool Function() active) async {
  final file = File(path);
  if (await file.length() != sdxsExpectedBytes) {
    throw StateError('هذا ليس ملف SDXS Q8_0 المحدد لهذه النسخة، أو أن تنزيله ناقص.');
  }
  await checkGgufHeader(path);
  final stream = file.openRead().map((chunk) {
    if (!active()) throw StateError('أُلغي التحقق.');
    return chunk;
  });
  final digest = await sha256.bind(stream).first;
  if (!active()) throw StateError('أُلغي التحقق.');
  if (digest.toString() != sdxsExpectedSha256) {
    throw StateError('بصمة النموذج لا تطابق SDXS المعتمد. أعد تنزيل الملف من مصدره.');
  }
}
