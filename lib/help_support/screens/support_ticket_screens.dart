import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/app_select_field.dart';
import '../../widgets/client_portal_surface.dart';
import '../models/support_models.dart';
import '../repositories/support_repository.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key, required this.repository});
  final SupportRepository repository;
  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _category = 'General';
  SupportPriority _priority = SupportPriority.medium;
  final List<({String name, Uint8List bytes})> _files = [];
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      type: FileType.custom,
    );
    if (result == null) return;
    setState(() {
      for (final file in result.files) {
        if (file.bytes != null && file.size <= 10 * 1024 * 1024) {
          _files.add((name: file.name, bytes: file.bytes!));
        }
      }
    });
  }

  Future<void> _submit() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.repository.createTicket(
        title: _title.text,
        description: _description.text,
        category: _category,
        priority: _priority,
        files: _files,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support ticket created.')),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ticket could not be created: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Raise support ticket')),
    body: Form(
      key: _key,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Share the details below. Firestore will queue the ticket if you are offline.',
            style: TextStyle(color: kHint, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: (value) =>
                (value?.trim().length ?? 0) < 4 ? 'Enter a clear title.' : null,
          ),
          const SizedBox(height: 12),
          AppSelectField<String>(
            label: 'Category',
            value: _category,
            options: const [
              'General',
              'Account',
              'Payment',
              'Consultation',
              'Technical',
            ],
            itemLabel: (value) => value,
            onChanged: (value) => _category = value!,
          ),
          const SizedBox(height: 12),
          AppSelectField<SupportPriority>(
            label: 'Priority',
            value: _priority,
            options: SupportPriority.values,
            itemLabel: (value) => value.name.toUpperCase(),
            onChanged: (value) => _priority = value!,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Description'),
            validator: (value) => (value?.trim().length ?? 0) < 10
                ? 'Please provide at least 10 characters.'
                : null,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickFiles,
            icon: const Icon(Icons.attach_file),
            label: const Text('Add image or document'),
          ),
          for (final file in _files.indexed)
            ListTile(
              dense: true,
              leading: const Icon(Icons.description_outlined),
              title: Text(file.$2.name),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _files.removeAt(file.$1)),
              ),
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.send_outlined),
            label: Text(_saving ? 'Creating ticket...' : 'Create ticket'),
          ),
        ],
      ),
    ),
  );
}

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key, required this.repository});
  final SupportRepository repository;
  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  SupportTicketStatus? _filter;
  String _sort = 'Newest';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My tickets')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ClientPortalSurface(
            child: CreateTicketScreen(repository: widget.repository),
          ),
        ),
      ),
      icon: const Icon(Icons.add),
      label: const Text('New ticket'),
    ),
    body: StreamBuilder<List<SupportTicket>>(
      stream: widget.repository.watchTickets(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Tickets could not be loaded.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var tickets = snapshot.data!
            .where((e) => _filter == null || e.status == _filter)
            .toList();
        if (_sort == 'Oldest') {
          tickets.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        }
        if (_sort == 'Priority') {
          tickets.sort((a, b) => b.priority.index.compareTo(a.priority.index));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _filter == null,
                          onSelected: (_) => setState(() => _filter = null),
                        ),
                        for (final status in SupportTicketStatus.values)
                          ChoiceChip(
                            label: Text(_statusLabel(status)),
                            selected: _filter == status,
                            onSelected: (_) => setState(() => _filter = status),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    initialValue: _sort,
                    tooltip: 'Sort tickets',
                    onSelected: (value) => setState(() => _sort = value),
                    itemBuilder: (_) => ['Newest', 'Oldest', 'Priority']
                        .map((e) => PopupMenuItem(value: e, child: Text(e)))
                        .toList(),
                    icon: const Icon(Icons.sort),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: tickets.isEmpty
                  ? const Center(
                      child: Text(
                        'No support tickets here.',
                        style: TextStyle(color: Color(0xFFD8C8BE)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: tickets.length,
                      itemBuilder: (_, i) => _TicketCard(
                        ticket: tickets[i],
                        repository: widget.repository,
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.repository});
  final SupportTicket ticket;
  final SupportRepository repository;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ClientPortalSurface(
            child: TicketDetailScreen(ticket: ticket, repository: repository),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _Badge(
                  label: _statusLabel(ticket.status),
                  color: _statusColor(ticket.status),
                ),
                _Badge(
                  label: ticket.priority.name.toUpperCase(),
                  color: _priorityColor(ticket.priority),
                ),
                _Badge(label: ticket.category, color: kBrown),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ticket.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFD8C8BE)),
            ),
          ],
        ),
      ),
    ),
  );
}

