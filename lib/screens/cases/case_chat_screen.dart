import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/consultation_request.dart';
import '../../repositories/case_chat_repository.dart';
import '../../services/app_error_message.dart';

class CaseChatScreen extends StatefulWidget {
  const CaseChatScreen({super.key, required this.request});

  final ConsultationRequest request;

  @override
  State<CaseChatScreen> createState() => _CaseChatScreenState();
}

class _CaseChatScreenState extends State<CaseChatScreen> {
  final _repository = CaseChatRepository();
  final _message = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    if (_message.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw StateError('Your session has expired. Please log in again.');
      }
      await _repository.send(
        requestId: widget.request.id,
        caseId: widget.request.caseId,
        clientId: widget.request.clientId,
        lawyerId: widget.request.lawyerId,
        receiverId: uid == widget.request.clientId
            ? widget.request.lawyerId
            : widget.request.clientId,
        message: _message.text,
      );
      _message.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(appErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(widget.request.caseTitle)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<CaseChatMessage>>(
              stream: _repository.watchMessages(widget.request.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Chat could not be loaded: ${snapshot.error}',
                      ),
                    ),
                  );
                }
                final messages = snapshot.data ?? const [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Chat started. Send the first message.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final item = messages[index];
                    final mine = item.senderId == uid;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? const Color(0xFF8B552F)
                              : Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .17),
                          ),
                        ),
                        child: Text(
                          item.message,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Write a message',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send,color: Colors.white,),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
