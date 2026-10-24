import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/generated_file_service.dart';
import '../services/legal_ai_service.dart';
import '../services/legal_document_export_service.dart';

class LegalChatScreen extends StatefulWidget {
  const LegalChatScreen({super.key});

  @override
  State<LegalChatScreen> createState() => _LegalChatScreenState();
}

class _LegalChatScreenState extends State<LegalChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final Map<LegalAiEngine, _EngineSession> _sessions = {};
  LegalAiEngine? _selectedEngine;

  _EngineSession _sessionFor(LegalAiEngine engine) => _sessions.putIfAbsent(
    engine,
    () => _EngineSession(
      service: LegalAiService(engine: engine),
      messages: [_ChatMessage(text: engine.greeting, fromUser: false)],
    ),
  );

  void _selectEngine(LegalAiEngine engine) {
    _sessionFor(engine);
    setState(() => _selectedEngine = engine);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      _focusNode.requestFocus();
    });
  }

  Future<void> _send() async {
    final engine = _selectedEngine;
    final text = _controller.text.trim();
    if (engine == null || text.isEmpty) return;
    final session = _sessionFor(engine);
    if (session.sending) return;

    _controller.clear();
    setState(() {
      session.messages.add(_ChatMessage(text: text, fromUser: true));
    });
    _scrollToBottom();

    final imageRequest = _isImageRequest(text);
    if (!imageRequest &&
        !LegalAiService.isLegalQuery(
          text,
          hasLegalContext: session.hasLegalContext,
        )) {
      setState(
        () => session.messages.add(
          _ChatMessage(
            text:
                'This workspace is only for legal matters. Please describe the legal issue, document, procedure, or authority you need help with.',
            fromUser: false,
          ),
        ),
      );
      _scrollToBottom();
      _focusNode.requestFocus();
      return;
    }

    if (!imageRequest) session.hasLegalContext = true;
    setState(() {
      session.sending = true;
      session.activity = imageRequest
          ? _GenerationStatus.generatingImage
          : engine == LegalAiEngine.documentGenerator
          ? _GenerationStatus.generatingContent
          : _GenerationStatus.idle;
    });
    try {
      if (imageRequest) {
        await _generateImage(session, text);
        return;
      }
      final answer = await session.service.send(text);
      if (!mounted) return;
      final canCreatePdf = engine == LegalAiEngine.documentGenerator;
      final visibleAnswer = answer.replaceAll('[DOCUMENT_READY]', '').trim();
      final message = _ChatMessage(
        text: visibleAnswer,
        fromUser: false,
        kind: canCreatePdf ? _GeneratedKind.document : _GeneratedKind.none,
        status: _GenerationStatus.idle,
        originalPrompt: text,
        title: canCreatePdf ? _documentTitle(text) : null,
      );
      setState(() {
        session.sending = false;
        session.messages.add(message);
      });
    } on LegalAiException catch (error) {
      debugPrint('NyaySaarthi content generation failed: ${error.message}');
      if (!mounted) return;
      setState(
        () => session.messages.add(
          _ChatMessage(text: error.message, fromUser: false, isError: true),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Unexpected NyaySaarthi failure: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(
        () => session.messages.add(
          _ChatMessage(
            text: 'Unable to generate the document. Please try again.',
            fromUser: false,
            isError: true,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          session.sending = false;
          session.activity = _GenerationStatus.idle;
        });
        _scrollToBottom();
        _focusNode.requestFocus();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _generateImage(_EngineSession session, String prompt) async {
    try {
      final generated = await session.service.generateImage(prompt);
      if (!mounted) return;
      final message = _ChatMessage(
        text: 'Your image has been generated.',
        fromUser: false,
        kind: _GeneratedKind.image,
        status: _GenerationStatus.savingImage,
        originalPrompt: prompt,
        title: _imageTitle(prompt),
        pendingBytes: generated.bytes,
      );
      setState(() {
        session.sending = false;
        session.messages.add(message);
      });
      await _saveImage(message);
    } on LegalAiException catch (error) {
      debugPrint('OpenAI image generation failed: ${error.message}');
      if (!mounted) return;
      setState(
        () => session.messages.add(
          _ChatMessage(
            text: 'Unable to generate the image. Please try again.',
            fromUser: false,
            isError: true,
            kind: _GeneratedKind.image,
            status: _GenerationStatus.failed,
            errorMessage: error.message,
            originalPrompt: prompt,
            title: _imageTitle(prompt),
          ),
        ),
      );
    }
  }

  Future<void> _createPdf(_ChatMessage message) async {
    try {
      final file = await LegalDocumentExportService.createPdf(
        title: message.title ?? 'Legal Document',
        content: message.text,
      );
      if (!mounted) return;
      setState(() => message.complete(file));
    } catch (error, stackTrace) {
      debugPrint('PDF creation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => message.fail('Could not create the PDF.'));
    }
  }

  Future<void> _saveImage(_ChatMessage message) async {
    try {
      final bytes = message.pendingBytes;
      if (bytes == null || bytes.isEmpty) {
        throw const GeneratedFileException('The generated image was empty.');
      }
      final file = await GeneratedFileService.saveBytes(
        bytes: bytes,
        fileName: '${message.title ?? 'Generated_Image'}.png',
      );
      if (!mounted) return;
      setState(() => message.complete(file));
    } catch (error, stackTrace) {
      debugPrint('Generated image file save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => message.fail('Could not save the generated image.'));
    }
  }

  Future<void> _retry(_ChatMessage message) async {
    if (message.kind == _GeneratedKind.document) {
      setState(() => message.status = _GenerationStatus.creatingPdf);
      await _createPdf(message);
      return;
    }
    if (message.pendingBytes != null) {
      setState(() => message.status = _GenerationStatus.savingImage);
      await _saveImage(message);
      return;
    }
    final engine = _selectedEngine;
    if (engine == null || message.originalPrompt == null) return;
    setState(() {
      message.status = _GenerationStatus.generatingImage;
      message.errorMessage = null;
    });
    try {
      final generated = await _sessionFor(
        engine,
      ).service.generateImage(message.originalPrompt!);
      message.pendingBytes = generated.bytes;
      if (!mounted) return;
      setState(() => message.status = _GenerationStatus.savingImage);
      await _saveImage(message);
    } catch (error, stackTrace) {
      debugPrint('Image retry failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => message.fail('Unable to generate the image.'));
    }
  }

  Future<void> _openFile(_ChatMessage message) async {
    try {
      await GeneratedFileService.open(message.filePath!);
    } catch (error, stackTrace) {
      debugPrint('Opening generated file failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the file: $error')),
      );
    }
  }

  Future<void> _shareFile(_ChatMessage message) async {
    try {
      await GeneratedFileService.share(
        message.filePath!,
        text: 'Generated with NyaySaarthi',
      );
    } catch (error, stackTrace) {
      debugPrint('Sharing generated file failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share the file: $error')),
      );
    }
  }

  static bool _isImageRequest(String text) => RegExp(
    r'\b(generate|create|make|draw|design)\b.*\b(image|picture|illustration|poster|graphic)\b',
    caseSensitive: false,
  ).hasMatch(text);

  static String _documentTitle(String prompt) => _generatedTitle(
    prompt,
    fallback: 'Legal Document',
    removedWords: const {
      'generate',
      'create',
      'draft',
      'prepare',
      'write',
      'make',
      'a',
      'an',
      'the',
      'pdf',
      'document',
      'please',
      'for',
      'me',
    },
  );

  static String _imageTitle(String prompt) => _generatedTitle(
    prompt,
    fallback: 'Generated Image',
    removedWords: const {
      'generate',
      'create',
      'make',
      'draw',
      'design',
      'a',
      'an',
      'the',
      'image',
      'picture',
      'illustration',
      'please',
      'of',
      'for',
      'me',
    },
  );

  static String _generatedTitle(
    String prompt, {
    required String fallback,
    required Set<String> removedWords,
  }) {
    final words = prompt
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => !removedWords.contains(word.toLowerCase()))
        .take(8)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .toList();
    return words.isEmpty ? fallback : words.join(' ');
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 220),
    child: _selectedEngine == null
        ? _EngineChooser(onSelected: _selectEngine)
        : _buildConversation(_selectedEngine!),
  );

  Widget _buildConversation(LegalAiEngine engine) {
    final session = _sessionFor(engine);
    return Column(
      key: ValueKey(engine),
      children: [
        _EngineHeader(
          engine: engine,
          onBack: () {
            _focusNode.unfocus();
            setState(() => _selectedEngine = null);
          },
          onChange: _selectEngine,
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            itemCount: session.messages.length + (session.sending ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == session.messages.length) {
                return _TypingIndicator(
                  engine: engine,
                  activity: session.activity,
                );
              }
              return _MessageBubble(
                message: session.messages[index],
                assistantName: 'NyaySaarthi',
                onOpen: () => _openFile(session.messages[index]),
                onShare: () => _shareFile(session.messages[index]),
                onRetry: () => _retry(session.messages[index]),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: engine.inputHint,
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 9),
                IconButton.filled(
                  onPressed: session.sending ? null : _send,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE5AA78),
                    foregroundColor: const Color(0xFF28150E),
                    disabledBackgroundColor: const Color(
                      0xFFE5AA78,
                    ).withValues(alpha: .35),
                    disabledForegroundColor: Colors.white38,
                    minimumSize: const Size.square(52),
                  ),
                  icon: session.sending
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.send_rounded, size: 24),
                  tooltip: 'Send message',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EngineSession {
  _EngineSession({required this.service, required this.messages});
  final LegalAiService service;
  final List<_ChatMessage> messages;
  bool sending = false;
  bool hasLegalContext = false;
  _GenerationStatus activity = _GenerationStatus.idle;
}

class _EngineChooser extends StatelessWidget {
  const _EngineChooser({required this.onSelected});
  final ValueChanged<LegalAiEngine> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('engine-chooser'),
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How can NyaySaarthi help you?',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        const Text(
          'Choose a NyaySaarthi tool. Each workspace keeps its own conversation and workflow.',
          style: TextStyle(color: Color(0xFFD8C8BE), height: 1.4),
        ),
        const SizedBox(height: 20),
        ...LegalAiEngine.values.map(
          (engine) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _EngineCard(engine: engine, onTap: () => onSelected(engine)),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8C8A7).withValues(alpha: .1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Color(0xFFE8C8A7), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'NyaySaarthi provides general legal information and may make mistakes. Verify important information and documents with a qualified advocate.',
                  style: TextStyle(color: Color(0xFFE8C8A7), height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EngineCard extends StatelessWidget {
  const _EngineCard({required this.engine, required this.onTap});
  final LegalAiEngine engine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xE638241C),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Colors.white24),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFE5AA78).withValues(alpha: .15),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(engine.icon, color: const Color(0xFFE5AA78)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    engine.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    engine.description,
                    style: const TextStyle(
                      color: Color(0xFFD8C8BE),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 17),
          ],
        ),
      ),
    ),
  );
}

