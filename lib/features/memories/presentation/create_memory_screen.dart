import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/domain/auth_state.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../media/presentation/in_app_media_picker.dart';
import 'memories_screen.dart';

class CreateMemoryScreen extends ConsumerStatefulWidget {
  const CreateMemoryScreen({super.key});

  @override
  ConsumerState<CreateMemoryScreen> createState() => _CreateMemoryScreenState();
}

class _CreateMemoryScreenState extends ConsumerState<CreateMemoryScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  File? _selectedImage;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    await InAppMediaPicker.pickSingleImage(
      context: context,
      onFilePicked: (file) {
        setState(() => _selectedImage = file);
      },
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final user = ref.read(authStateProvider).user;
    if (user == null || user.coupleId == null) return;

    setState(() => _isSaving = true);
    try {
      String? mediaUrl;
      if (_selectedImage != null) {
        mediaUrl = await ref.read(storageRepositoryProvider).uploadCouplePhoto(
              coupleId: user.coupleId!,
              file: _selectedImage!,
            );
      }

      await ref.read(memoriesRepositoryProvider).createMemory(
            coupleId: user.coupleId!,
            title: title,
            description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
            mediaUrl: mediaUrl,
            memoryDate: _selectedDate,
            createdBy: user.uid,
          );

      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Memory'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceSubtleDark : AppColors.surfaceSubtleLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.dividerLight),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, size: 44, color: AppColors.primary),
                          const SizedBox(height: 8),
                          Text(
                            'select a special photo',
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Memory Title *'),
            ),
            const SizedBox(height: 16),
            // Description
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 16),
            // Date Picker Card
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
              ),
              leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
              title: const Text('Memory Date'),
              subtitle: Text(DateFormat('MMMM d, yyyy').format(_selectedDate)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _selectDate,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('save memory'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
