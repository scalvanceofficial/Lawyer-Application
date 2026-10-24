import 'package:flutter/material.dart';

import '../../models/consultation_request.dart';
import '../../models/legal_case.dart';
import '../../repositories/case_repository.dart';
import '../../repositories/consultation_repository.dart';
import '../../services/app_error_message.dart';
import '../../widgets/client_portal_surface.dart';
import 'case_detail_screen.dart';

class ClientCasesScreen extends StatelessWidget {
  ClientCasesScreen({super.key});

  final CaseRepository _cases = CaseRepository();
  final ConsultationRepository _requests = ConsultationRepository();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<LegalCase>>(
    stream: _cases.watchClientCases(),
    builder: (context, caseSnapshot) =>
        StreamBuilder<List<ConsultationRequest>>(
          stream: _requests.watchClientRequests(),
          builder: (context, requestSnapshot) {
            final error = caseSnapshot.error ?? requestSnapshot.error;
            if (error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Cases could not be loaded: ${appErrorMessage(error)}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!caseSnapshot.hasData || !requestSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _CaseTabs(
              cases: caseSnapshot.data!,
              requests: requestSnapshot.data!,
            );
          },
        ),
  );
}

class _CaseTabs extends StatefulWidget {
  const _CaseTabs({required this.cases, required this.requests});
  final List<LegalCase> cases;
  final List<ConsultationRequest> requests;

  @override
  State<_CaseTabs> createState() => _CaseTabsState();
}

class _CaseTabsState extends State<_CaseTabs> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final draft = widget.cases.where((item) => !item.isActive).toList();
    final pendingIds = widget.requests
        .where((item) => item.status == ConsultationRequestStatus.pending)
        .map((item) => item.caseId)
        .toSet();
    final rejectedIds = widget.requests
        .where((item) => item.status == ConsultationRequestStatus.rejected)
        .map((item) => item.caseId)
        .toSet();
    final completed = widget.cases
        .where((item) => item.status == LegalCaseStatus.completed)
        .toList();
    final active = widget.cases
        .where(
          (item) => item.isActive && item.status != LegalCaseStatus.completed,
        )
        .toList();
    final sections = <({String label, IconData icon, List<LegalCase> cases})>[
      (label: 'Draft', icon: Icons.edit_note, cases: draft),
      (
        label: 'Pending',
        icon: Icons.hourglass_top_rounded,
        cases: widget.cases
            .where((item) => pendingIds.contains(item.id))
            .toList(),
      ),
      (label: 'Active', icon: Icons.work_outline, cases: active),
      (label: 'Completed', icon: Icons.task_alt_outlined, cases: completed),
      (
        label: 'Rejected',
        icon: Icons.cancel_outlined,
        cases: widget.cases
            .where((item) => rejectedIds.contains(item.id))
            .toList(),
      ),
    ];
    final selected = sections[_selectedIndex];

    return Column(
      children: [
        Material(
          color: Colors.white.withValues(alpha: .08),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final (index, section) in sections.indexed)
                  ChoiceChip(
                    selected: _selectedIndex == index,
                    showCheckmark: false,
                    avatar: Icon(section.icon, size: 17),
                    label: Text('${section.label} ${section.cases.length}'),
                    onSelected: (_) => setState(() => _selectedIndex = index),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey(_selectedIndex),
              child: _CaseList(cases: selected.cases),
            ),
          ),
        ),
      ],
    );
  }
}

class _CaseList extends StatelessWidget {
  const _CaseList({required this.cases});
  final List<LegalCase> cases;

  @override
  Widget build(BuildContext context) {
    if (cases.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'No cases in this section.',
            style: TextStyle(color: Color(0xFFD8C8BE)),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cases.length,
      itemBuilder: (context, index) {
        final item = cases[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(item.isActive ? Icons.gavel : Icons.lock_outline),
            ),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${item.category} • ${item.isPaidAndActive ? 'Paid' : 'Payment pending'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClientPortalSurface(
                  child: CaseDetailScreen(legalCase: item),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
