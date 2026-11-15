import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'cloud_image_edit.dart';
import 'image_safety.dart';
import 'safe_file_read.dart';

class EditImagePage extends StatefulWidget {
  const EditImagePage({super.key});
  @override
  State<EditImagePage> createState() => _EditImagePageState();
}
class _EditImagePageState extends State<EditImagePage> {
  final prompt = TextEditingController();
  CloudImageEdit? service;
  File? source;
  Uint8List? output;
  bool busy = false;
  bool consent = false;
  String status = 'اختر صورة JPG أو PNG واكتب التعديل. الاتصال بالإنترنت مطلوب.';
  Future<void> choose() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png']);
      if (!mounted || result == null) return;
      final path = result.files.single.path;
      if (path == null) return;
      final file = File(path);
      if (await file.length() > 10 * 1024 * 1024) throw StateError('الحد الأقصى للصورة 10MB.');
      await validateEncodedImage(await readLimitedFile(file, 10 * 1024 * 1024));
      if (mounted) setState(() { source = file; output = null; consent = false; });
    } catch (error) { update('$error'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  void update(String text) { if (mounted) setState(() => status = text); }
  Future<void> edit() async {
    if (busy || source == null || !consent || prompt.text.trim().isEmpty) return;
    setState(() { busy = true; output = null; });
    final current = CloudImageEdit();
    service = current;
    try {
      final bytes = await current.edit(source!, prompt.text.trim(), update).timeout(const Duration(minutes: 5));
      if (!mounted) return;
      await validateEncodedImage(bytes);
      if (!mounted) return;
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) throw StateError('تعذّر تجهيز ملف الصورة.');
          if (mounted) setState(() { output = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes); status = 'استُلمت الصورة المعدّلة. عاينها ثم احفظها.'; });
        } finally { frame.image.dispose(); }
      } finally { codec.dispose(); }
    } catch (error) { update('لم يكتمل التعديل: $error'); }
    finally {
      current.close();
      service = null;
      if (mounted) setState(() => busy = false);
    }
  }
  Future<void> save() async {
    final bytes = output;
    if (bytes == null || busy) return;
    setState(() => busy = true);
    try {
      final path = await FilePicker.platform.saveFile(fileName: 'hmidouche_edit_${DateTime.now().millisecondsSinceEpoch}.png', type: FileType.custom, allowedExtensions: ['png'], bytes: bytes);
      update(path == null ? 'أُلغي الحفظ.' : 'حُفظت الصورة.');
    } catch (error) { update('تعذّر الحفظ: $error'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  void dispose() { service?.close(); prompt.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تعديل صورة • خدمة خارجية')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('تجربة مجانية محدودة عبر Qwen Image Edit على Hugging Face. لا اشتراك ولا تحويل تلقائي لخدمة مدفوعة. قد تنتظر أو تُرفض العملية عند نفاد الحصة. لا ترسل صورًا حساسة.'),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: busy ? null : choose, icon: const Icon(Icons.upload_file), label: const Text('رفع صورة من الهاتف')),
      if (source != null) Image.file(source!, cacheWidth: 1024, height: 220, fit: BoxFit.contain, errorBuilder: (_, error, stack) => const Text('تعذّرت معاينة الصورة. اختر ملفًا صالحًا.')),
      TextField(controller: prompt, enabled: !busy, minLines: 2, maxLines: 5, maxLength: 1000, decoration: const InputDecoration(labelText: 'التعديل المطلوب', hintText: 'Change the background to a sunny garden', border: OutlineInputBorder())),
      CheckboxListTile(value: consent, onChanged: busy ? null : (value) => setState(() => consent = value ?? false), title: const Text('أوافق على إرسال هذه الصورة والوصف إلى Qwen عبر Hugging Face لمعالجتها.')),
      FilledButton(onPressed: busy || source == null || !consent ? null : edit, child: const Text('إرسال واستلام الصورة المعدّلة')),
      if (busy) const LinearProgressIndicator(),
      Text(status),
      if (output != null) ...[Image.memory(output!), OutlinedButton.icon(onPressed: busy ? null : save, icon: const Icon(Icons.download), label: const Text('حفظ الصورة المعدّلة PNG'))],
      const Text('إغلاق الشاشة يوقف اتصال التطبيق، لكنه قد لا يلغي المعالجة على الخدمة. لا يوجد حفظ تلقائي في Drive.'),
    ])),
  );
}
