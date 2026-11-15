import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:llamadart/llamadart.dart';
import 'model_file_check.dart';

class ImagePage extends StatefulWidget {
  const ImagePage({super.key});
  @override
  State<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> {
  final prompt = TextEditingController();
  ImageGenerationEngine? engine;
  Uint8List? png;
  bool busy = false;
  String status = 'اختر ملف SDXS Q8_0 المحلي أولًا. ليس ملف نموذج المحادثة.';

  void notice(String value) {
    if (mounted) setState(() => status = value);
  }

  Future<void> selectModel() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || !mounted) return;
      final path = result.files.single.path;
      if (path == null || !path.toLowerCase().endsWith('.gguf')) {
        notice('اختر ملف SDXS بصيغة GGUF.');
        return;
      }
      notice('جار التحقق من بصمة SDXS…');
      await checkSdxsFile(path, () => mounted);
      if (!mounted) return;
      await engine?.dispose();
      engine = null;
      notice('جار فحص الذاكرة وتحميل نموذج الصور…');
      final loaded = await ImageGenerationEngine.load(
        ImageGenerationModel(ModelSource.path(path)),
        params: const ImageModelParams(device: ComputeDevice.cpu, checkMemory: true),
      );
      if (!mounted) {
        await loaded.dispose();
        return;
      }
      engine = loaded;
      notice('نموذج الصور محمّل. الإعدادات مخصصة لـ SDXS فقط.');
    } catch (error) {
      notice('تعذّر تحميل نموذج الصور: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> generate() async {
    if (busy || engine == null || prompt.text.trim().isEmpty) return;
    setState(() { busy = true; status = 'جار توليد الصورة محليًا… قد يستغرق وقتًا.'; });
    try {
      final result = await engine!.generateImage(ImageGenerationRequest(
        prompt: prompt.text.trim(), width: 512, height: 512,
        steps: 1, guidanceScale: 1,
      ));
      final bytes = result.images.first.toPng();
      if (mounted) setState(() { png = bytes; status = 'اكتمل التوليد المحلي. يمكنك حفظ الصورة.'; });
    } catch (error) {
      notice('تعذّر التوليد: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final bytes = png;
    if (bytes == null || busy) return;
    setState(() => busy = true);
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ صورة حميدوش',
        fileName: 'hmidouche_${DateTime.now().millisecondsSinceEpoch}.png',
        type: FileType.custom, allowedExtensions: ['png'], bytes: bytes,
      );
      notice(path == null ? 'أُلغي الحفظ.' : 'حُفظت الصورة في المكان الذي اخترته.');
    } catch (error) {
      notice('تعذّر الحفظ: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> close() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await engine?.dispose();
      engine = null;
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      notice('تعذّر إغلاق النموذج: $error');
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    engine?.dispose();
    prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) { if (!didPop) close(); },
    child: Scaffold(
      appBar: AppBar(title: const Text('صور حميدوش • محلي'),
        leading: IconButton(onPressed: busy ? null : close, icon: const Icon(Icons.arrow_back))),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        Text(status), const SizedBox(height: 12),
        FilledButton.icon(onPressed: busy ? null : selectModel,
          icon: const Icon(Icons.memory), label: const Text('اختيار نموذج SDXS')),
        const Text('المعالجة داخل الهاتف. النموذج غير مضمّن. ابدأ بوصف إنجليزي قصير؛ جودة العربية غير مختبرة.'),
        const SizedBox(height: 12),
        TextField(controller: prompt, enabled: !busy, minLines: 2, maxLines: 6,
          maxLength: 1000, decoration: const InputDecoration(
            labelText: 'وصف الصورة', hintText: 'A red fox in autumn leaves', border: OutlineInputBorder())),
        FilledButton(onPressed: busy || engine == null ? null : generate,
          child: const Text('توليد الصورة محليًا')),
        if (busy) const LinearProgressIndicator(),
        if (png != null) ...[
          const SizedBox(height: 16), Image.memory(png!),
          OutlinedButton.icon(onPressed: busy ? null : save,
            icon: const Icon(Icons.save_alt), label: const Text('حفظ PNG')),
        ],
        const SizedBox(height: 12),
        const Text('لا تغلق الشاشة أثناء التحميل أو التوليد. محرك الصور تجريبي، وقد ترفض الذاكرة تحميل النموذج.'),
      ])),
    ),
  );
}
