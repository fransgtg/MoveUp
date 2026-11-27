import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// Daftar data milik satu akun yang disimpan sebagai file JSON di penyimpanan aplikasi.
// Akun baru dimulai dengan isi awal yang ditentukan oleh [seed].
abstract class JsonListStore<T> extends ChangeNotifier {
  JsonListStore(this._fileName);

  final String _fileName;
  final List<T> _items = [];
  String? _uid;
  int _loadVersion = 0;
  Future<void> _pendingSave = Future.value();

  List<T> get items => List.unmodifiable(_items);

  String idOf(T item);
  Map<String, dynamic> encode(T item);
  T decode(Map<String, dynamic> json);
  List<T> seed();

  // Urutan tampilan; null berarti mengikuti urutan penambahan
  Comparator<T>? get order => null;

  // Melengkapi data versi lama setelah dibaca; kembalikan null kalau tidak ada yang berubah
  List<T>? upgrade(List<T> loaded) => null;

  T? byId(String id) {
    for (final item in _items) {
      if (idOf(item) == id) return item;
    }
    return null;
  }

  Future<File> fileFor(String uid) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/${_fileName}_$uid.json');
  }

  Future<void> loadFor(String uid) async {
    if (_uid == uid) return;
    final version = ++_loadVersion;
    _uid = uid;
    _items.clear();
    notifyListeners();
    try {
      await _pendingSave;
      final file = await fileFor(uid);
      final exists = await file.exists();
      final read = exists
          ? (jsonDecode(await file.readAsString()) as List<dynamic>)
              .map((e) => decode(e as Map<String, dynamic>))
              .toList()
          : seed();
      final upgraded = exists ? upgrade(read) : null;
      final loaded = upgraded ?? read;
      // Pengguna bisa saja keluar selagi file dibaca
      if (version != _loadVersion) return;
      _items
        ..clear()
        ..addAll(loaded);
      _sort();
      final save = !exists || upgraded != null ? _save() : null;
      notifyListeners();
      await save;
    } catch (e) {
      debugPrint('Gagal memuat $_fileName: $e');
    }
  }

  void clear() {
    _loadVersion++;
    _uid = null;
    _items.clear();
    notifyListeners();
  }

  Future<void> add(T item) async {
    _items.add(item);
    await _changed();
  }

  Future<void> update(T item) async {
    final i = _items.indexWhere((e) => idOf(e) == idOf(item));
    if (i < 0) return;
    _items[i] = item;
    await _changed();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((e) => idOf(e) == id);
    await _changed();
  }

  Future<void> replaceAll(List<T> items) async {
    _items
      ..clear()
      ..addAll(items);
    await _changed();
  }

  Future<void> resetToSample() => replaceAll(seed());

  Future<void> _changed() async {
    _sort();
    final save = _save();
    notifyListeners();
    await save;
  }

  void _sort() {
    final compare = order;
    if (compare != null) _items.sort(compare);
  }

  Future<void> _save() {
    final uid = _uid;
    if (uid == null) return Future.value();
    final contents = jsonEncode(_items.map(encode).toList());
    final save = _pendingSave.then((_) async {
      final file = await fileFor(uid);
      // Tulis ke file sementara sebelum mengganti data akun.
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(contents);
      await tmp.rename(file.path);
    });
    _pendingSave = save.catchError((Object _) {});
    return save;
  }
}
