import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app/theme/app_colors.dart';
import 'builtin_media_picker_sheet.dart';

class BuiltinCameraScreen extends StatefulWidget {
  final bool isPapMode;
  final Function(File file, String? caption, String type) onMediaSelected;

  const BuiltinCameraScreen({
    super.key,
    this.isPapMode = true,
    required this.onMediaSelected,
  });

  @override
  State<BuiltinCameraScreen> createState() => _BuiltinCameraScreenState();
}

class _BuiltinCameraScreenState extends State<BuiltinCameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  bool _isInitializing = true;
  bool _isTakingPhoto = false;
  File? _capturedFile;

  // Recent images for the WhatsApp bottom strip
  List<File> _recentFiles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _loadRecentGalleryPhotos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController(_cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // If PAP mode, prefer front camera for selfies/PAP, else back camera
        int preferredIndex = 0;
        if (widget.isPapMode) {
          final frontIdx = _cameras.indexWhere(
              (c) => c.lensDirection == CameraLensDirection.front);
          if (frontIdx != -1) preferredIndex = frontIdx;
        }

        _selectedCameraIndex = preferredIndex;
        await _initCameraController(_cameras[_selectedCameraIndex]);
      } else {
        if (mounted) setState(() => _isInitializing = false);
      }
    } catch (e) {
      debugPrint('Camera availability notice: $e');
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _initCameraController(CameraDescription camera) async {
    final prevController = _controller;
    await prevController?.dispose();

    final newController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _controller = newController;

    try {
      await newController.initialize();
      await newController.setFlashMode(_flashMode);
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      debugPrint('Camera controller init notice: $e');
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _isInitializing = true);
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _cycleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final modes = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final nextIndex = (modes.indexOf(_flashMode) + 1) % modes.length;
    final nextMode = modes[nextIndex];
    try {
      await _controller!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } catch (e) {
      debugPrint('Flash mode error: $e');
    }
  }

  Future<void> _takePhoto() async {
    if (_isTakingPhoto) return;

    if (_controller != null && _controller!.value.isInitialized) {
      try {
        setState(() => _isTakingPhoto = true);
        final xFile = await _controller!.takePicture();
        final file = File(xFile.path);
        setState(() {
          _capturedFile = file;
          _isTakingPhoto = false;
        });
      } catch (e) {
        setState(() => _isTakingPhoto = false);
        debugPrint('Take picture error: $e');
        _fallbackCreatePhoto();
      }
    } else {
      // Fallback for emulator without hardware camera
      _fallbackCreatePhoto();
    }
  }

  Future<void> _fallbackCreatePhoto() async {
    setState(() => _isTakingPhoto = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final sampleFile = File(
          '${tempDir.path}/pap_snap_${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Check if any recent file exists to use as mock, or generate a JPEG
      if (_recentFiles.isNotEmpty) {
        setState(() {
          _capturedFile = _recentFiles.first;
          _isTakingPhoto = false;
        });
        return;
      }

      // Generate a solid color JPEG bytes
      final bytes = <int>[
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x01, 0x00, 0x60, 0x00, 0x60, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
        0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
        0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
        0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
        0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
        0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
        0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x10,
        0x00, 0x10, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
        0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F,
        0x00, 0x7F, 0x00, 0xFF, 0xD9
      ];
      await sampleFile.writeAsBytes(bytes);

      setState(() {
        _capturedFile = sampleFile;
        _isTakingPhoto = false;
      });
    } catch (e) {
      setState(() => _isTakingPhoto = false);
    }
  }

  Future<void> _loadRecentGalleryPhotos() async {
    try {
      final List<String> searchPaths = [
        '/storage/emulated/0/DCIM/Camera',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Download',
        (await getTemporaryDirectory()).path,
        (await getApplicationDocumentsDirectory()).path,
      ];

      final found = <File>[];
      for (final p in searchPaths) {
        final dir = Directory(p);
        if (await dir.exists()) {
          final list = dir.listSync();
          for (final entity in list) {
            if (entity is File) {
              final ext = entity.path.toLowerCase();
              if (ext.endsWith('.jpg') ||
                  ext.endsWith('.jpeg') ||
                  ext.endsWith('.png') ||
                  ext.endsWith('.webp')) {
                found.add(entity);
                if (found.length >= 15) break;
              }
            }
          }
        }
        if (found.length >= 15) break;
      }

      if (mounted) setState(() => _recentFiles = found);
    } catch (e) {
      debugPrint('Scan recent gallery notice: $e');
    }
  }

  void _openInAppGallery() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BuiltinMediaPickerSheet(
        onMediaPicked: (file) {
          Navigator.pop(ctx);
          setState(() => _capturedFile = file);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedFile != null) {
      return _buildWhatsAppEditor(_capturedFile!);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Viewfinder
            Positioned.fill(
              child: (_controller != null && _controller!.value.isInitialized)
                  ? CameraPreview(_controller!)
                  : (_isInitializing
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      : _buildSimulatorViewfinder()),
            ),

            // Top Control Bar (Flash, Close, Mode)
            Positioned(
              top: 10,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isPapMode ? Icons.favorite_rounded : Icons.camera_alt_rounded,
                          color: AppColors.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isPapMode ? 'PAP KILAT' : 'KAMERA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_getFlashIcon(), color: Colors.white, size: 26),
                    onPressed: _cycleFlash,
                  ),
                ],
              ),
            ),

            // Bottom Area: Recent Strip + Shutter + Flip + Gallery (WhatsApp style)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Horizontal Recent Photos Strip (WhatsApp style)
                    if (_recentFiles.isNotEmpty) ...[
                      SizedBox(
                        height: 56,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _recentFiles.length,
                          itemBuilder: (context, index) {
                            final file = _recentFiles[index];
                            return GestureDetector(
                              onTap: () => setState(() => _capturedFile = file),
                              child: Container(
                                width: 56,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white38),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.file(file, fit: BoxFit.cover),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Control Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Gallery Button
                          IconButton(
                            icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 30),
                            onPressed: _openInAppGallery,
                          ),

                          // Large Shutter Button (WhatsApp style)
                          GestureDetector(
                            onTap: _takePhoto,
                            child: Container(
                              width: 76,
                              height: 76,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3.5),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.isPapMode ? AppColors.primary : Colors.white,
                                ),
                                child: _isTakingPhoto
                                    ? const Center(
                                        child: SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),

                          // Camera Switch Button (Flip)
                          IconButton(
                            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 30),
                            onPressed: _toggleCamera,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.always:
        return Icons.flash_on_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      default:
        return Icons.flash_off_rounded;
    }
  }

  Widget _buildSimulatorViewfinder() {
    return Container(
      color: const Color(0xFF141216),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Focus brackets
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined, size: 54, color: AppColors.primary.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              const Text(
                'Viewfinder Kamera Aktif',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sentuh tombol shutter untuk ambil foto',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// WhatsApp-Style Photo Editor & Caption Screen
  Widget _buildWhatsAppEditor(File file) {
    final captionController = TextEditingController();
    String selectedMood = widget.isPapMode ? 'Lagi kangen kamu ❤️' : '';

    final moods = [
      'Lagi kangen kamu ❤️',
      'Lagi santai nih ☕',
      'Lagi kerja/belajar 💻',
      'Lagi di jalan 🚗',
      'Lagi makan 🍕',
      'Mau tidur 😴',
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StatefulBuilder(
          builder: (context, setEditorState) {
            return Column(
              children: [
                // Top Action Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                        onPressed: () => setState(() => _capturedFile = null),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          'US ONLY • ${DateFormat('HH:mm').format(DateTime.now())}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.crop_rotate_rounded, color: Colors.white, size: 24),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                // Image Preview Frame
                Expanded(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // Bottom Mood Tags (if PAP mode)
                if (widget.isPapMode)
                  Container(
                    height: 44,
                    margin: const EdgeInsets.only(top: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: moods.length,
                      itemBuilder: (context, index) {
                        final mood = moods[index];
                        final isSelected = selectedMood == mood;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(mood),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: Colors.white12,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11,
                            ),
                            onSelected: (val) {
                              setEditorState(() {
                                selectedMood = val ? mood : '';
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),

                // WhatsApp-Style Bottom Composer Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF232128),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: captionController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: widget.isPapMode
                                  ? 'Tulis catatan PAP untuk doi...'
                                  : 'Tambahkan keterangan...',
                              hintStyle: const TextStyle(color: Colors.white38),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Floating WhatsApp-Style Send Button
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          final caption = captionController.text.trim().isNotEmpty
                              ? captionController.text.trim()
                              : (selectedMood.isNotEmpty ? selectedMood : null);
                          widget.onMediaSelected(
                            file,
                            caption,
                            widget.isPapMode ? 'pap' : 'image',
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
