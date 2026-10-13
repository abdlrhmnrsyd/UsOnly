import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/domain/auth_state.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../media/presentation/app_image_view.dart';
import '../../notifications/data/notifications_repository.dart';
import '../data/location_repository.dart';
import '../domain/location_model.dart';

enum MapStyleType {
  googleRoadmap(
    'Google Maps (Jalan)',
    'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
    ['0', '1', '2', '3'],
  ),
  googleSatellite(
    'Google Maps (Satelit)',
    'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
    ['0', '1', '2', '3'],
  ),
  googleTerrain(
    'Google Maps (Medan)',
    'https://mt{s}.google.com/vt/lyrs=p&x={x}&y={y}&z={z}',
    ['0', '1', '2', '3'],
  ),
  cartoVoyager(
    'Carto Clean Style',
    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
    ['a', 'b', 'c', 'd'],
  ),
  cartoDark(
    'Find Hub (Mode Gelap)',
    'https://{s}.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png',
    ['a', 'b', 'c', 'd'],
  ),
  osm(
    'OpenStreetMap',
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    [],
  );

  final String label;
  final String urlTemplate;
  final List<String> subdomains;
  const MapStyleType(this.label, this.urlTemplate, this.subdomains);
}

class LocationTrackingScreen extends ConsumerStatefulWidget {
  const LocationTrackingScreen({super.key});

  @override
  ConsumerState<LocationTrackingScreen> createState() => _LocationTrackingScreenState();
}