class _EngineHeader extends StatelessWidget {
  const _EngineHeader({
    required this.engine,
    required this.onBack,
    required this.onChange,
  });
  final LegalAiEngine engine;
  final VoidCallback onBack;
  final ValueChanged<LegalAiEngine> onChange;

  Future<void> _openEnginePicker(BuildContext context) async {
    final selected = await showModalBottomSheet<LegalAiEngine>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF2C1812),
      barrierColor: Colors.black.withValues(alpha: .65),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Choose NyaySaarthi tool',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Your conversation in each engine is saved while this page is open.',
              style: TextStyle(color: Color(0xFFD8C8BE), height: 1.35),
            ),
            const SizedBox(height: 16),
            ...LegalAiEngine.values.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: item == engine
                      ? const Color(0xFFE5AA78).withValues(alpha: .18)
                      : Colors.white.withValues(alpha: .07),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: item == engine
                          ? const Color(0xFFE5AA78)
                          : Colors.white12,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => Navigator.pop(sheetContext, item),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            color: const Color(0xFFE5AA78),
                            size: 24,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFD8C8BE),
                                    fontSize: 12,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            item == engine
                                ? Icons.check_circle_rounded
                                : Icons.chevron_right_rounded,
                            color: item == engine
                                ? const Color(0xFFE5AA78)
                                : Colors.white54,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null && selected != engine) onChange(selected);
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(8, 8, 10, 10),
    decoration: const BoxDecoration(
      color: Color(0xE638241C),
      border: Border(bottom: BorderSide(color: Colors.white24)),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'All NyaySaarthi tools',
        ),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE5AA78).withValues(alpha: .15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(engine.icon, color: const Color(0xFFE5AA78), size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            engine.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: 'Change NyaySaarthi tool',
          onPressed: () => _openEnginePicker(context),
          icon: const Icon(Icons.swap_horiz_rounded),
        ),
      ],
    ),
  );
}

