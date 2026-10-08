import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moveup/models/activity.dart';

enum Gender {
  male('Laki-laki'),
  female('Perempuan');

  const Gender(this.label);

  final String label;
}

enum FitnessLevel {
  beginner('Pemula', 'Baru mulai atau jarang berolahraga'),
  intermediate('Menengah', 'Rutin berolahraga 1–3 kali seminggu'),
  advanced('Lanjutan', 'Berlatih lebih dari 3 kali seminggu');

  const FitnessLevel(this.label, this.description);

  final String label;
  final String description;
}

// Data profil pengguna yang disimpan di Firestore: users/{uid}
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.gender,
    required this.birthDate,
    required this.weightKg,
    required this.heightCm,
    required this.level,
    required this.favoriteSports,
  });

  final String uid;
  final String name;
  final String email;
  final Gender gender;
  final DateTime birthDate;
  final double weightKg;
  final double heightCm;
  final FitnessLevel level;
  final List<SportType> favoriteSports;

  String get initials => initialsOf(name);

  int get age => ageOn(birthDate, DateTime.now());

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  // Kategori BMI Asia-Pasifik (WHO), yang dipakai Kemenkes
  String get bmiCategory {
    final b = bmi;
    if (b < 18.5) return 'Kurus';
    if (b < 23) return 'Normal';
    if (b < 25) return 'Berlebih';
    return 'Obesitas';
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'gender': gender.name,
        'birthDate': Timestamp.fromDate(birthDate),
        'weightKg': weightKg,
        'heightCm': heightCm,
        'level': level.name,
        'favoriteSports': favoriteSports.map((s) => s.name).toList(),
      };

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) => UserProfile(
        uid: uid,
        name: map['name'] as String,
        email: map['email'] as String,
        gender: Gender.values.byName(map['gender'] as String),
        birthDate: (map['birthDate'] as Timestamp).toDate(),
        weightKg: (map['weightKg'] as num).toDouble(),
        heightCm: (map['heightCm'] as num).toDouble(),
        level: FitnessLevel.values.byName(map['level'] as String),
        favoriteSports: ((map['favoriteSports'] as List?) ?? []).map((s) => SportType.fromName(s as String)).toList(),
      );
}

int ageOn(DateTime birthDate, DateTime today) {
  var age = today.year - birthDate.year;
  if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) age--;
  return age;
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
