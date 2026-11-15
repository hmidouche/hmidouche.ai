import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'local_ai.dart';
import 'image_page.dart';
import 'edit_image_page.dart';
import 'prompt_policy.dart';
import 'dart:io';
import 'dart:convert';
import 'safe_file_read.dart';

void main() => runApp(const HamidouchApp());

class HamidouchApp extends StatelessWidget {
  const HamidouchApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en'), Locale('fr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xff173c60)),
    home: const ChatPage(),
  );
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ai = LocalAi();
  bool busy = false;
  String status = 'اختر نموذج GGUF من الزر العلوي';
  final input = TextEditingController();
  final scroll = ScrollController();
  final messages = <String>[];
  final attachments = <PlatformFile>[];
  @override
  void dispose() { ai.dispose(); input.dispose(); scroll.dispose(); super.dispose(); }

  Future<void> attach() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (!mounted || result == null) return;
      if (attachments.length + result.files.length > 4) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يمكن إرفاق أربعة ملفات كحد أقصى لكل طلب.')));
        return;
      }
      setState(() => attachments.addAll(result.files));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر اختيار الملف. حاول مجددًا.')));
    }
  }

  Future<void> openImageEdit() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ai.dispose();
      if (!mounted) return;
      await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const EditImagePage()));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر فتح تعديل الصور: $error')));
    } finally {
      if (mounted) setState(() {
        busy = false;
        status = 'اختر نموذج المحادثة مجددًا عند الحاجة.';
      });
    }
  }

  Future<void> openImages() async {
    if (busy) return;
    setState(() { busy = true; status = 'جار تحرير ذاكرة المحادثة قبل فتح الصور…'; });
    try {
      await ai.dispose();
      if (!mounted) return;
      await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const ImagePage()));
    } catch (error) {
      if (mounted) setState(() => status = 'تعذّر فتح الصور: $error');
    } finally {
      if (mounted) setState(() {
        busy = false;
        status = 'اختر نموذج المحادثة من جديد. السجل المعروض لا يُعاد تلقائيًا إلى ذاكرة النموذج.';
      });
    }
  }

  Future<void> loadModel() async {
    if (busy) return;
    setState(() { busy = true; status = 'جار تحميل النموذج'; });
    try {
      final loaded = await ai.selectModel();
      if (mounted) setState(() => status = loaded ? 'جاهز • معالجة محلية' : 'لم يتم الاختيار');
    } catch (error) {
      if (mounted) setState(() => status = 'تعذّر التحميل: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  Future<void> send() async {
    if (busy) return;
    if (!ai.ready) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر نموذج GGUF من زر الذاكرة أولًا.')));
      return;
    }
    final text = input.text.trim();
    if (text.isEmpty && attachments.isEmpty) return;
    setState(() => busy = true);
    final blocks = <String>[];
    final selectedAttachments = List<PlatformFile>.of(attachments);
    for (final attachment in selectedAttachments) {
      final path = attachment.path;
      if (path == null || !supportsTextFile(attachment.name)) {
        blocks.add('صيغة غير مدعومة: ' + attachment.name);
        continue;
      }
      try {
        final file = File(path);
        if (!fileFits(await file.length())) {
          blocks.add('المرفق أكبر من حد القراءة 64KB: ' + attachment.name);
          continue;
        }
        final content = utf8.decode(await readLimitedFile(file, maxFileBytes));
        blocks.add('ملف: ' + attachment.name + '\n' + content);
      } catch (_) {
        blocks.add('تعذّر قراءة المرفق: ' + attachment.name);
      }
    }
    if (!mounted) return;
    final names = selectedAttachments.map((f) => f.name).join('، ');
    final prompt = [text, ...blocks].join('\n\n');
    if (!promptFits(prompt)) {
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('النص أطول من حد التجربة. اختر مقطعًا أصغر من الملف.')));
      return;
    }
    try {
      await ai.checkPrompt(prompt);
    } catch (error) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      messages.add([if (text.isNotEmpty) text, if (names.isNotEmpty) 'مرفقات محلية: '+names].join('\n'));
      attachments.clear();
      input.clear();
    });
    setState(() => busy = true);
    try {
      final answer = await ai.reply(prompt);
      if (mounted) setState(() => messages.add('حميدوش:\n$answer'));
    } catch (error) {
      if (mounted) setState(() => messages.add('تعذّر الرد: $error'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('حميدوش'), leading: Padding(
      padding: const EdgeInsets.all(8), child: CircleAvatar(backgroundImage: const AssetImage('assets/avatar.png'))),
      actions: [IconButton(tooltip: 'رفع صورة وتعديلها', icon: const Icon(Icons.edit_outlined), onPressed: busy ? null : openImageEdit), IconButton(tooltip: 'توليد الصور محليًا', icon: const Icon(Icons.image_outlined), onPressed: busy ? null : openImages), IconButton(tooltip: 'اختيار نموذج محلي', icon: const Icon(Icons.memory), onPressed: busy ? null : loadModel), IconButton(tooltip: 'مسح المحادثة المحلية', icon: const Icon(Icons.delete_outline), onPressed: busy ? null : () => setState(() { ai.clear(); messages.clear(); attachments.clear(); }))]),
    body: SafeArea(child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(12), color: Theme.of(context).colorScheme.secondaryContainer,
        child: Text(status)),
      Expanded(child: ListView(controller: scroll, padding: const EdgeInsets.all(16), children: [
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 20, backgroundImage: AssetImage('assets/avatar.png')),
          SizedBox(width: 10), Expanded(child: Text('مرحبًا، أنا حميدوش. هنا ستكون مساحة تطوير التطبيقات وتحليل البيانات وفهم أخطاء الأكواد.')),
        ]),
        const SizedBox(height: 24),
        for (final message in messages) Align(alignment: AlignmentDirectional.centerEnd, child: Container(
          constraints: const BoxConstraints(maxWidth: 500), margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(18)),
          child: SelectableText(message))),
        if (busy) const LinearProgressIndicator(),
        const Text('قراءة محلية للملفات النصية والأكواد فقط، حتى 64KB للملف. الصور وPDF غير مدعومة. المحادثة غير محفوظة بعد الإغلاق.'),
      ])),
      if (attachments.isNotEmpty) SizedBox(height: 54, child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final file in attachments) Padding(padding: const EdgeInsets.all(4), child: InputChip(label: Text(file.name), onDeleted: busy ? null : () => setState(() => attachments.remove(file))))
      ])),
      Padding(padding: const EdgeInsets.all(10), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        IconButton(onPressed: busy ? null : attach, tooltip: 'اختيار ملف محلي', icon: const Icon(Icons.attach_file)),
        Expanded(child: TextField(controller: input, enabled: !busy, minLines: 1, maxLines: 6, decoration: const InputDecoration(hintText: 'اكتب سؤالك أو الصق الكود…', border: OutlineInputBorder()))),
        IconButton(onPressed: busy ? null : send, tooltip: 'إرسال إلى النموذج المحلي', icon: const Icon(Icons.send)),
      ])),
    ])),
  );
}
