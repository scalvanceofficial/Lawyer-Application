import 'package:cloud_firestore/cloud_firestore.dart';

class LegalTaxonomyRepository {
  LegalTaxonomyRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<String>> watchAreasOfExpertise() {
    return _firestore.collection('areaofexpertise').snapshots().map((snapshot) {
      final values = <({int order, String value})>[];
      for (final document in snapshot.docs) {
        for (final entry in document.data().entries) {
          final order = int.tryParse(entry.key) ?? 100000;
          final raw = entry.value;
          if (raw is String && raw.trim().isNotEmpty) {
            values.add((order: order, value: raw.trim()));
          } else if (raw is Iterable) {
            var nestedOrder = order;
            for (final item in raw) {
              final value = item.toString().trim();
              if (value.isNotEmpty) {
                values.add((order: nestedOrder++, value: value));
              }
            }
          }
        }
      }
      values.sort((a, b) {
        final order = a.order.compareTo(b.order);
        return order == 0 ? a.value.compareTo(b.value) : order;
      });
      final unique = <String>{};
      return values
          .map((item) => item.value)
          .where(unique.add)
          .toList(growable: false);
    });
  }
}
