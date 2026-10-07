import 'package:flutter/material.dart';
import 'package:moveup/screens/login_screen.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/widgets.dart';

// Langit berkabut di atas garis cakrawala dengan siluet pelari, seperti foto referensi tema
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Langit senja biru: pucat di atas, makin biru di dekat cakrawala
    const sky = [Color(0xFFEAF1FB), Color(0xFFBCD2F3), Color(0xFF7EA6EA)];
    const ground = Color(0xFF0B1222);

    return Scaffold(
      backgroundColor: ground,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: sky),
                  ),
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // Matahari senja separuh tenggelam di cakrawala: inti kuning keemasan
                      // memudar ke jingga kemerahan, dengan pendar hangat di sekelilingnya
                      Positioned(
                        right: 24,
                        bottom: -70,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [Color(0xFFFFD27A), Color(0xFFFF8A3D), Color(0xFFF2542D)],
                              stops: [0, 0.55, 1],
                            ),
                            boxShadow: [
                              BoxShadow(color: Color(0x99FF7A2F), blurRadius: 40, spreadRadius: 6),
                              BoxShadow(color: Color(0x40FFB347), blurRadius: 90, spreadRadius: 30),
                            ],
                          ),
                        ),
                      ),
                      const Positioned(
                        right: 70,
                        bottom: 0,
                        child: Icon(Icons.directions_run, size: 56, color: ground),
                      ),
                    ],
                  ),
                ),
              ),
              Container(height: 3, color: const Color(0xFF8E8E8A)),
              // Tanah malam bergradasi gelap ke hitam
              const Expanded(
                flex: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF14203A), Color(0xFF060A14)],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
              ),
            ],
          ),
          const Positioned.fill(child: FilmGrain(opacity: 0.08)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  Text("MOVEUP", style: AppTheme.display(64, color: ground, letterSpacing: 8)),
                  Text(
                    "RUN · RIDE · HIKE",
                    style: AppTheme.display(16, color: AppTheme.accentDeep, letterSpacing: 4),
                  ),
                  const Spacer(),
                  const Text(
                    "Mulai langkah sehatmu hari ini, tanpa tekanan. Pantau setiap langkah, kayuhan, dan tanjakan.",
                    style: TextStyle(fontSize: 16, color: Color(0xFFBDBDB9), height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      onPressed: () {
                        // push (bukan replace) supaya AuthGate tetap menjadi halaman dasar
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                      },
                      child: Text("MULAI SEKARANG", style: AppTheme.display(18, letterSpacing: 2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
