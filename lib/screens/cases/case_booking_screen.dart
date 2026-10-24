import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../controllers/case_booking_controller.dart';
import '../../models/legal_case.dart';
import '../../models/lawyer_directory_profile.dart';
import '../../models/user_profile.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/app_error_message.dart';
import '../../repositories/legal_taxonomy_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_select_field.dart';
import '../../widgets/client_portal_surface.dart';

class CaseBookingScreen extends StatefulWidget {
  const CaseBookingScreen({super.key, required this.lawyer});

  final LawyerDirectoryProfile lawyer;

  @override
  State<CaseBookingScreen> createState() => _CaseBookingScreenState();
}

class _CaseBookingScreenState extends State<CaseBookingScreen> {
  final CaseBookingController _controller = CaseBookingController();
  late final Future<UserProfile> _profile = AuthService.currentUserProfile(
    UserRole.client,
  );

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_refresh)
      ..loadAvailableCases();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  Future<void> _selectCase(LegalCase legalCase, UserProfile profile) async {
    try {
      await _controller.requestLawyer(
        legalCase: legalCase,
        lawyerId: widget.lawyer.id,
        lawyerName: widget.lawyer.name,
        clientName: profile.displayName,
        clientPhone: profile.phone,
        lawyerPhone: widget.lawyer.phone,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to ${widget.lawyer.name}.')),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _createCase(UserProfile profile) async {
    final draft = await Navigator.push<NewCaseDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => const ClientPortalSurface(child: CreateCaseScreen()),
      ),
    );
    if (draft == null || !mounted) return;
    try {
      final legalCase = await _controller.createCase(
        title: draft.title,
        category: draft.category,
        description: draft.description,
        documents: draft.documents,
      );
      await _selectCase(legalCase, profile);
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(appErrorMessage(error))));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Book Consultation')),
    body: FutureBuilder<UserProfile>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Your profile could not be loaded: ${appErrorMessage(snapshot.error!)}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final profile = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Continue with ${widget.lawyer.name}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose an existing case or create a new one. Payment is only '
              'requested after an advocate accepts, and is charged once per case.',
              style: TextStyle(color: Color(0xFFD8C8BE), height: 1.4),
            ),
            const SizedBox(height: 24),
            if (_controller.availableCases.isNotEmpty) ...[
              Text(
                'Select Existing Case',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ..._controller.availableCases.map(
                (item) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.gavel_outlined),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${item.category} • '
                      '${item.isPaidAndActive ? 'Paid' : 'No payment yet'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: !_controller.busy,
                    onTap: () => _selectCase(item, profile),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
            ],
            FilledButton.icon(
              onPressed: _controller.busy ? null : () => _createCase(profile),
              icon: const Icon(Icons.add),
              label: const Text('Create New Case'),
            ),
            if (_controller.error != null) ...[
              const SizedBox(height: 12),
              Text(
                _controller.error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            if (_controller.busy) ...[
              const SizedBox(height: 18),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        );
      },
    ),
  );
}

class NewCaseDraft {
  const NewCaseDraft({
    required this.title,
    required this.category,
    required this.description,
    required this.documents,
  });
  final String title;
  final String category;
  final String description;
  final List<PendingCaseDocument> documents;
}

class CreateCaseScreen extends StatefulWidget {
  const CreateCaseScreen({super.key});

  @override
  State<CreateCaseScreen> createState() => _CreateCaseScreenState();
}

class _CreateCaseScreenState extends State<CreateCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final List<PendingCaseDocument> _documents = [];
  final LegalTaxonomyRepository _taxonomy = LegalTaxonomyRepository();
  String? _category;
  bool _pickingDocuments = false;

  Future<void> _pickDocuments() async {
    if (_pickingDocuments) return;
    setState(() => _pickingDocuments = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'doc',
          'docx',
          'txt',
        ],
      );
      if (result == null) return;
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw StateError(
            'Could not read ${file.name}. Please choose the file again.',
          );
        }
        if (file.size > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${file.name} is larger than 10 MB.')),
            );
          }
          continue;
        }
        final alreadyAdded = _documents.any(
          (item) => item.name == file.name && item.size == file.size,
        );
        if (alreadyAdded) continue;
        _documents.add(
          PendingCaseDocument(
            name: file.name,
            bytes: bytes,
            contentType: _contentType(file.extension),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Attachment failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _pickingDocuments = false);
    }
  }

  String _contentType(String? extension) => switch (extension?.toLowerCase()) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'txt' => 'text/plain',
    _ => 'application/octet-stream',
  };

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      NewCaseDraft(
        title: _title.text.trim(),
        category: _category!,
        description: _description.text.trim(),
        documents: List.unmodifiable(_documents),
      ),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create Case')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Primary.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.gavel_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tell us about your matter',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Add clear details so the advocate can understand your case.',
                          style: TextStyle(
                            color: Color(0xFFD8C8BE),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Case Title'),
            validator: (value) => (value?.trim().length ?? 0) < 3
                ? 'Enter a descriptive case title'
                : null,
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<String>>(
            stream: _taxonomy.watchAreasOfExpertise(),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? const <String>[];
              final selected = categories.contains(_category)
                  ? _category
                  : null;
              return AppSelectField<String>(
                label: 'Category',
                value: selected,
                options: categories,
                itemLabel: (item) => item,
                suffix:
                    snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                helperText: snapshot.hasError
                    ? 'Unable to load live categories'
                    : null,
                enabled: categories.isNotEmpty,
                onChanged: (value) => setState(() => _category = value),
                validator: (value) =>
                    value == null ? 'Select a category' : null,
              );
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description'),
            minLines: 5,
            maxLines: 9,
            validator: (value) => (value?.trim().length ?? 0) < 10
                ? 'Add at least 10 characters'
                : null,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickingDocuments ? null : _pickDocuments,
            icon: _pickingDocuments
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_file),
            label: Text(
              _pickingDocuments
                  ? 'Opening files…'
                  : 'Add attachments (optional)',
            ),
          ),
          ..._documents.indexed.map(
            (entry) => ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(entry.$2.name),
              subtitle: Text(
                '${(entry.$2.size / 1024).ceil()} KB • Ready to upload',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _documents.removeAt(entry.$1)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Save Case')),
          const SizedBox(height: 10),
          const Text(
            'Saving creates a draft. You decide whether to unlock it for ₹149.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFD8C8BE)),
          ),
        ],
      ),
    ),
  );
}
