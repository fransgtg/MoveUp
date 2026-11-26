import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moveup/screens/add_activity_screen.dart';
import 'package:moveup/screens/login_screen.dart';
import 'package:moveup/screens/splash_screen.dart';
import 'package:moveup/widgets.dart';

// Uji komponen bersama dan perilaku form (kualitas UI dan interaksi)
Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // Tes tidak boleh mengunduh font dari internet
  GoogleFonts.config.allowRuntimeFetching = false;

  group('tombol utama', () {
    testWidgets('loading menonaktifkan tombol dan menampilkan spinner', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(PrimaryButton(text: 'Simpan', loading: true, onPressed: () => taps++)));
      await tester.tap(find.byType(ElevatedButton));
      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('teks panjang dipotong tanpa overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(PrimaryButton(text: 'Simpan ' * 20, icon: Icons.check, onPressed: () {})));
      expect(tester.takeException(), isNull);
    });
  });

  group('dialog aksi destruktif', () {
    // Membuka dialog; hasil pilihan pengguna ditaruh di results
    Future<List<bool>> open(WidgetTester tester) async {
      final results = <bool>[];
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(await showConfirmDialog(
            context,
            title: 'Hapus target?',
            message: 'Target akan dihapus permanen.',
            confirmLabel: 'Hapus',
          )),
          child: const Text('buka'),
        ),
      )));
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('Batal tidak menghapus', (tester) async {
      final results = await open(tester);
      expect(find.text('Hapus target?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(results, [false]);
    });

    testWidgets('konfirmasi mengembalikan true', (tester) async {
      final results = await open(tester);
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(results, [true]);
    });

    testWidgets('fokus awal ada di tombol Batal', (tester) async {
      await open(tester);
      final batal = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Batal'));
      expect(batal.autofocus, isTrue);
    });
  });

  testWidgets('pesan sukses tampil setelah aksi selesai', (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () => showSuccessMessage(context, 'Target ditambahkan'),
        child: const Text('simpan'),
      ),
    )));
    await tester.tap(find.text('simpan'));
    await tester.pump();
    expect(find.text('Target ditambahkan'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('empty state memberi tombol aksi', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_app(EmptyStateWidget(
      message: 'Belum ada aktivitas',
      actionLabel: 'Catat Manual',
      onAction: () => tapped = true,
    )));
    await tester.tap(find.text('Catat Manual'));
    expect(tapped, isTrue);
  });

  group('field', () {
    testWidgets('berlabel dan menampilkan pesan error spesifik', (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(_app(Form(
        key: key,
        child: AppTextField(label: 'Nama target', validator: (v) => v!.isEmpty ? 'Nama target wajib diisi' : null),
      )));
      expect(find.text('Nama target'), findsOneWidget);
      key.currentState!.validate();
      await tester.pump();
      expect(find.text('Nama target wajib diisi'), findsOneWidget);
    });

    testWidgets('tombol berikutnya memindahkan fokus ke field tujuan', (tester) async {
      final next = FocusNode();
      addTearDown(next.dispose);
      await tester.pumpWidget(_app(Column(children: [
        AppTextField(label: 'Jam', nextFocus: next),
        AppTextField(label: 'Menit', focusNode: next),
      ])));
      await tester.tap(find.widgetWithText(TextField, 'Jam'));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(next.hasFocus, isTrue);
    });

    testWidgets('picker ikut divalidasi form', (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(_app(Form(
        key: key,
        child: PickerField<DateTime>(
          label: 'Tanggal',
          display: (v) => v == null ? 'Pilih tanggal' : '$v',
          pick: (_) async => null,
          validator: (v) => v == null ? 'Tanggal wajib diisi' : null,
        ),
      )));
      expect(find.text('Tanggal'), findsOneWidget);
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Tanggal wajib diisi'), findsOneWidget);
    });
  });

  testWidgets('keyboard tidak menutupi aksi utama', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FormLayout(
          action: PrimaryButton(text: 'Simpan', onPressed: () {}),
          children: [for (var i = 0; i < 12; i++) AppTextField(label: 'Isian $i')],
        ),
      ),
    ));
    final button = tester.getRect(find.byType(PrimaryButton));
    expect(button.bottom, lessThanOrEqualTo(800 - 300));
  });

  group('form Aktivitas Manual', () {
    testWidgets('punya minimal 5 isian berlabel', (tester) async {
      // Layar tinggi supaya seluruh isian dibangun oleh ListView
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: AddActivityScreen()));
      for (final label in ['Judul', 'Tanggal', 'Jam', 'Menit', 'Jarak', 'Catatan']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.byType(ChoiceChip), findsNWidgets(4));
      expect(find.text('Renang'), findsNothing);
    });

    testWidgets('simpan tanpa durasi menampilkan error spesifik', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AddActivityScreen()));
      await tester.tap(find.text('Simpan Aktivitas'));
      await tester.pump();
      expect(find.text('Isi durasi minimal 1 menit'), findsOneWidget);
    });

    testWidgets('menit di atas 59 ditolak', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AddActivityScreen()));
      await tester.enterText(find.widgetWithText(TextFormField, 'Menit'), '75');
      await tester.tap(find.text('Simpan Aktivitas'));
      await tester.pump();
      expect(find.text('Menit maksimal 59'), findsOneWidget);
    });
  });

  testWidgets('Google adalah satu-satunya pilihan login', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('Masuk dengan Google'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Daftar'), findsNothing);
  });

  testWidgets('halaman awal membuka login Google', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    expect(find.text('Daftar'), findsNothing);
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk dengan Google'), findsOneWidget);
  });
}
