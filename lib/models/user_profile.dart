import 'user_role.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
    required this.address,
    required this.imageUrl,
    required this.bio,
    required this.barCouncilId,
    required this.expertise,
    required this.courts,
    required this.experience,
    required this.availability,
    required this.consultationFee,
  });

  final String id;
  final UserRole role;
  final String name;
  final String email;
  final String phone;
  final String dateOfBirth;
  final String gender;
  final String address;
  final String imageUrl;
  final String bio;
  final String barCouncilId;
  final String expertise;
  final String courts;
  final String experience;
  final List<String> availability;
  final int consultationFee;

  factory UserProfile.fromMap({
    required String id,
    required UserRole role,
    required Map<String, dynamic> data,
  }) {
    String text(String key, [String? alternate]) {
      final value = data[key] ?? (alternate == null ? null : data[alternate]);
      if (value == null) return '';
      if (value is Iterable) return value.join(', ');
      return value.toString().trim();
    }

    final courtValue = data['court'];
    final courts = courtValue is Iterable
        ? courtValue.join(', ')
        : (courtValue ?? data['courtType'] ?? '').toString();

    return UserProfile(
      id: id,
      role: role,
      name: text('name'),
      email: text('email'),
      phone: text('phone'),
      dateOfBirth: text('dob', 'dateOfBirth'),
      gender: text('gender'),
      address: text('address', 'location'),
      imageUrl: text('img', 'imageUrl'),
      bio: text('bio'),
      barCouncilId: text('barid', 'barCouncilId'),
      expertise: text('aoe', 'expertise'),
      courts: courts,
      experience: text('experience', 'experienceYears'),
      availability: (data['availability'] as Iterable? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      consultationFee: data['fee'] is num
          ? (data['fee'] as num).round()
          : int.tryParse(data['fee']?.toString() ?? '') ?? 0,
    );
  }

  String get displayName => name.isEmpty ? 'User' : name;
  String get displayEmail => email.isEmpty ? 'Not provided' : email;
  String get displayPhone => phone.isEmpty ? 'Not provided' : phone;
  String get displayAddress => address.isEmpty ? 'Not provided' : address;
}