class _LocationTrackingScreenState extends ConsumerState<LocationTrackingScreen>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  MapStyleType _selectedMapStyle = MapStyleType.googleRoadmap;

  String _selectedStatus = 'Di Rumah 🏡';
  bool _isPanelExpanded = true;
  LatLng? _lastAutoCenteredPoint;

  final List<String> _statusOptions = [
    'Di Rumah 🏡',
    'Di Kampus/Kantor 🏢',
    'Sedang di Jalan 🚗',
    'Lagi Santai ☕',
    'Lagi Belanja 🛍️',
    'Lagi Bareng Kamu 💕',
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleLiveSharing(bool enable) async {
    final user = ref.read(authStateProvider).user;
    if (user == null || user.coupleId == null) return;

    final repo = ref.read(locationRepositoryProvider);
    setState(() {});

    try {
      if (enable) {
        await repo.startLiveSharing(
          coupleId: user.coupleId!,
          uid: user.uid,
          displayName: user.displayName,
          photoUrl: user.photoUrl,
          placeLabel: _selectedStatus,
        );

        try {
          await ref.read(notificationsRepositoryProvider).sendNotification(
                coupleId: user.coupleId!,
                senderUid: user.uid,
                senderName: user.displayName,
                title: '📍 ${user.displayName} menyalakan Live Location!',
                body: 'Buka Find Hub untuk melihat pergerakannya secara realtime di peta.',
                type: 'location',
              );
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🟢 Live Location Aktif! Posisi otomatis terkirim.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await repo.stopLiveSharing(
          coupleId: user.coupleId!,
          uid: user.uid,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚪ Live Location Dimatikan.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling live location: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _openNavigation(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat membuka Google Maps: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _shareToChat(LocationModel myLoc) async {
    final user = ref.read(authStateProvider).user;
    if (user == null || user.coupleId == null) return;

    try {
      final convId = 'conv_${user.coupleId}';
      await ref.read(chatRepositoryProvider).sendLocationMessage(
            conversationId: convId,
            senderUid: user.uid,
            latitude: myLoc.latitude,
            longitude: myLoc.longitude,
            placeLabel: myLoc.placeLabel ?? _selectedStatus,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi dibagikan ke Chat! 💬'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim ke chat: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pingPartnerForLocation() async {
    final user = ref.read(authStateProvider).user;
    if (user == null || user.coupleId == null) return;

    await ref.read(notificationsRepositoryProvider).sendNotification(
          coupleId: user.coupleId!,
          senderUid: user.uid,
          senderName: user.displayName,
          title: '📍 Nyalakan Live Location dong!',
          body: '${user.displayName} ingin melihat lokasimu di Find Hub.',
          type: 'location',
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permintaan live location dikirim ke pasangan! 🔔'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _centerOnLocation(LatLng point, {double zoom = 16.0}) {
    try {
      _mapController.move(point, zoom);
    } catch (e) {
      debugPrint('Map move error: $e');
    }
  }

  void _fitBothLocations(LatLng p1, LatLng p2) {
    try {
      final bounds = LatLngBounds.fromPoints([p1, p2]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(left: 60, right: 60, top: 120, bottom: 280),
          maxZoom: 16.5,
        ),
      );
    } catch (_) {
      _centerOnLocation(p1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null || user.coupleId == null) {
      return const Scaffold(
        body: Center(child: Text('Silakan hubungkan pasangan terlebih dahulu.')),
      );
    }

    final coupleId = user.coupleId!;
    final repo = ref.watch(locationRepositoryProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: StreamBuilder<Map<String, LocationModel>>(
        stream: repo.watchCoupleLocations(coupleId),
        builder: (context, snapshot) {
          final locs = snapshot.data ?? {};
          final myLoc = locs[user.uid];
          final partnerEntry = locs.entries.where((e) => e.key != user.uid);
          final partnerLoc = partnerEntry.isNotEmpty ? partnerEntry.first.value : null;

          final isMyLiveActive = (myLoc?.isLive == true) || repo.isLiveSharing;
          final isPartnerLive = partnerLoc?.isLive ?? false;

          // LatLng coords with sensible fallbacks
          final myLatLng = (myLoc != null && myLoc.latitude != 0.0 && myLoc.longitude != 0.0)
              ? LatLng(myLoc.latitude, myLoc.longitude)
              : const LatLng(-6.2088, 106.8456); // Jakarta Pusat fallback

          // If partner has no location yet, create a simulated nearby demonstration point
          final partnerLatLng = (partnerLoc != null && partnerLoc.latitude != 0.0 && partnerLoc.longitude != 0.0)
              ? LatLng(partnerLoc.latitude, partnerLoc.longitude)
              : LatLng(myLatLng.latitude + 0.0055, myLatLng.longitude + 0.0072); // ~900m away

          final partnerDisplayName = partnerLoc?.displayName ?? 'Pasangan Kamu';
          final partnerPhotoUrl = partnerLoc?.photoUrl;
          final partnerBattery = partnerLoc?.batteryLevel ?? 88;
          final partnerPlace = partnerLoc?.placeLabel ?? 'Di Rumah 🏡';

          // Distance calculation & estimated travel time
          final distanceMeters = const Distance().as(LengthUnit.Meter, myLatLng, partnerLatLng);
          final String distanceString = distanceMeters < 50
              ? 'Kalian sedang bersama 💕'
              : distanceMeters < 1000
                  ? '${distanceMeters.round()} m dari kamu'
                  : '${(distanceMeters / 1000).toStringAsFixed(1)} km dari kamu';
          final int carMinutes = (distanceMeters / 450).ceil().clamp(1, 999);
          final int walkMinutes = (distanceMeters / 75).ceil().clamp(1, 999);

          // Auto-center camera when a new coordinate arrives or on initial load
          if (_lastAutoCenteredPoint == null ||
              (_lastAutoCenteredPoint!.latitude - myLatLng.latitude).abs() > 0.005 ||
              (_lastAutoCenteredPoint!.longitude - myLatLng.longitude).abs() > 0.005) {
            _lastAutoCenteredPoint = myLatLng;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitBothLocations(myLatLng, partnerLatLng);
            });
          }

          // Midpoint for distance pill badge
          final midPoint = LatLng(
            (myLatLng.latitude + partnerLatLng.latitude) / 2,
            (myLatLng.longitude + partnerLatLng.longitude) / 2,
          );

          return Stack(
            children: [
              // 0. MAP VECTOR CANVAS (Realistic Google Maps Terrain & Road Network)
              Positioned.fill(
                child: CustomPaint(
                  painter: GoogleMapsCanvasPainter(isDark: isDark),
                ),
              ),

              // 1. FULLSCREEN INTERACTIVE MAP (Google Maps / Find Hub Style)
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: myLatLng,
                    initialZoom: 15.0,
                    minZoom: 3.0,
                    maxZoom: 19.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    // Dynamic Map Tile Provider (OSM / Voyager / Dark)
                    TileLayer(
                      urlTemplate: _selectedMapStyle.urlTemplate,
                      userAgentPackageName: 'com.usonly.app',
                      subdomains: _selectedMapStyle.subdomains,
                      maxZoom: 20,
                    ),

                    // Accuracy & Radar Range Circles
                    CircleLayer(
                      circles: [
                        // User accuracy halo
                        CircleMarker(
                          point: myLatLng,
                          radius: 40,
                          useRadiusInMeter: false,
                          color: const Color(0xFF2EC4B6).withValues(alpha: 0.15),
                          borderColor: const Color(0xFF2EC4B6).withValues(alpha: 0.6),
                          borderStrokeWidth: 1.5,
                        ),
                        // Partner live pulsing halo
                        if (isPartnerLive)
                          CircleMarker(
                            point: partnerLatLng,
                            radius: 50,
                            useRadiusInMeter: false,
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderColor: AppColors.primary.withValues(alpha: 0.6),
                            borderStrokeWidth: 1.5,
                          ),
                      ],
                    ),

                    // Connecting Line between Couple
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [myLatLng, partnerLatLng],
                          strokeWidth: 3.5,
                          color: AppColors.primary.withValues(alpha: 0.8),
                          borderStrokeWidth: 1.5,
                          borderColor: Colors.white.withValues(alpha: 0.8),
                          strokeCap: StrokeCap.round,
                        ),
                      ],
                    ),

                    // Custom Interactive Map Markers
                    MarkerLayer(
                      markers: [
                        // Midpoint Distance Pill
                        Marker(
                          point: midPoint,
                          width: 140,
                          height: 38,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.favorite_rounded, color: Colors.white, size: 13),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      distanceString,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // My Avatar Marker ("Kamu")
                        Marker(
                          point: myLatLng,
                          width: 90,
                          height: 105,
                          child: GestureDetector(
                            onTap: () => _centerOnLocation(myLatLng),
                            child: _buildGoogleStyleMarker(
                              name: 'Kamu',
                              photoUrl: user.photoUrl,
                              isMe: true,
                              isLive: isMyLiveActive,
                              statusText: myLoc?.placeLabel ?? _selectedStatus,
                            ),
                          ),
                        ),

                        // Partner Avatar Marker (Find Hub Style)
                        Marker(
                          point: partnerLatLng,
                          width: 100,
                          height: 115,
                          child: GestureDetector(
                            onTap: () {
                              _centerOnLocation(partnerLatLng);
                              setState(() => _isPanelExpanded = true);
                            },
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return _buildGoogleStyleMarker(
                                  name: partnerDisplayName,
                                  photoUrl: partnerPhotoUrl,
                                  isMe: false,
                                  isLive: isPartnerLive,
                                  batteryLevel: partnerBattery,
                                  statusText: partnerPlace,
                                  pulseValue: isPartnerLive ? _pulseController.value : 0.0,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. FLOATING TOP BAR (Google Maps / Find Hub Style)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        // Back Button
                        _buildGlassCircleButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          tooltip: 'Kembali',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 10),

                        // Title & Live Status Chip Pill
                        Expanded(
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.surfaceDark : Colors.white).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: (isDark ? Colors.white12 : Colors.black12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (isMyLiveActive || isPartnerLive)
                                        ? AppColors.success
                                        : Colors.grey,
                                    boxShadow: (isMyLiveActive || isPartnerLive)
                                        ? [
                                            BoxShadow(
                                              color: AppColors.success.withValues(alpha: 0.6),
                                              blurRadius: 6,
                                              spreadRadius: 2,
                                            )
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Find Hub • Live Tracking',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                      Text(
                                        isMyLiveActive
                                            ? '🟢 Live streaming aktif'
                                            : '⚪ Berbagi lokasi standby',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMyLiveActive ? AppColors.success : Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Map Style Layer Switcher Popup
                        PopupMenuButton<MapStyleType>(
                          tooltip: 'Pilih Gaya Peta',
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          icon: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isDark ? AppColors.surfaceDark : Colors.white).withValues(alpha: 0.9),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.layers_rounded, size: 20),
                          ),
                          onSelected: (style) {
                            setState(() => _selectedMapStyle = style);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: MapStyleType.googleRoadmap,
                              child: Row(
                                children: [
                                  Icon(Icons.map_rounded, size: 18, color: Color(0xFF4285F4)),
                                  SizedBox(width: 10),
                                  Text('Google Maps (Jalan)'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: MapStyleType.googleSatellite,
                              child: Row(
                                children: [
                                  Icon(Icons.satellite_alt_rounded, size: 18, color: Color(0xFF34A853)),
                                  SizedBox(width: 10),
                                  Text('Google Maps (Satelit)'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: MapStyleType.googleTerrain,
                              child: Row(
                                children: [
                                  Icon(Icons.terrain_rounded, size: 18, color: Color(0xFFFBBC05)),
                                  SizedBox(width: 10),
                                  Text('Google Maps (Medan)'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: MapStyleType.cartoDark,
                              child: Row(
                                children: [
                                  Icon(Icons.dark_mode_rounded, size: 18, color: Colors.indigoAccent),
                                  SizedBox(width: 10),
                                  Text('Find Hub (Mode Gelap)'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: MapStyleType.cartoVoyager,
                              child: Row(
                                children: [
                                  Icon(Icons.wb_sunny_rounded, size: 18, color: AppColors.primary),
                                  SizedBox(width: 10),
                                  Text('Carto Clean'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. FLOATING MAP ACTION BUTTONS (Right Side Google Maps Style, floats right above bottom sheet)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                right: 16,
                bottom: _isPanelExpanded ? 340 : 120,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fit Both (Lihat Berdua)
                    _buildFloatingMapButton(
                      icon: Icons.zoom_out_map_rounded,
                      iconColor: isDark ? Colors.white : Colors.black87,
                      tooltip: 'Lihat Berdua di Peta',
                      onTap: () => _fitBothLocations(myLatLng, partnerLatLng),
                    ),
                    const SizedBox(height: 8),

                    // Recenter to Partner (Focus Doi)
                    _buildFloatingMapButton(
                      icon: Icons.favorite_rounded,
                      iconColor: AppColors.primary,
                      tooltip: 'Fokus ke Doi',
                      onTap: () => _centerOnLocation(partnerLatLng, zoom: 16.5),
                    ),
                    const SizedBox(height: 8),

                    // Recenter to Me (Focus Kamu)
                    _buildFloatingMapButton(
                      icon: Icons.my_location_rounded,
                      iconColor: const Color(0xFF2EC4B6),
                      tooltip: 'Fokus ke Saya',
                      onTap: () => _centerOnLocation(myLatLng, zoom: 16.5),
                    ),
                    const SizedBox(height: 8),

                    // Zoom In & Out Connected Pill
                    Container(
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.surfaceDark : Colors.white).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              try {
                                _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                              } catch (_) {}
                            },
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Icon(Icons.add_rounded, size: 20),
                            ),
                          ),
                          Container(width: 22, height: 1, color: isDark ? Colors.white12 : Colors.black12),
                          InkWell(
                            onTap: () {
                              try {
                                _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                              } catch (_) {}
                            },
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Icon(Icons.remove_rounded, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 4. BOTTOM FLOATING CARD / BOTTOM SHEET (Find Hub Style)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 28,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Grabber Handle
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _isPanelExpanded = !_isPanelExpanded),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(top: 10, bottom: 6),
                            child: Center(
                              child: Container(
                                width: 42,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Partner Header Row (Tap to expand / collapse)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _isPanelExpanded = !_isPanelExpanded),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                            child: Row(
                              children: [
                                // Avatar with Live Indicator
                                Stack(
                                  children: [
                                    AppAvatar(
                                      photoUrl: partnerPhotoUrl,
                                      name: partnerDisplayName,
                                      radius: 26,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: isPartnerLive ? AppColors.success : Colors.grey,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(Icons.favorite, size: 8, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),

                                // Name & Distance
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            partnerDisplayName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (isPartnerLive)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.success,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Text(
                                                'LIVE',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$distanceString • $partnerPlace',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Wrap(
                                        spacing: 6,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '🚗 ~$carMinutes mnt',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '🚶 ~$walkMinutes mnt',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isPartnerLive
                                            ? '🟢 Sedang berbagi live lokasi realtime'
                                            : (partnerLoc != null
                                                ? 'Terakhir diperbarui ${DateFormat('HH:mm').format(partnerLoc.updatedAt)}'
                                                : 'Belum memperbarui lokasi hari ini'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isPartnerLive ? AppColors.success : Colors.grey,
                                          fontWeight: isPartnerLive ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Battery Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.battery_charging_full_rounded, size: 14, color: AppColors.success),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$partnerBattery%',
                                        style: const TextStyle(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _isPanelExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Expandable Controls Section
                        if (_isPanelExpanded) ...[
                          const SizedBox(height: 10),

                          // 1-TAP LIVE SHARING MASTER TOGGLE
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isMyLiveActive
                                      ? [
                                          const Color(0xFF163E2B),
                                          isDark ? AppColors.surfaceDark : const Color(0xFFE8F7EE)
                                        ]
                                      : [
                                          isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                                          isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isMyLiveActive ? AppColors.success : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isMyLiveActive ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                                    color: isMyLiveActive ? AppColors.success : Colors.grey,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Bagikan Live Lokasi Saya',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                          ),
                                        ),
                                        Text(
                                          isMyLiveActive
                                              ? 'GPS streaming live aktif otomatis'
                                              : 'Nyalakan agar pasangan bisa tracking kamu',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: isMyLiveActive,
                                    activeTrackColor: AppColors.success,
                                    onChanged: (val) => _toggleLiveSharing(val),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Quick Action Row (Find Hub / Google Maps Style)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                // Google Maps Route Navigation
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      elevation: 2,
                                    ),
                                    onPressed: () => _openNavigation(partnerLatLng.latitude, partnerLatLng.longitude),
                                    icon: const Icon(Icons.directions_car_rounded, size: 18),
                                    label: const Text(
                                      'Petunjuk Arah',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Ping Partner Notification
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: IconButton(
                                    tooltip: 'Ping Doi',
                                    icon: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                                    onPressed: _pingPartnerForLocation,
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Share Snapshot to Chat
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: IconButton(
                                    tooltip: 'Bagi ke Chat',
                                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
                                    onPressed: () {
                                      if (myLoc != null) {
                                        _shareToChat(myLoc);
                                      } else {
                                        repo
                                            .updateLocation(
                                          coupleId: coupleId,
                                          uid: user.uid,
                                          displayName: user.displayName,
                                          photoUrl: user.photoUrl,
                                          placeLabel: _selectedStatus,
                                        )
                                            .then((updated) {
                                          if (updated != null) _shareToChat(updated);
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Activity Status Selector Chips
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              height: 34,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _statusOptions.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 6),
                                itemBuilder: (context, idx) {
                                  final status = _statusOptions[idx];
                                  final isSelected = _selectedStatus == status;
                                  return ChoiceChip(
                                    label: Text(status),
                                    selected: isSelected,
                                    selectedColor: AppColors.primaryLight,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    labelStyle: TextStyle(
                                      color: isSelected ? AppColors.primary : null,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 11,
                                    ),
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() => _selectedStatus = status);
                                        if (isMyLiveActive) {
                                          repo.updateLocation(
                                            coupleId: coupleId,
                                            uid: user.uid,
                                            displayName: user.displayName,
                                            photoUrl: user.photoUrl,
                                            placeLabel: status,
                                            isLive: true,
                                          );
                                        }
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Glassmorphic circular button for top bar
  Widget _buildGlassCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isDark ? AppColors.surfaceDark : Colors.white).withValues(alpha: 0.9),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }

  /// Floating map tool buttons on the right side
  Widget _buildFloatingMapButton({
    required IconData icon,
    Color? iconColor,
    required String tooltip,
    required VoidCallback onTap,
    bool mini = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = mini ? 38.0 : 44.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: (isDark ? AppColors.surfaceDark : Colors.white).withValues(alpha: 0.95),
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black38,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: mini ? 18 : 22, color: iconColor),
          ),
        ),
      ),
    );
  }

  /// Google Maps / Find Hub Pin with Avatar, Pulsing Halo & Battery Badge
  Widget _buildGoogleStyleMarker({
    required String name,
    required String? photoUrl,
    required bool isMe,
    required bool isLive,
    int? batteryLevel,
    required String statusText,
    double pulseValue = 0.0,
  }) {
    final mainColor = isMe ? const Color(0xFF2EC4B6) : AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Pulsing live beacon wave
            if (isLive && pulseValue > 0.0)
              Transform.scale(
                scale: 1.0 + (pulseValue * 0.45),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: mainColor.withValues(alpha: (1.0 - pulseValue) * 0.4),
                  ),
                ),
              ),

            // Drop pin wrapper
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: isLive ? AppColors.success : mainColor,
                  width: 3.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? AppImageView(imageUrl: photoUrl, fit: BoxFit.cover)
                    : Container(
                        color: isMe ? const Color(0xFF2EC4B6) : AppColors.primaryLight,
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: isMe ? Colors.white : AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
              ),
            ),

            // Battery Badge (top right of avatar)
            if (batteryLevel != null)
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '$batteryLevel%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Bottom pin pointer triangle
            Positioned(
              bottom: -5,
              child: CustomPaint(
                size: const Size(10, 6),
                painter: _PinTrianglePainter(color: isLive ? AppColors.success : mainColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),

        // Name & Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Text(
            isLive ? '🟢 $name' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _PinTrianglePainter extends CustomPainter {
  final Color color;
  _PinTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTrianglePainter oldDelegate) => oldDelegate.color != color;
}

class GoogleMapsCanvasPainter extends CustomPainter {
  final bool isDark;
  GoogleMapsCanvasPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Terrain Base Background
    final bgPaint = Paint()..color = isDark ? const Color(0xFF1E242B) : const Color(0xFFF2EFE9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. City Water Body (Curved river / lake bay)
    final waterPaint = Paint()..color = isDark ? const Color(0xFF162D3D) : const Color(0xFFAADAFF);
    final riverPath = Path()
      ..moveTo(-20, size.height * 0.35)
      ..cubicTo(size.width * 0.3, size.height * 0.28, size.width * 0.6, size.height * 0.55, size.width + 20, size.height * 0.48)
      ..lineTo(size.width + 20, size.height * 0.56)
      ..cubicTo(size.width * 0.6, size.height * 0.63, size.width * 0.3, size.height * 0.36, -20, size.height * 0.43)
      ..close();
    canvas.drawPath(riverPath, waterPaint);

    // 3. Green Park Zones (Urban nature parks)
    final parkPaint = Paint()..color = isDark ? const Color(0xFF223528) : const Color(0xFFD5E8D4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.08, size.height * 0.12, 140, 90), const Radius.circular(16)),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.62, size.height * 0.68, 120, 80), const Radius.circular(16)),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.55, size.height * 0.18, 90, 70), const Radius.circular(14)),
      parkPaint,
    );

    // 4. City Street Grid Network (Google Maps Arterial & Secondary Roads)
    final secondaryRoadPaint = Paint()
      ..color = (isDark ? Colors.white12 : Colors.white)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final roadBorderPaint = Paint()
      ..color = (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFDCD8CF))
      ..strokeWidth = 5.5
      ..style = PaintingStyle.stroke;

    final arterialRoadPaint = Paint()
      ..color = (isDark ? const Color(0xFF384350) : const Color(0xFFFFF7D6))
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;

    final arterialBorderPaint = Paint()
      ..color = (isDark ? Colors.white24 : const Color(0xFFE8DEB5))
      ..strokeWidth = 8.5
      ..style = PaintingStyle.stroke;

    // Draw secondary grid streets
    for (double y = 60; y < size.height; y += 75) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadBorderPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), secondaryRoadPaint);
    }
    for (double x = 40; x < size.width; x += 85) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadBorderPaint);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), secondaryRoadPaint);
    }

    // Draw primary diagonal & cross highways
    final highway1 = Path()..moveTo(0, size.height * 0.25)..lineTo(size.width, size.height * 0.75);
    final highway2 = Path()..moveTo(size.width * 0.45, 0)..lineTo(size.width * 0.52, size.height);
    canvas.drawPath(highway1, arterialBorderPaint);
    canvas.drawPath(highway1, arterialRoadPaint);
    canvas.drawPath(highway2, arterialBorderPaint);
    canvas.drawPath(highway2, arterialRoadPaint);
  }

  @override
  bool shouldRepaint(covariant GoogleMapsCanvasPainter oldDelegate) => oldDelegate.isDark != isDark;
}