extension on LegalAiEngine {
  IconData get icon => switch (this) {
    LegalAiEngine.caseAnalyzer => Icons.manage_search_rounded,
    LegalAiEngine.strategy => Icons.account_tree_outlined,
    LegalAiEngine.documentGenerator => Icons.description_outlined,
    LegalAiEngine.caseResearch => Icons.balance_outlined,
  };
}

enum _GeneratedKind { none, document, image }

enum _GenerationStatus {
  idle,
  generatingContent,
  creatingPdf,
  generatingImage,
  savingImage,
  completed,
  failed,
}

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.fromUser,
    this.isError = false,
    this.kind = _GeneratedKind.none,
    this.status = _GenerationStatus.idle,
    this.originalPrompt,
    this.title,
    this.errorMessage,
    this.pendingBytes,
  });
  final String text;
  final bool fromUser;
  final bool isError;
  final _GeneratedKind kind;
  _GenerationStatus status;
  final String? originalPrompt;
  final String? title;
  String? errorMessage;
  Uint8List? pendingBytes;
  String? filePath;
  String? fileName;

  void complete(GeneratedFile file) {
    filePath = file.path;
    fileName = file.name;
    pendingBytes = null;
    errorMessage = null;
    status = _GenerationStatus.completed;
  }

  void fail(String message) {
    filePath = null;
    fileName = null;
    errorMessage = message;
    status = _GenerationStatus.failed;
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.assistantName,
    required this.onOpen,
    required this.onShare,
    required this.onRetry,
  });
  final _ChatMessage message;
  final String assistantName;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Align(
    alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 620),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: message.fromUser
            ? const Color(0xFF8B552F)
            : message.isError
            ? const Color(0xFF6D3030)
            : Colors.white.withValues(alpha: .12),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            message.fromUser ? message.text : '$assistantName\n${message.text}',
            style: TextStyle(
              color: Colors.white,
              height: 1.4,
              fontWeight: message.fromUser
                  ? FontWeight.normal
                  : FontWeight.w500,
            ),
          ),
          if (message.kind != _GeneratedKind.none) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 10),
            _GeneratedFileStatus(
              message: message,
              onOpen: onOpen,
              onShare: onShare,
              onRetry: onRetry,
            ),
          ],
        ],
      ),
    ),
  );
}

