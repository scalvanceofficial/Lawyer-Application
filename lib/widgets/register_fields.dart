import 'package:flutter/material.dart';

import '../models/court.dart';
import '../repositories/court_repository.dart';
import 'app_select_field.dart';

class AvailabilityField extends StatelessWidget {
  const AvailabilityField({super.key, required this.days, required this.onTap});

  final Set<String> days;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'Th', 'F', 'S', 'S'];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD8D8D8)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Availability',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            for (final label in labels)
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(left: 4),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0x885A4034),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CourtField extends StatefulWidget {
  const CourtField({super.key, required this.value, required this.onChanged});

  final Set<String> value;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<CourtField> createState() => _CourtFieldState();
}

class _CourtFieldState extends State<CourtField> {
  static final CourtRepository _courts = CourtRepository();
  final Set<String> _selectedHighCourts = {};
  final Set<String> _selectedDistrictCourts = {};
  CourtType? _type;

  @override
  void initState() {
    super.initState();
    _selectedHighCourts.addAll(
      widget.value.where((court) => court.toLowerCase().contains('high court')),
    );
    _selectedDistrictCourts.addAll(
      widget.value.where(
        (court) =>
            court != CourtType.supremeCourt.label &&
            !court.toLowerCase().contains('high court'),
      ),
    );
    if (widget.value.isNotEmpty) {
      _type = widget.value.contains(CourtType.supremeCourt.label)
          ? CourtType.supremeCourt
          : _selectedHighCourts.isNotEmpty
          ? CourtType.highCourt
          : CourtType.districtCourt;
    }
  }

  Future<void> _typeChanged(CourtType? type) async {
    if (type == null) return;
    setState(() => _type = type);
    if (type == CourtType.supremeCourt) {
      final updated = widget.value.toSet();
      if (updated.contains(type.label) && updated.length > 1) {
        updated.remove(type.label);
      } else {
        updated.add(type.label);
      }
      widget.onChanged(updated);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    if (type == CourtType.highCourt) {
      final selected = await _showHighCourtPicker(context);
      if (selected == null || !mounted) {
        if (mounted && widget.value.isEmpty) setState(() => _type = null);
        return;
      }
      final updated = widget.value.toSet()
        ..removeAll(_selectedHighCourts)
        ..addAll(selected);
      setState(() {
        _selectedHighCourts
          ..clear()
          ..addAll(selected);
        if (updated.isEmpty) _type = null;
      });
      widget.onChanged(updated);
    } else {
      final selected = await _showDistrictCourtPicker(context);
      if (selected == null || !mounted) {
        if (mounted && widget.value.isEmpty) setState(() => _type = null);
        return;
      }
      final updated = widget.value.toSet()
        ..removeAll(_selectedDistrictCourts)
        ..addAll(selected);
      setState(() {
        _selectedDistrictCourts
          ..clear()
          ..addAll(selected);
        if (updated.isEmpty) _type = null;
      });
      widget.onChanged(updated);
    }
  }

  @override
  Widget build(BuildContext context) => AppSelectField<CourtType>(
    label: 'Court of practice',
    hint: 'Select court of practice',
    value: _type,
    options: CourtType.values,
    itemLabel: (court) => court.label,
    displayText: widget.value.join(', '),
    displayChild: widget.value.isEmpty
        ? null
        : Wrap(
            spacing: 6,
            runSpacing: 4,
            children: widget.value
                .map(
                  (court) => Chip(
                    label: Text(court),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(growable: false),
          ),
    onChanged: _typeChanged,
    validator: (_) => widget.value.isEmpty ? 'Required' : null,
  );

  Future<Set<String>?> _showHighCourtPicker(BuildContext context) =>
      showModalBottomSheet<Set<String>>(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        showDragHandle: true,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 560),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _CourtSearchSheet<HighCourt>(
          title: 'High Court',
          searchHint: 'Search High Court',
          load: _courts.fetchHighCourts,
          filter: _courts.searchHighCourts,
          initiallySelected: _selectedHighCourts,
          titleFor: (court) => court.name,
        ),
      );

  Future<Set<String>?> _showDistrictCourtPicker(BuildContext context) =>
      showModalBottomSheet<Set<String>>(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        showDragHandle: true,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 560),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _CourtSearchSheet<DistrictCourt>(
          title: 'District Court',
          searchHint: 'Search State / District / Court',
          load: _courts.fetchDistrictCourts,
          filter: _courts.searchDistrictCourts,
          initiallySelected: _selectedDistrictCourts,
          titleFor: (court) => court.name,
          subtitleFor: (court) => [
            court.district,
            court.state,
          ].where((part) => part.isNotEmpty).join(', '),
        ),
      );
}

class _CourtSearchSheet<T> extends StatefulWidget {
  const _CourtSearchSheet({
    required this.title,
    required this.searchHint,
    required this.load,
    required this.filter,
    required this.initiallySelected,
    required this.titleFor,
    this.subtitleFor,
  });

  final String title;
  final String searchHint;
  final Future<List<T>> Function() load;
  final List<T> Function(List<T>, String) filter;
  final Set<String> initiallySelected;
  final String Function(T) titleFor;
  final String Function(T)? subtitleFor;

  @override
  State<_CourtSearchSheet<T>> createState() => _CourtSearchSheetState<T>();
}

class _CourtSearchSheetState<T> extends State<_CourtSearchSheet<T>> {
  String _query = '';
  late Future<List<T>> _future;
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
    _selected = widget.initiallySelected.toSet();
  }

  void _retry() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: scheme.onSurface),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: TextField(
                autofocus: true,
                style: TextStyle(color: scheme.onSurface),
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<T>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Court data could not be loaded. Check your connection and try again.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _retry,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final items = widget.filter(
                    snapshot.data ?? const [],
                    _query,
                  );
                  if (items.isEmpty) {
                    return const Center(
                      child: Text('No matching courts found.'),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final itemTitle = widget.titleFor(item);
                      final selected = _selected.contains(itemTitle);
                      final subtitle = widget.subtitleFor?.call(item);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: selected
                              ? scheme.primary.withValues(alpha: .16)
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(13),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            title: Text(
                              itemTitle,
                              style: TextStyle(color: scheme.onSurface),
                            ),
                            subtitle: subtitle == null || subtitle.isEmpty
                                ? null
                                : Text(
                                    subtitle,
                                    style: TextStyle(
                                      color: scheme.onSurface.withValues(
                                        alpha: .72,
                                      ),
                                    ),
                                  ),
                            trailing: selected
                                ? Icon(
                                    Icons.check_circle,
                                    color: scheme.primary,
                                  )
                                : null,
                            onTap: () => setState(() {
                              if (selected) {
                                _selected.remove(itemTitle);
                              } else {
                                _selected.add(itemTitle);
                              }
                            }),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
