import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:moveup/services/activity_store.dart';
import 'package:moveup/services/coach_service.dart';
import 'package:moveup/services/goal_store.dart';
import 'package:moveup/services/profile_service.dart';
import 'package:moveup/services/reminder_store.dart';
import 'package:moveup/services/social_notifications.dart';

// Pesan error yang ramah pengguna untuk dilempar ke UI
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get userChanges => _auth.userChanges();

  static bool _googleReady = false;

  // Di Android, client ID diambil otomatis dari google-services.json
  static Future<void> _initGoogle() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize();
    _googleReady = true;
  }

  // Mengembalikan false kalau pengguna menutup pemilih akun Google.
  // Pengguna baru belum punya profil, jadi AuthGate akan membuka layar Lengkapi Profil.
  static Future<bool> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        await _guard(() => _auth.signInWithPopup(GoogleAuthProvider()));
      } else {
        await _initGoogle();
        if (!GoogleSignIn.instance.supportsAuthenticate()) {
          throw const AuthFailure('Login Google belum tersedia pada perangkat ini.');
        }
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) throw const AuthFailure('Google tidak mengirim token login. Coba lagi.');
        await _guard(() => _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken)));
      }
      return true;
    } on AuthFailure catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') return false;
      rethrow;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      final misconfigured = e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError;
      throw AuthFailure(
        misconfigured
            ? 'Login Google belum dikonfigurasi. Pastikan SHA-1 aplikasi sudah didaftarkan di Firebase.'
            : 'Login Google gagal (${e.code.name}). Coba lagi.',
        code: e.code.name,
      );
    }
  }

  // Akun Google tidak punya password MoveUp, jadi fitur ganti password tidak berlaku
  static bool get hasPasswordLogin =>
      currentUser?.providerData.any((p) => p.providerId == EmailAuthProvider.PROVIDER_ID) ?? false;

  static Future<void> resendVerification() => _guard(() => _auth.currentUser!.sendEmailVerification());

  // Mengembalikan true kalau email sudah diverifikasi setelah data pengguna dimuat ulang
  static Future<bool> reloadAndCheckVerified() async {
    await _guard(() => _auth.currentUser!.reload());
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) return false;
    await _guard(() => user.getIdToken(true));
    return true;
  }

  // Firebase mewajibkan login ulang sebelum ganti password
  static Future<void> changePassword(String currentPassword, String newPassword) {
    return _guard(() async {
      final user = _auth.currentUser!;
      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    });
  }

  static Future<void> signOut() async {
    // Keluar juga dari Google supaya lain kali pemilih akun muncul lagi
    final uid = currentUser?.uid;
    await _auth.signOut();
    if (uid != null) {
      try {
        await SocialNotifications.clearAccount(uid);
      } catch (e) {
        debugPrint('Gagal membersihkan notifikasi: $e');
      }
    }
    CoachService.instance.reset();
    ProfileService.instance.clear();
    ActivityStore.instance.clear();
    GoalStore.instance.clear();
    ReminderStore.instance.clear();
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } on GoogleSignInException catch (e) {
        debugPrint('Gagal menutup pemilih akun Google: ${e.code.name}');
      }
    }
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(messageFor(e.code), code: e.code);
    } on FirebaseException catch (e) {
      throw AuthFailure(code: e.code, e.code == 'permission-denied'
          ? 'Akses database ditolak. Periksa aturan keamanan Firestore.'
          : 'Terjadi kesalahan server (${e.code}). Coba lagi.');
    }
  }

  static String messageFor(String code) => switch (code) {
        'invalid-email' => 'Format email tidak valid.',
        'user-disabled' => 'Akun ini telah dinonaktifkan.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email atau password salah.',
        'email-already-in-use' => 'Email sudah terdaftar. Silakan masuk.',
        'weak-password' => 'Password terlalu lemah.',
        'too-many-requests' => 'Terlalu banyak percobaan. Tunggu beberapa saat lalu coba lagi.',
        'network-request-failed' => 'Tidak ada koneksi internet.',
        'requires-recent-login' => 'Demi keamanan, silakan masuk ulang lalu coba lagi.',
        'operation-not-allowed' => 'Metode login ini belum diaktifkan di Firebase Console.',
        'account-exists-with-different-credential' =>
          'Email ini sudah terdaftar dengan metode lain. Akun lama perlu ditautkan ke Google.',
        _ => 'Terjadi kesalahan ($code). Coba lagi.',
      };
}
