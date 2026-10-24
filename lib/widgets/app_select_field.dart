import 'package:flutter/material.dart';

class AppSelectField<T> extends FormField<T> {
  AppSelectField({
    super.key,
    required String label,
    required T? value,
    required List<T> options,
    required String Function(T value) itemLabel,
    required ValueChanged<T?> onChanged,
    String? hint,
    String? clearLabel,
    String? helperText,
    String? displayText,
    Widget? displayChild,
    Widget? suffix,
    bool enabled = true,
    super.validator,
  }) : super(
         initialValue: value,
         builder: (state) {
           final selected = state.value;

           void choose(T? next) {
             state.didChange(next);
             onChanged(next);
             Navigator.of(state.context).pop();
           }

           Future<void> openPicker() async {
             if (!enabled) return;
             final scheme = Theme.of(state.context).colorScheme;
             await showModalBottomSheet<void>(
               context: state.context,
               backgroundColor: scheme.surface,
               showDragHandle: true,
               isScrollControlled: true,
               constraints: const BoxConstraints(maxWidth: 560),
               shape: const RoundedRectangleBorder(
                 borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
               ),
               builder: (sheetContext) => SafeArea(
                 top: false,
                 child: ConstrainedBox(
                   constraints: BoxConstraints(
                     maxHeight: MediaQuery.sizeOf(sheetContext).height * .62,
                   ),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                       Padding(
                         padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                         child: Row(
                           children: [   
                             Expanded(
                               child: Text(
                                 label,
                                 style: TextStyle(
                                   color: scheme.onSurface,
                                   fontSize: 18,
                                   fontWeight: FontWeight.w800,
                                 ),
                               ),
                             ),
                             IconButton(
                               tooltip: 'Close',
                               onPressed: () => Navigator.pop(sheetContext),
                               icon: Icon(Icons.close, color: scheme.onSurface),
                             ),
                           ],
                         ),
                       ),
                       Flexible(
                         child: ListView(
                           shrinkWrap: true,
                           padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                           children: [
                             if (clearLabel != null)
                               _SelectOption(
                                 label: clearLabel,
                                 selected: selected == null,
                                 onTap: () => choose(null),
                               ),
                             for (final option in options)
                               _SelectOption(
                                 label: itemLabel(option),
                                 selected: option == selected,
                                 onTap: () => choose(option),
                               ),
                           ],
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
             );
           }

           return InkWell(
             onTap: openPicker,
             borderRadius: BorderRadius.circular(13),
             child: InputDecorator(
               isEmpty: selected == null,
               decoration: InputDecoration(
                 labelText: label,
                 hintText: hint ?? 'Select $label',
                 helperText: helperText,
                 errorText: state.errorText,
                 enabled: enabled,
                 suffixIcon:
                     suffix ??
                     Icon(
                       Icons.keyboard_arrow_down_rounded,
                       color: Theme.of(state.context).colorScheme.onSurface,
                     ),
               ),
               child: selected == null
                   ? const SizedBox(height: 18)
                   : displayChild ??
                         Text(
                           displayText ?? itemLabel(selected),
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                           style: TextStyle(
                             color: Theme.of(
                               state.context,
                             ).colorScheme.onSurface,
                             fontSize: 16,
                             fontWeight: FontWeight.w500,
                           ),
                         ),
             ),
           );
         },
       );
}

class _SelectOption extends StatelessWidget {
  const _SelectOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: .16)
            : scheme.surface,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: scheme.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
