import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

// Pengaturan tampilan yang berlaku untuk semua akun di perangkat ini
class SettingsService extends ChangeNotifier {
  SettingsService._();

  static final instance = SettingsService._();

  // Default gelap: tema utama aplikasi; pengguna tetap bisa memilih Terang atau Sistem
  ThemeMode _themeMode = ThemeMode.dark;
  bool _voiceCoach = true;

  ThemeMode get themeMode => _themeMode;

  // Pengumuman suara setiap 1 km saat merekam aktivitas
  bool get voiceCoach => _voiceCoach;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/settings.json');
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _themeMode = ThemeMode.values.asNameMap()[json['themeMode']] ?? ThemeMode.dark;
      _voiceCoach = json['voiceCoach'] as bool? ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Gagal memuat pengaturan: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _changed();
  }

  Future<void> setVoiceCoach(bool on) async {
    _voiceCoach = on;
    await _changed();
  }

  Future<void> _changed() async {
    notifyListeners();
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode({'themeMode': _themeMode.name, 'voiceCoach': _voiceCoach}));
    } catch (e) {
      debugPrint('Gagal menyimpan pengaturan: $e');
    }
  }
}
