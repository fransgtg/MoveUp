import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moveup/screens/login_screen.dart';
import 'package:moveup/theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xff081124),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/sports/welcome.jpg',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x12061024),
                    Color(0xf508122c),
                  ],
                  stops: [0, .45, 1],
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: 'Move',
                            children: const [
                              TextSpan(
                                text: 'Up',
                                style: TextStyle(color: Color(0xff8ebbff)),
                              ),
                            ],
                          ),
                          style: AppTheme.display(72, color: Colors.white)
                              .copyWith(
                                fontStyle: FontStyle.italic,
                                letterSpacing: -2,
                              ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Teman latihanmu, dari langkah pertama hingga garis akhir.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.accentDeep,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 52),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            ),
                            child: const Text('Masuk'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
