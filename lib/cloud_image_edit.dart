import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'safe_file_read.dart';
import 'gradio_events.dart';

/// Experimental public ZeroGPU endpoint; never falls back to paid inference.
class CloudImageEdit {
  static const host = 'qwen-qwen-image-edit.hf.space';
  final HttpClient client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  bool cancelled = false;

  void close() { cancelled = true; client.close(force: true); }

  Future<HttpClientResponse> open(String method, String path) async {
    if (cancelled) throw StateError('أُلغي الاتصال.');
    final request = await client.openUrl(method, Uri.https(host, path));
    return request.close();
  }

  Future<String> body(HttpClientResponse response) async {
    final text = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('تعذّر الاتصال بالخدمة (${response.statusCode}). قد تكون الحصة انتهت أو الخدمة مشغولة.');
    }
    return text;
  }

  Future<Uint8List> edit(File file, String prompt, void Function(String) progress) async {
    final size = await file.length();
    if (size > 10 * 1024 * 1024) throw StateError('اختر صورة أصغر من 10MB.');
    final bytes = await readLimitedFile(file, 10 * 1024 * 1024);
    progress('جار رفع الصورة إلى Qwen على Hugging Face…');
    final boundary = 'hmidouche${DateTime.now().microsecondsSinceEpoch}';
    final request = await client.postUrl(Uri.https(host, '/gradio_api/upload'));
    request.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');
    final extension = file.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    request.add(utf8.encode('--$boundary\r\nContent-Disposition: form-data; name="files"; filename="input.$extension"\r\nContent-Type: application/octet-stream\r\n\r\n'));
    request.add(bytes);
    request.add(utf8.encode('\r\n--$boundary--\r\n'));
    final uploaded = jsonDecode(await body(await request.close())) as List<dynamic>;
    if (uploaded.isEmpty || uploaded.first is! String) throw StateError('لم تُرجع الخدمة مسار الصورة.');
    final submit = await client.postUrl(Uri.https(host, '/gradio_api/call/infer'));
    submit.headers.contentType = ContentType.json;
    submit.write(jsonEncode({'data': [
      {'path': uploaded.first, 'meta': {'_type': 'gradio.FileData'}},
      prompt, 42, false, 4, 12, false,
    ]}));
    final accepted = jsonDecode(await body(await submit.close())) as Map<String, dynamic>;
    final id = accepted['event_id'];
    if (id is! String || !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw StateError('تعذّر الحصول على رقم متابعة الطلب.');
    }
    progress('الطلب في الانتظار أو المعالجة. الحصة المجانية قد تمنع الإكمال.');
    final result = await waitForResult(id).timeout(const Duration(minutes: 4));
    final output = result.first;
    if (output is! Map || output['url'] is! String) throw StateError('لم تُرجع الخدمة رابط صورة.');
    final url = Uri.parse(output['url'] as String);
    if (url.scheme != 'https' || url.host != host) throw StateError('رابط النتيجة خارج المصدر المعتمد.');
    progress('جار استلام الصورة المعدّلة…');
    final download = await client.getUrl(url);
    download.followRedirects = false;
    final response = await download.close();
    if (response.statusCode != 200) throw StateError('تعذّر تنزيل النتيجة.');
    final builder = BytesBuilder();
    await for (final chunk in response.timeout(const Duration(seconds: 45))) {
      builder.add(chunk);
      if (builder.length > 20 * 1024 * 1024) throw StateError('النتيجة أكبر من حد التنزيل.');
    }
    return builder.takeBytes();
  }

  Future<List<dynamic>> waitForResult(String id) async {
    final response = await open('GET', '/gradio_api/call/infer/$id');
    if (response.statusCode != 200) throw StateError('تعذّرت متابعة الطلب (${response.statusCode}).');
    return parseGradioResult(response.transform(utf8.decoder));
  }
}
