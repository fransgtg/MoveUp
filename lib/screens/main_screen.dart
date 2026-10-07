import 'package:flutter/material.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/screens/dashboard_screen.dart';
import 'package:moveup/screens/gps_tracking_screen.dart';
import 'package:moveup/screens/history_screen.dart';
import 'package:moveup/screens/statistics_screen.dart';
import 'package:moveup/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    HistoryScreen(),
    SizedBox(), // Slot tombol Rekam di tengah, dibuka sebagai halaman terpisah
    StatisticsScreen(),
    ProfileScreen(),
  ];

  void _openRecorder() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const GpsTrackingScreen()));
  }

  void _select(int index) {
    if (index == 2) {
      _openRecorder();
    } else {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.accentGradient,
          boxShadow: AppTheme.softShadow(AppTheme.accent, alpha: 0.45),
        ),
        child: RawMaterialButton(
          shape: const CircleBorder(),
          onPressed: _openRecorder,
          child: const Tooltip(
            message: "Rekam aktivitas",
            child: Icon(Icons.fiber_manual_record, size: 30, color: Colors.white),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        // Sedikit tembus pandang supaya gradasi latar tetap terasa di balik navigasi
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: "Beranda",
              selected: _currentIndex == 0,
              onTap: () => _select(0),
            ),
            _NavItem(
              icon: Icons.access_time,
              activeIcon: Icons.access_time_filled,
              label: "Riwayat",
              selected: _currentIndex == 1,
              onTap: () => _select(1),
            ),
            // Ruang kosong untuk tombol Rekam yang menempel di tengah
            const Expanded(child: SizedBox()),
            _NavItem(
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart_rounded,
              label: "Statistik",
              selected: _currentIndex == 3,
              onTap: () => _select(3),
            ),
            _NavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: "Profil",
              selected: _currentIndex == 4,
              onTap: () => _select(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? scheme.primary.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(selected ? activeIcon : icon, color: color, size: 24),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
