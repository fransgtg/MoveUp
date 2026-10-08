import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/screens/save_activity_screen.dart';
import 'package:moveup/services/profile_service.dart';
import 'package:moveup/services/recording_notification.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/utils/format.dart';
import 'package:moveup/widgets/route_map.dart';
import 'package:moveup/widgets.dart';
import 'package:moveup/services/settings_service.dart';
import 'package:moveup/services/voice_coach.dart';

enum _RecordState { ready, recording, paused }

class GpsTrackingScreen extends StatefulWidget {
  const GpsTrackingScreen({super.key, this.initialType = SportType.run});

  final SportType initialType;

  @override
  State<GpsTrackingScreen> createState() => _GpsTrackingScreenState();
}

class _GpsTrackingScreenState extends State<GpsTrackingScreen> {
  // Default ke Jakarta sampai lokasi pertama didapat
  static const _defaultCenter = LatLng(-6.2088, 106.8456);
  // Titik GPS dengan akurasi lebih buruk dari ini tidak dimasukkan ke rute
  static const _maxAccuracyMeters = 25.0;
  static const _readError = "Gagal membaca lokasi. Menunggu sinyal GPS…";

  final _mapController = MapController();
  // Stopwatch memakai jam monotonic, jadi tetap akurat walau timer UI melambat saat layar mati
  final _stopwatch = Stopwatch();
  final List<TrackPoint> _points = [];

