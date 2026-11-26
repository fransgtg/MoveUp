import 'package:flutter/material.dart';
import 'package:moveup/services/auth_service.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final signedIn = await AuthService.signInWithGoogle();
      if (signedIn && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthFailure catch (e) {
      if (mounted) showErrorMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.darkTheme;
    final scheme = theme.colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        const SportsPhotoBackground(
          'assets/sports/login-cycling-blue.png',
          opacity: 0.15,
        ),
        Theme(
          data: theme,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: AppSpacing.page,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'SELAMAT DATANG',
                          style: AppTheme.display(38, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Gunakan akun Google untuk memulai atau melanjutkan latihanmu.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _signIn,
                          icon: _loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'G',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                          label: const Text('Masuk dengan Google'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