class TicketDetailScreen extends StatelessWidget {
  const TicketDetailScreen({
    super.key,
    required this.ticket,
    required this.repository,
  });
  final SupportTicket ticket;
  final SupportRepository repository;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('#${ticket.id.substring(0, ticket.id.length.clamp(0, 8))}'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          ticket.title,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          children: [
            _Badge(
              label: _statusLabel(ticket.status),
              color: _statusColor(ticket.status),
            ),
            _Badge(
              label: ticket.priority.name.toUpperCase(),
              color: _priorityColor(ticket.priority),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(ticket.description, style: const TextStyle(height: 1.5)),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ClientPortalSurface(
                child: TicketChatScreen(ticket: ticket, repository: repository),
              ),
            ),
          ),
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Open support chat'),
        ),
        const SizedBox(height: 10),
        if (ticket.status != SupportTicketStatus.closed)
          OutlinedButton.icon(
            onPressed: () async {
              await repository.setTicketStatus(
                ticket.id,
                SupportTicketStatus.closed,
              );
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.close),
            label: const Text('Close ticket'),
          ),
        if (ticket.status == SupportTicketStatus.closed)
          OutlinedButton.icon(
            onPressed: () async {
              await repository.setTicketStatus(
                ticket.id,
                SupportTicketStatus.open,
              );
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reopen ticket'),
          ),
      ],
    ),
  );
}

class TicketChatScreen extends StatefulWidget {
  const TicketChatScreen({
    super.key,
    required this.ticket,
    required this.repository,
  });
  final SupportTicket ticket;
  final SupportRepository repository;
  @override
  State<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<TicketChatScreen> {
  final message = TextEditingController();
  bool sending = false;
  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (message.text.trim().isEmpty || sending) return;
    final value = message.text;
    message.clear();
    setState(() => sending = true);
    try {
      await widget.repository.sendMessage(widget.ticket.id, value);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Support chat')),
    body: Column(
      children: [
        Expanded(
          child: StreamBuilder<List<SupportMessage>>(
            stream: widget.repository.watchMessages(widget.ticket.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = snapshot.data!;
              if (messages.isEmpty) {
                return const Center(
                  child: Text(
                    'Send a message to start the conversation.',
                    style: TextStyle(color: kHint),
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(14),
                itemCount: messages.length,
                itemBuilder: (_, index) {
                  final item = messages[messages.length - 1 - index];
                  final mine = item.senderId == widget.repository.userId;
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 310),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: mine ? kBrown : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: mine ? null : Border.all(color: kBorder),
                      ),
                      child: Text(
                        item.message,
                        style: TextStyle(color: mine ? Colors.white : kInk),
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
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: message,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Message support...',
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: sending ? null : send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

String _statusLabel(SupportTicketStatus status) => switch (status) {
  SupportTicketStatus.open => 'Open',
  SupportTicketStatus.inProgress => 'In progress',
  SupportTicketStatus.waitingUser => 'Waiting for you',
  SupportTicketStatus.resolved => 'Resolved',
  SupportTicketStatus.closed => 'Closed',
};
Color _statusColor(SupportTicketStatus status) => switch (status) {
  SupportTicketStatus.open => Colors.blue,
  SupportTicketStatus.inProgress => Colors.orange,
  SupportTicketStatus.waitingUser => Colors.deepPurple,
  SupportTicketStatus.resolved => Colors.green,
  SupportTicketStatus.closed => Colors.blueGrey,
};
Color _priorityColor(SupportPriority value) => switch (value) {
  SupportPriority.low => Colors.blueGrey,
  SupportPriority.medium => Colors.blue,
  SupportPriority.high => Colors.orange,
  SupportPriority.urgent => Colors.red,
};
