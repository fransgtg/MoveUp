import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moveup/services/profile_service.dart';

// Nilai MET (metabolic equivalent) per kecepatan dari Compendium of Physical Activities 2011.
// Tiap pasangan adalah (km/j, MET); di antara titik tabel dihitung secara linear.
enum SportType {
  run('Lari', Icons.directions_run, 9.8, [
    (6.4, 6.0), (8.0, 8.3), (8.4, 9.0), (9.7, 9.8), (10.8, 10.5), (11.3, 11.0),
    (12.1, 11.5), (12.9, 11.8), (13.8, 12.3), (14.5, 12.8), (16.1, 14.5), (17.7, 16.0), (19.3, 19.0),
  ]),
  walk('Jalan', Icons.directions_walk, 3.5, [
    (3.2, 2.8), (4.0, 3.0), (4.8, 3.5), (5.6, 4.3), (6.4, 5.0), (7.2, 7.0), (8.0, 8.3),
  ]),
  // Compendium memberi rentang kecepatan untuk sepeda; di sini dipakai titik tengahnya
  ride('Sepeda', Icons.directions_bike, 6.8, [
    (12.0, 4.0), (17.5, 6.8), (20.9, 8.0), (24.0, 10.0), (28.0, 12.0), (32.0, 15.8),
  ]),
  // Hiking lebih ditentukan tanjakan daripada kecepatan, jadi memakai satu nilai tetap
  hike('Hiking', Icons.hiking, 6.0, []),
  // Dipertahankan untuk membaca data renang yang sudah tersimpan.
  swim('Renang', Icons.pool, 5.8, []);

  static const available = [run, walk, ride, hike];

  const SportType(this.label, this.icon, this.defaultMet, this._metBySpeed);

  final String label;
  final IconData icon;
  // Dipakai kalau kecepatan tidak diketahui, misalnya input manual tanpa jarak
  final double defaultMet;
  final List<(double, double)> _metBySpeed;

  // Sepeda lazim ditampilkan dalam km/j, olahraga lain dalam pace menit/km
  bool get showsSpeed => this == SportType.ride;

  double metAt(double speedKmh) {
    final table = _metBySpeed;
    if (table.isEmpty || speedKmh <= 0 || !speedKmh.isFinite) return defaultMet;
    if (speedKmh <= table.first.$1) return table.first.$2;
    if (speedKmh >= table.last.$1) return table.last.$2;
    for (var i = 1; i < table.length; i++) {
      final (s1, m1) = table[i];
      if (speedKmh <= s1) {
        final (s0, m0) = table[i - 1];
        return m0 + (m1 - m0) * (speedKmh - s0) / (s1 - s0);
      }
    }
    return table.last.$2;
  }

  // Kalori = MET × berat badan (kg) × jam bergerak
  int caloriesFor({required double meters, required int seconds, required double weightKg}) {
    if (seconds <= 0) return 0;
    final hours = seconds / 3600;
    return (metAt(meters / 1000 / hours) * weightKg * hours).round();
  }

  // Kategori olahraga adalah data referensi; name dipakai sebagai ID relasi di target dan pengingat
  String get id => name;

  static SportType fromName(String name) =>
      SportType.values.firstWhere((t) => t.name == name, orElse: () => SportType.run);
}

class TrackPoint {
  const TrackPoint(this.lat, this.lng, this.t, this.segment);

  final double lat;
  final double lng;
  // Detik waktu bergerak saat titik direkam (tidak termasuk waktu jeda)
  final double t;
  // Nomor segmen; bertambah setiap kali rekaman dilanjutkan setelah jeda
  final int segment;

  List<num> toJson() => [lat, lng, t, segment];

  factory TrackPoint.fromJson(List<dynamic> json) => TrackPoint(
        (json[0] as num).toDouble(),
        (json[1] as num).toDouble(),
        (json[2] as num).toDouble(),
        (json[3] as num).toInt(),
      );
}

class KmSplit {
  const KmSplit(this.index, this.distanceMeters, this.seconds);

  final int index;
  final double distanceMeters;
  final double seconds;

  double get paceSecPerKm => seconds / (distanceMeters / 1000);
  double get speedKmh => (distanceMeters / 1000) / (seconds / 3600);
}

class Activity {
  const Activity({
    required this.id,
    required this.type,
    required this.title,
    this.description = '',
    required this.startTime,
    required this.movingSeconds,
    required this.distanceMeters,
    this.points = const [],
    this.photos = const [],
  });

  final String id;
  final SportType type;
  final String title;
  final String description;
  final DateTime startTime;
  final int movingSeconds;
  final double distanceMeters;
  final List<TrackPoint> points;
  // Nama file foto di folder foto aplikasi (lihat PhotoStore)
  final List<String> photos;

  bool get hasRoute => points.length > 1;

  Activity copyWith({List<TrackPoint>? points, List<String>? photos}) => Activity(
        id: id,
        type: type,
        title: title,
        description: description,
        startTime: startTime,
        movingSeconds: movingSeconds,
        distanceMeters: distanceMeters,
        points: points ?? this.points,
        photos: photos ?? this.photos,
      );

  double get km => distanceMeters / 1000;

  double? get paceSecPerKm => km < 0.01 ? null : movingSeconds / km;

  double get speedKmh => movingSeconds == 0 ? 0 : km / (movingSeconds / 3600);

  // Memakai berat badan dari profil pengguna yang sedang masuk
  int get calories =>
      type.caloriesFor(meters: distanceMeters, seconds: movingSeconds, weightKg: ProfileService.instance.weightKg);

  List<KmSplit> get splits {
    final result = <KmSplit>[];
    if (points.length < 2) return result;

    var cumDist = 0.0;
    var nextKm = 1000.0;
    var lastSplitTime = points.first.t;
    var lastSplitDist = 0.0;

    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (a.segment != b.segment) continue;
      final d = haversineMeters(a.lat, a.lng, b.lat, b.lng);
      while (cumDist + d >= nextKm) {
        final frac = d == 0 ? 0 : (nextKm - cumDist) / d;
        final crossTime = a.t + (b.t - a.t) * frac;
        result.add(KmSplit(result.length + 1, 1000, crossTime - lastSplitTime));
        lastSplitTime = crossTime;
        lastSplitDist = nextKm;
        nextKm += 1000;
      }
      cumDist += d;
    }

    final rest = cumDist - lastSplitDist;
    final restTime = points.last.t - lastSplitTime;
    if (rest >= 50 && restTime > 0) {
      result.add(KmSplit(result.length + 1, rest, restTime));
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'description': description,
        'startTime': startTime.toIso8601String(),
        'movingSeconds': movingSeconds,
        'distanceMeters': distanceMeters,
        'points': points.map((p) => p.toJson()).toList(),
        'photos': photos,
      };

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'] as String,
        type: SportType.fromName(json['type'] as String),
        title: json['title'] as String,
        description: (json['description'] as String?) ?? '',
        startTime: DateTime.parse(json['startTime'] as String),
        movingSeconds: (json['movingSeconds'] as num).toInt(),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        points: ((json['points'] as List?) ?? [])
            .map((p) => TrackPoint.fromJson(p as List<dynamic>))
            .toList(),
        photos: ((json['photos'] as List?) ?? []).cast<String>(),
      );
}

double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(h));
}

double _rad(double deg) => deg * math.pi / 180;
