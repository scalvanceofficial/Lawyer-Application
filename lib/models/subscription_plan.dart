import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.documentId,
    required this.id,
    required this.duration,
    required this.months,
    required this.price,
    required this.discount,
    required this.features,
    required this.popular,
    required this.active,
    this.appleProductId = '',
  });

  final String appleProductId;
  final String documentId;
  final int id;
  final String duration;
  final int months;
  final int price;
  final int discount;
  final List<String> features;
  final bool popular;
  final bool active;

  factory SubscriptionPlan.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final duration = _text(data, 'duration', 'Duration');
    final parsedMonths =
        _number(data, 'months', 'Months') ??
        int.tryParse(RegExp(r'\d+').firstMatch(duration)?.group(0) ?? '');

    return SubscriptionPlan(
      documentId: document.id,
      appleProductId: _text(data, 'appleProductId'),
      id: _number(data, 'id', 'planId') ?? 0,
      duration: duration.isEmpty ? 'Subscription Plan' : duration,
      months: parsedMonths == null || parsedMonths < 1 ? 1 : parsedMonths,
      price: _number(data, 'price', 'Price') ?? 0,
      discount: _number(data, 'discount', 'Discount') ?? 0,
      features: _features(data['features'] ?? data['Features']),
      popular:
          data['popular'] == true ||
          data['Popular'] == true ||
          data['Populer'] == true,
      active: data['active'] != false && data['Active'] != false,
    );
  }

  static String _text(
    Map<String, dynamic> data,
    String key, [
    String? alternate,
  ]) {
    return (data[key] ?? (alternate == null ? null : data[alternate]) ?? '')
        .toString()
        .trim();
  }

  static int? _number(
    Map<String, dynamic> data,
    String key, [
    String? alternate,
  ]) {
    final value = data[key] ?? (alternate == null ? null : data[alternate]);
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static List<String> _features(dynamic value) {
    if (value is! Iterable) return const [];
    return value
        .map((feature) => feature.toString().trim())
        .where((feature) => feature.isNotEmpty)
        .toList(growable: false);
  }
}
