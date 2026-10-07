import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:moveup/models/activity.dart';

// Mendeteksi setiap kali jarak rekaman melewati kilometer bulat dan menyusun kalimat pengumumannya.
// Tidak bergantung pada GPS atau suara, jadi bisa diuji langsung.
class KmAnnouncer {
  KmAnnouncer(this.type);

  final SportType type;

  int _lastKm = 0;
  double _lastKmSeconds = 0;
  double? _previousSplit;

  // Dipanggil setiap titik GPS baru. [fromMeters]/[fromSeconds] = posisi sebelumnya, [toMeters]/[toSeconds] = sekarang.
  // Mengembalikan kalimat untuk setiap kilometer yang terlewati di antara keduanya.
  List<String> update({
    required double fromMeters,
    required double fromSeconds,
    required double toMeters,
    required double toSeconds,
  }) {
    final result = <String>[];
    while (toMeters >= (_lastKm + 1) * 1000) {
      final km = _lastKm + 1;
      // Waktu saat tepat melewati kilometer ini, dikira dari dua titik di sekitarnya
      final frac = toMeters == fromMeters ? 1.0 : (km * 1000 - fromMeters) / (toMeters - fromMeters);
      final crossSeconds = fromSeconds + (toSeconds - fromSeconds) * frac.clamp(0.0, 1.0);
      final split = crossSeconds - _lastKmSeconds;
      result.add(buildAnnouncement(
        type: type,
        km: km,
        totalSeconds: crossSeconds,
        splitSeconds: split,
        previousSplitSeconds: _previousSplit,
      ));
      _previousSplit = split;
      _lastKmSeconds = crossSeconds;
      _lastKm = km;
    }
    return result;
  }

  static String buildAnnouncement({
    required SportType type,
    required int km,
    required double totalSeconds,
    required double splitSeconds,
    double? previousSplitSeconds,
  }) {
    final parts = <String>[
      'Jarak $km kilometer.',
      'Waktu ${spokenDuration(totalSeconds)}.',
    ];
    if (type.showsSpeed) {
      // Bersepeda lebih lazim memakai kecepatan daripada pace
      final speed = 3600 / splitSeconds;
      parts.add('Kecepatan kilometer ini ${_decimal(speed)} kilometer per jam.');
      if (previousSplitSeconds != null) {
        final diff = speed - 3600 / previousSplitSeconds;
        parts.add(diff.abs() < 0.1
            ? 'Sama dengan kilometer sebelumnya.'
            : '${_decimal(diff.abs())} kilometer per jam ${diff > 0 ? 'lebih cepat' : 'lebih lambat'} dari kilometer sebelumnya.');
      }
      parts.add('Kecepatan rata-rata ${_decimal(km * 3600 / totalSeconds)} kilometer per jam.');
    } else {
      parts.add('Pace kilometer ini ${spokenDuration(splitSeconds)} per kilometer.');
      if (previousSplitSeconds != null) {
        final diff = (splitSeconds - previousSplitSeconds).round();
        parts.add(diff == 0
            ? 'Sama dengan kilometer sebelumnya.'
            : '${spokenDuration(diff.abs().toDouble())} ${diff < 0 ? 'lebih cepat' : 'lebih lambat'} dari kilometer sebelumnya.');
      }
      if (km > 1) parts.add('Pace rata-rata ${spokenDuration(totalSeconds / km)} per kilometer.');
    }
    return parts.join(' ');
  }

  // 754 detik → "12 menit 34 detik"; 3725 → "1 jam 2 menit 5 detik"
  static String spokenDuration(double seconds) {
    final total = seconds.round();
    final h = total ~/ 3600, m = total % 3600 ~/ 60, s = total % 60;
    return [
      if (h > 0) '$h jam',
      if (m > 0) '$m menit',
      if (s > 0 || total == 0) '$s detik',
    ].join(' ');
  }

  static String _decimal(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
}

// Membacakan pengumuman dengan suara bahasa Indonesia; musik yang sedang diputar dipelankan sebentar
class VoiceCoach {
  VoiceCoach._();

  static final instance = VoiceCoach._();

  final _tts = FlutterTts();
  bool _ready = false;
  bool _indonesian = false;

  // Suara bahasa Indonesia membaca "pace" sebagai "pa-ce"; ejaan "peis" terdengar seperti pelafalan Inggrisnya
  static String forIndonesianSpeech(String text) =>
      text.replaceAllMapped(RegExp(r'\b([Pp])ace\b'), (m) => '${m[1]}eis');

  Future<void> _init() async {
    if (_ready) return;
    try {
      _indonesian = await _tts.isLanguageAvailable('id-ID') == true;
      await _tts.setLanguage(_indonesian ? 'id-ID' : 'en-US');
      await _tts.setSpeechRate(0.5);
      // Pengumuman berikutnya menunggu yang sebelumnya selesai (1 = antre)
      await _tts.setQueueMode(1);
      _ready = true;
    } catch (e) {
      debugPrint('Text-to-speech tidak tersedia: $e');
    }
  }

  Future<void> speak(String text) async {
    debugPrint('Pengumuman suara: $text');
    await _init();
    if (!_ready) return;
    try {
      await _tts.speak(_indonesian ? forIndonesianSpeech(text) : text, focus: true);
    } catch (e) {
      debugPrint('Gagal membacakan pengumuman: $e');
    }
  }

  Future<void> stop() async {
    if (_ready) await _tts.stop();
  }
}
