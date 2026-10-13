import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app/theme/app_colors.dart';
import 'builtin_camera_screen.dart';

class BuiltinMediaPickerSheet extends StatefulWidget {
  final bool isPap;
  final Function(File file) onMediaPicked;
  final Function(File file, String? caption, String type)? onMediaWithEditorSelected;

  const BuiltinMediaPickerSheet({
    super.key,
    this.isPap = false,
    required this.onMediaPicked,
    this.onMediaWithEditorSelected,
  });

  @override
  State<BuiltinMediaPickerSheet> createState() => _BuiltinMediaPickerSheetState();
}

class _BuiltinMediaPickerSheetState extends State<BuiltinMediaPickerSheet> {
  List<File> _allMediaFiles = [];
  List<File> _filteredFiles = [];
  bool _isLoading = true;
  String _selectedFolder = 'Semua';
  final List<String> _folders = ['Semua', 'Kamera', 'Download', 'Pictures'];

  @override
  void initState() {
    super.initState();
    _loadMediaFiles();
  }

  Future<void> _loadMediaFiles() async {
    setState(() => _isLoading = true);
    final List<File> files = [];

    try {
      final List<String> searchPaths = [
        '/storage/emulated/0/DCIM/Camera',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Download',
        (await getTemporaryDirectory()).path,
        (await getApplicationDocumentsDirectory()).path,
      ];

      for (final path in searchPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          try {
            final entities = dir.listSync();
            for (final entity in entities) {
              if (entity is File) {
                final ext = entity.path.toLowerCase();
                if (ext.endsWith('.jpg') ||
                    ext.endsWith('.jpeg') ||
                    ext.endsWith('.png') ||
                    ext.endsWith('.webp')) {
                  files.add(entity);
                }
              }
            }
          } catch (e) {
            debugPrint('Cannot list directory $path: $e');
          }
        }
      }

      // Sort by modified time descending (newest first)
      files.sort((a, b) {
        try {
          return b.lastModifiedSync().compareTo(a.lastModifiedSync());
        } catch (_) {
          return 0;
        }
      });

      // If emulator has no photos at all, create 3 aesthetic sample photos so the grid is never blank
      if (files.isEmpty) {
        final sampleFiles = await _generateSamplePhotos();
        files.addAll(sampleFiles);
      }
    } catch (e) {
      debugPrint('Error scanning media files: $e');
    }

