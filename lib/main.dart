import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_picker/file_picker.dart';

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
  final input = TextEditingController();
  final scroll = ScrollController();
  final messages = <String>[];
  final attachments = <PlatformFile>[];
  @override
  void dispose() { input.dispose(); scroll.dispose(); super.dispose(); }

  Future<void> attach() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (!mounted || result == null) return;
      setState(() => attachments.addAll(result.files));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر اختيار الملف. حاول مجددًا.')));
    }
  }

  void send() {
    final text = input.text.trim();
    if (text.isEmpty && attachments.isEmpty) return;
    final names = attachments.map((f) => f.name).join('، ');
    setState(() {
      messages.add([if (text.isNotEmpty) text, if (names.isNotEmpty) 'مرفقات محلية: '+names].join('\n'));
      attachments.clear();
      input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('حميدوش'), leading: Padding(
      padding: const EdgeInsets.all(8), child: CircleAvatar(backgroundImage: const AssetImage('assets/avatar.png'))),
      actions: [IconButton(tooltip: 'مسح المحادثة المحلية', icon: const Icon(Icons.delete_outline), onPressed: () => setState(() { messages.clear(); attachments.clear(); }))]),
    body: SafeArea(child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(12), color: Theme.of(context).colorScheme.secondaryContainer,
        child: const Text('نسخة واجهة تجريبية • لم يتم ربط الذكاء الاصطناعي. لا تُرسل الرسائل أو الملفات إلى أي خدمة، ولا تُحفظ بعد إغلاق التطبيق.')),
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
        if (messages.isNotEmpty) const Text('تمت إضافة الرسالة محليًا فقط. الرد والتحليل يحتاجان إلى ربط الخدمة.'),
      ])),
      if (attachments.isNotEmpty) SizedBox(height: 54, child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final file in attachments) Padding(padding: const EdgeInsets.all(4), child: InputChip(label: Text(file.name), onDeleted: () => setState(() => attachments.remove(file))))
      ])),
      Padding(padding: const EdgeInsets.all(10), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        IconButton(onPressed: attach, tooltip: 'اختيار ملف محلي', icon: const Icon(Icons.attach_file)),
        Expanded(child: TextField(controller: input, minLines: 1, maxLines: 6, decoration: const InputDecoration(hintText: 'اكتب سؤالك أو الصق الكود…', border: OutlineInputBorder()))),
        IconButton(onPressed: send, tooltip: 'إضافة الرسالة محليًا', icon: const Icon(Icons.send)),
      ])),
    ])),
  );
}

