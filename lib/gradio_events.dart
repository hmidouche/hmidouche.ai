import 'dart:convert';

/// Parses SSE without assuming TCP chunks align to lines or UTF-8 characters.
Future<List<dynamic>> parseGradioResult(Stream<String> chunks) async {
  String event = '';
  final data = <String>[];
  var characters = 0;
  List<dynamic>? dispatch() {
    if (data.isEmpty) return null;
    final payload = data.join('\n');
    data.clear();
    if (event == 'error') {
      throw StateError('أعادت الخدمة خطأ دون تفاصيل كافية؛ لم يتم استلام صورة.');
    }
    if (event == 'complete') {
      final result = jsonDecode(payload);
      if (result is List<dynamic> && result.isNotEmpty) return result;
      throw StateError('نتيجة غير متوقعة من الخدمة.');
    }
    return null;
  }
  await for (final line in chunks.transform(const LineSplitter())) {
    characters += line.length;
    if (characters > 1048576) throw StateError('رد المتابعة أكبر من الحد المسموح.');
    if (line.startsWith(':')) continue;
    if (line.startsWith('event:')) event = line.substring(6).trim();
    if (line.startsWith('data:')) data.add(line.substring(5).trim());
    if (line.isEmpty) {
      final result = dispatch();
      if (result != null) return result;
      event = '';
    }
  }
  final result = dispatch();
  if (result != null) return result;
  throw StateError('انقطع الاتصال قبل اكتمال النتيجة.');
}