    if (mounted) {
      setState(() {
        _allMediaFiles = files;
        _filterFiles();
        _isLoading = false;
      });
    }
  }

  Future<List<File>> _generateSamplePhotos() async {
    final List<File> samples = [];
    try {
      final tempDir = await getTemporaryDirectory();
      // Generate 4 gradient/tinted sample JPEG files with valid JPEG headers
      final sampleConfigs = [
        ('sample_love_1.jpg', 0xE9, 0x1E, 0x63), // Pink
        ('sample_sunset_2.jpg', 0xFF, 0x57, 0x22), // Deep Orange
        ('sample_coffee_3.jpg', 0x79, 0x55, 0x48), // Warm Brown
        ('sample_night_4.jpg', 0x21, 0x96, 0xF3), // Soft Blue
      ];

      for (final (name, r, g, b) in sampleConfigs) {
        final file = File('${tempDir.path}/$name');
        if (!await file.exists()) {
          // Minimal 16x16 valid JPEG header with color markers
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
            0x00, r, g, b, 0xFF, 0xD9
          ];
          await file.writeAsBytes(bytes);
        }
        samples.add(file);
      }
    } catch (e) {
      debugPrint('Error generating sample photos: $e');
    }
    return samples;
  }

  void _filterFiles() {
    if (_selectedFolder == 'Semua') {
      _filteredFiles = List.from(_allMediaFiles);
    } else if (_selectedFolder == 'Kamera') {
      _filteredFiles = _allMediaFiles.where((f) => f.path.contains('DCIM') || f.path.contains('Camera')).toList();
    } else if (_selectedFolder == 'Download') {
      _filteredFiles = _allMediaFiles.where((f) => f.path.contains('Download')).toList();
    } else if (_selectedFolder == 'Pictures') {
      _filteredFiles = _allMediaFiles.where((f) => f.path.contains('Pictures')).toList();
    }
  }

  void _onPhotoSelected(File file) {
    if (widget.onMediaWithEditorSelected != null) {
      _showInAppEditorModal(file);
    } else {
      widget.onMediaPicked(file);
    }
  }

  void _openCamera() {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BuiltinCameraScreen(
          isPapMode: widget.isPap,
          onMediaSelected: (file, caption, type) {
            if (widget.onMediaWithEditorSelected != null) {
              widget.onMediaWithEditorSelected!(file, caption, type);
            } else {
              widget.onMediaPicked(file);
            }
          },
        ),
      ),
    );
  }

  void _showInAppEditorModal(File file) {
    final captionController = TextEditingController();
    String selectedMood = widget.isPap ? 'Lagi kangen kamu ❤️' : '';

    final moods = [
      'Lagi kangen kamu ❤️',
      'Lagi santai nih ☕',
      'Lagi kerja/belajar 💻',
      'Lagi di jalan 🚗',
      'Lagi makan 🍕',
      'Mau tidur 😴',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(
                color: Color(0xFF141216),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'US ONLY • ${DateFormat('HH:mm').format(DateTime.now())}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx); // Close editor
                            Navigator.pop(context); // Close picker
                            final caption = captionController.text.trim().isNotEmpty
                                ? captionController.text.trim()
                                : (selectedMood.isNotEmpty ? selectedMood : null);
                            widget.onMediaWithEditorSelected!(
                              file,
                              caption,
                              widget.isPap ? 'pap' : 'image',
                            );
                          },
                          child: const Text('Kirim 🚀'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),

                  // Image Frame
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.file(file, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),

                  // Mood Chips
                  if (widget.isPap)
                    SizedBox(
                      height: 44,
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
                              backgroundColor: Colors.white10,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 11,
                              ),
                              onSelected: (val) {
                                setModalState(() {
                                  selectedMood = val ? mood : '';
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),

                  // Caption Input
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
                                hintText: widget.isPap
                                    ? 'Tulis catatan PAP untuk doi...'
                                    : 'Tambahkan keterangan foto...',
                                hintStyle: const TextStyle(color: Colors.white38),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                            final caption = captionController.text.trim().isNotEmpty
                                ? captionController.text.trim()
                                : (selectedMood.isNotEmpty ? selectedMood : null);
                            widget.onMediaWithEditorSelected!(
                              file,
                              caption,
                              widget.isPap ? 'pap' : 'image',
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
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_library_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Galeri Foto Us Only',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_filteredFiles.length} Foto',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Folder filter chips (WhatsApp-style)
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _folders.length,
              itemBuilder: (context, index) {
                final folder = _folders[index];
                final isSelected = _selectedFolder == folder;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(folder),
                    selected: isSelected,
                    selectedColor: AppColors.primaryLight,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : null,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      setState(() {
                        _selectedFolder = folder;
                        _filterFiles();
                      });
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // Media Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: _filteredFiles.length + 1, // +1 for Camera tile
                    itemBuilder: (context, index) {
                      // First tile is always the Built-in Camera tile (like WhatsApp)
                      if (index == 0) {
                        return InkWell(
                          onTap: _openCamera,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_rounded, color: Colors.white, size: 36),
                                SizedBox(height: 6),
                                Text(
                                  'Kamera',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final file = _filteredFiles[index - 1];
                      return GestureDetector(
                        onTap: () => _onPhotoSelected(file),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                file,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  child: const Icon(Icons.broken_image_rounded),
                                ),
                              ),
                              // Subtle hover overlay
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.5),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
