import 'package:flutter/material.dart';

class MultiSelectFormField extends FormField<Set<String>> {
  MultiSelectFormField({
    super.key,
    required String label,
    required List<String> options,
    required Set<String> selected,
    required ValueChanged<Set<String>> onChanged,
    bool loading = false,
    String? errorText,
  }) : super(
         initialValue: selected,
         validator: (value) =>
             value == null || value.isEmpty ? 'Select at least one area' : null,
         builder: (state) {
           final current = state.value ?? <String>{};

           Future<void> openPicker() async {
             if (loading || options.isEmpty) return;
             final temporary = {...current};
             final result = await showDialog<Set<String>>(
               context: state.context,
               builder: (context) => StatefulBuilder(
                 builder: (context, setDialogState) => AlertDialog(
                   title: Text(label),
                   content: SizedBox(
                     width: double.maxFinite,
                     child: ListView(
                       shrinkWrap: true,
                       children: options
                           .map(
                             (option) => CheckboxListTile(
                               value: temporary.contains(option),
                               title: Text(option),
                               controlAffinity: ListTileControlAffinity.leading,
                               onChanged: (checked) => setDialogState(() {
                                 checked == true
                                     ? temporary.add(option)
                                     : temporary.remove(option);
                               }),
                             ),
                           )
                           .toList(),
                     ),
                   ),
                   actions: [
                     TextButton(
                       onPressed: () => Navigator.pop(context),
                       child: const Text('Cancel'),
                     ),
                     FilledButton(
                       onPressed: temporary.isEmpty
                           ? null
                           : () => Navigator.pop(context, temporary),
                       child: const Text('Apply'),
                     ),
                   ],
                 ),
               ),
             );
             if (result == null) return;
             state.didChange(result);
             onChanged(result);
           }

           return InkWell(
             onTap: openPicker,
             borderRadius: BorderRadius.circular(12),
             child: InputDecorator(
               isEmpty: current.isEmpty,
               decoration: InputDecoration(
                 labelText: label,
                 hintText: loading
                     ? 'Loading live values…'
                     : 'Choose one or more areas',
                 errorText: state.errorText ?? errorText,
                 suffixIcon: loading
                     ? const Padding(
                         padding: EdgeInsets.all(13),
                         child: SizedBox.square(
                           dimension: 18,
                           child: CircularProgressIndicator(strokeWidth: 2),
                         ),
                       )
                     : const Icon(Icons.arrow_drop_down),
               ),
               child: current.isEmpty
                   ? const SizedBox(height: 20)
                   : Wrap(
                       spacing: 6,
                       runSpacing: 4,
                       children: current
                           .map(
                             (value) => Chip(
                               label: Text(value),
                               visualDensity: VisualDensity.compact,
                             ),
                           )
                           .toList(),
                     ),
             ),
           );
         },
       );
}