class _GeneratedFileStatus extends StatelessWidget {
  const _GeneratedFileStatus({
    required this.message,
    required this.onOpen,
    required this.onShare,
    required this.onRetry,
  });

  final _ChatMessage message;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final status = message.status;
    if (status == _GenerationStatus.idle &&
        message.kind == _GeneratedKind.document) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE5AA78),
            foregroundColor: const Color(0xFF28150E),
            minimumSize: const Size(0, 46),
          ),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Create / Download PDF'),
        ),
      );
    }
    if (status == _GenerationStatus.generatingContent ||
        status == _GenerationStatus.creatingPdf ||
        status == _GenerationStatus.generatingImage ||
        status == _GenerationStatus.savingImage) {
      final label = switch (status) {
        _GenerationStatus.generatingContent => 'Generating document...',
        _GenerationStatus.creatingPdf => 'Creating PDF...',
        _GenerationStatus.generatingImage => 'Generating image...',
        _ => 'Saving image...',
      };
      return Row(
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
    }
    if (status == _GenerationStatus.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.errorMessage ?? 'Could not create the file.',
            style: const TextStyle(
              color: Color(0xFFFFC7C7),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      );
    }
    if (status != _GenerationStatus.completed || message.filePath == null) {
      return const SizedBox.shrink();
    }
    final isImage = message.kind == _GeneratedKind.image;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isImage ? '✓ Image Ready' : '✓ Document Ready',
          style: const TextStyle(
            color: Color(0xFF9EE29E),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message.fileName ?? '',
          style: const TextStyle(color: Color(0xFFD8C8BE)),
        ),
        if (isImage) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(message.filePath!),
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, error, _) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Could not display the saved image: $error'),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(isImage ? 'Open Image' : 'Open PDF'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_outlined),
                label: Text(isImage ? 'Share Image' : 'Share PDF'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.engine, required this.activity});
  final LegalAiEngine engine;
  final _GenerationStatus activity;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 14),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              switch (activity) {
                _GenerationStatus.generatingContent =>
                  'Generating your document...',
                _GenerationStatus.generatingImage => 'Generating image...',
                _ => '${engine.title} is preparing a response…',
              },
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}