  late SportType _type = widget.initialType;
  _RecordState _state = _RecordState.ready;
  StreamSubscription<Position>? _positionSub;
  Timer? _ticker;
  DateTime? _startTime;
  double _distanceMeters = 0;
  int _segment = 0;
  LatLng? _current;
  double? _accuracy;
  bool _mapReady = false;
  bool _followUser = true;
  String? _error;
  // Dibuat saat mulai merekam, karena jenis olahraga bisa diganti sebelum itu
  KmAnnouncer? _announcer;
  DateTime _lastNotified = DateTime(0);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _ticker?.cancel();
    VoiceCoach.instance.stop();
    RecordingNotification.stop();
    super.dispose();
  }

  Future<void> _initLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() => _error = "GPS tidak aktif. Nyalakan layanan lokasi.");
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _error = "Izin lokasi ditolak.");
      return;
    }
    if (!mounted) return;

    _positionSub = Geolocator.getPositionStream(locationSettings: _locationSettings()).listen(
      _onPosition,
      onError: (Object e) {
        debugPrint('Gagal membaca lokasi: $e');
        if (mounted) setState(() => _error = _readError);
      },
    );
  }

  LocationSettings _locationSettings() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // GPS tetap jalan saat layar mati berkat foreground service dari RecordingNotification
        return AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 3,
          // Baca GPS langsung lewat LocationManager: rekaman olahraga memang butuh GPS satelit,
          // dan tetap jalan di perangkat tanpa Google Play Services
          forceLocationManager: true,
          intervalDuration: const Duration(seconds: 1),
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.best,
          activityType: ActivityType.fitness,
          distanceFilter: 3,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
        );
      default:
        return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3);
    }
  }

  void _onPosition(Position position) {
    final point = LatLng(position.latitude, position.longitude);
    setState(() {
      // Gangguan GPS sesaat tidak boleh mengunci tombol Mulai selamanya
      if (_error == _readError) _error = null;
      _current = point;
      _accuracy = position.accuracy;
      if (_state == _RecordState.recording && position.accuracy <= _maxAccuracyMeters) {
        // Jarak hanya dihitung dalam satu segmen, jadi perpindahan saat dijeda tidak ikut terhitung
        final now = _stopwatch.elapsedMilliseconds / 1000;
        if (_points.isNotEmpty && _points.last.segment == _segment) {
          final last = _points.last;
          final before = _distanceMeters;
          _distanceMeters += haversineMeters(last.lat, last.lng, point.latitude, point.longitude);
          _announceKilometers(before, last.t, now);
        }
        _points.add(TrackPoint(point.latitude, point.longitude, now, _segment));
      }
    });
    // Dibatasi supaya tidak kena batas frekuensi update notifikasi dari Android
    if (_state == _RecordState.recording && DateTime.now().difference(_lastNotified) >= const Duration(seconds: 3)) {
      _updateNotification();
    }
    if (_mapReady && _followUser) _mapController.move(point, _mapController.camera.zoom);
  }

  void _announceKilometers(double fromMeters, double fromSeconds, double toSeconds) {
    final texts = _announcer?.update(
          fromMeters: fromMeters,
          fromSeconds: fromSeconds,
          toMeters: _distanceMeters,
          toSeconds: toSeconds,
        ) ??
        const [];
    if (!SettingsService.instance.voiceCoach) return;
    for (final text in texts) {
      VoiceCoach.instance.speak(text);
    }
  }

  void _start() {
    _announcer = KmAnnouncer(_type);
    _startTime = DateTime.now();
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    setState(() => _state = _RecordState.recording);
    final (title, body) = _notificationText();
    RecordingNotification.start(title: title, body: body, elapsed: _stopwatch.elapsed);
  }

  void _pause() {
    _stopwatch.stop();
    setState(() => _state = _RecordState.paused);
    _updateNotification();
  }

  void _resume() {
    _stopwatch.start();
    _segment++;
    setState(() => _state = _RecordState.recording);
    _updateNotification();
  }

  void _finish() {
    _stopwatch.stop();
    _ticker?.cancel();
    _positionSub?.cancel();
    _positionSub = null;
    RecordingNotification.stop();

    final start = _startTime!;
    final draft = Activity(
      id: start.millisecondsSinceEpoch.toString(),
      type: _type,
      title: defaultTitle(_type, start),
      startTime: start,
      movingSeconds: _stopwatch.elapsed.inSeconds,
      distanceMeters: _distanceMeters,
      points: List.of(_points),
    );
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SaveActivityScreen(draft: draft)));
  }

  String get _paceText {
    final seconds = _stopwatch.elapsed.inSeconds;
    final km = _distanceMeters / 1000;
    return _type.showsSpeed
        ? formatSpeed(seconds == 0 ? 0 : km / (seconds / 3600))
        : formatPace(km < 0.01 ? null : seconds / km);
  }

  int get _kcal => _type.caloriesFor(
      meters: _distanceMeters, seconds: _stopwatch.elapsed.inSeconds, weightKg: ProfileService.instance.weightKg);

  (String, String) _notificationText() {
    final title = _state == _RecordState.paused
        ? "${_type.label} · Dijeda ${formatDuration(_stopwatch.elapsed.inSeconds)}"
        : "${_type.label} · Merekam";
    final pace = _type.showsSpeed ? "$_paceText km/j" : "Pace $_paceText /km";
    return (title, "${formatKm(_distanceMeters)} km · $pace · $_kcal kcal");
  }

  void _updateNotification() {
    _lastNotified = DateTime.now();
    final (title, body) = _notificationText();
    RecordingNotification.update(
      title: title,
      body: body,
      running: _state == _RecordState.recording,
      elapsed: _stopwatch.elapsed,
    );
  }

  Future<void> _confirmDiscard() async {
    final discard = await showConfirmDialog(
      context,
      title: "Buang aktivitas?",
      message: "Rekaman aktivitas ini akan dihapus dan tidak bisa dikembalikan.",
      confirmLabel: "Buang",
      icon: Icons.delete_outline,
    );
    if (discard && mounted) Navigator.pop(context);
  }

  void _pickSport() {
    showModalBottomSheet(
      context: context,
            builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("Pilih Jenis Olahraga", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final type in SportType.values)
              ListTile(
                leading: Icon(type.icon),
                title: Text(type.label),
                trailing: type == _type ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
                onTap: () {
                  setState(() => _type = type);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _recenter() {
    setState(() => _followUser = true);
    final pos = _current;
    if (pos != null && _mapReady) _mapController.move(pos, 17);
  }

  List<List<LatLng>> get _segments {
    final segments = <List<LatLng>>[];
    for (var i = 0; i < _points.length; i++) {
      if (i == 0 || _points[i].segment != _points[i - 1].segment) segments.add([]);
      segments.last.add(LatLng(_points[i].lat, _points[i].lng));
    }
    return segments;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: _state == _RecordState.ready,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _current ?? _defaultCenter,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                initialZoom: 17,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onMapReady: () {
                  _mapReady = true;
                  if (_current != null) _mapController.move(_current!, 17);
                },
                // Berhenti mengikuti posisi saat pengguna menggeser peta sendiri
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture && _followUser) setState(() => _followUser = false);
                },
              ),
              children: [
                osmTileLayer(context),
                PolylineLayer(
                  polylines: [
                    for (final seg in _segments)
                      Polyline(points: seg, color: scheme.primary, strokeWidth: 5, borderColor: scheme.onPrimary, borderStrokeWidth: 1.5),
                  ],
                ),
                if (_current != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _current!,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.onPrimary, width: 3),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.surface,
                      child: IconButton(
                        icon: Icon(Icons.close, color: scheme.onSurface),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                    ),
                    const Spacer(),
                    _buildSportChip(),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildGpsIndicator(),
                        const SizedBox(height: 8),
                        CircleAvatar(
                          backgroundColor: scheme.surface,
                          child: IconButton(
                            icon: Icon(_followUser ? Icons.my_location : Icons.location_searching, color: scheme.onSurface),
                            onPressed: _recenter,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListenableBuilder(
                          listenable: SettingsService.instance,
                          builder: (context, _) {
                            final on = SettingsService.instance.voiceCoach;
                            return CircleAvatar(
                              backgroundColor: scheme.surface,
                              child: IconButton(
                                tooltip: on ? "Matikan suara tiap km" : "Nyalakan suara tiap km",
                                icon: Icon(on ? Icons.volume_up : Icons.volume_off, color: scheme.onSurface),
                                onPressed: () {
                                  SettingsService.instance.setVoiceCoach(!on);
                                  if (on) VoiceCoach.instance.stop();
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        const OsmAttribution(),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (_error != null)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 72, left: 16, right: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.danger, borderRadius: BorderRadius.circular(12)),
                    child: Text(_error!, style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),

            Align(alignment: Alignment.bottomCenter, child: _buildStatsPanel(scheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildSportChip() {
    final ready = _state == _RecordState.ready;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: ready ? _pickSport : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_type.icon, size: 18, color: scheme.onSurface),
              const SizedBox(width: 6),
              Text(_type.label.toUpperCase(), style: AppTheme.display(16, color: scheme.onSurface, letterSpacing: 1.5)),
              if (ready) Icon(Icons.arrow_drop_down, color: scheme.onSurface),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGpsIndicator() {
    final (label, color) = switch (_accuracy) {
      null => ("Mencari GPS…", Theme.of(context).colorScheme.onSurfaceVariant),
      final a when a <= _maxAccuracyMeters => ("GPS siap", AppTheme.success),
      _ => ("GPS lemah", AppTheme.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildStatsPanel(ColorScheme scheme) {
    final seconds = _stopwatch.elapsed.inSeconds;
    final paceStat = _buildMiniStat(_paceText, _type.showsSpeed ? "km/j" : "Pace /km");

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_state == _RecordState.paused)
              Text("DIJEDA", style: AppTheme.display(16, color: scheme.onSurfaceVariant, letterSpacing: 4)),
            Text(formatDuration(seconds), style: AppTheme.display(72)),
            Text("WAKTU", style: AppTheme.display(14, color: scheme.onSurfaceVariant, letterSpacing: 3)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat(formatKm(_distanceMeters), "KM"),
                paceStat,
                _buildMiniStat("$_kcal", "Kcal"),
              ],
            ),
            const SizedBox(height: 24),
            _buildControls(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(ColorScheme scheme) {
    final label = AppTheme.display(18, color: scheme.onPrimary, letterSpacing: 2);
    switch (_state) {
      case _RecordState.ready:
        return _roundButton(
          scheme: scheme,
          onTap: _error == null ? _start : null,
          child: Text("MULAI", style: label),
        );
      case _RecordState.recording:
        return _roundButton(
          scheme: scheme,
          onTap: _pause,
          child: Icon(Icons.pause, color: scheme.onPrimary, size: 40),
        );
      case _RecordState.paused:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _roundButton(scheme: scheme, onTap: _resume, child: Text("LANJUT", style: label)),
            _roundButton(
              scheme: scheme,
              outlined: true,
              onTap: _finish,
              child: Text("SELESAI", style: label.copyWith(color: scheme.primary)),
            ),
          ],
        );
    }
  }

  Widget _roundButton({required ColorScheme scheme, required Widget child, VoidCallback? onTap, bool outlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 88,
        width: 88,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : (onTap == null ? scheme.onSurfaceVariant : scheme.primary),
          shape: BoxShape.circle,
          border: outlined ? Border.all(color: scheme.primary, width: 2.5) : null,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _buildMiniStat(String val, String label) {
    return Column(
      children: [
        Text(val, style: AppTheme.display(30)),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
