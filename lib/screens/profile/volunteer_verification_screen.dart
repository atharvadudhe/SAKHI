import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../services/firestore_service.dart';

/// KYC / identity verification screen for volunteers.
/// Uploads government-issued ID photos to Firebase Storage and updates
/// the user's verification status to `pending`.
class VolunteerVerificationScreen extends ConsumerStatefulWidget {
  const VolunteerVerificationScreen({super.key});

  @override
  ConsumerState<VolunteerVerificationScreen> createState() =>
      _VolunteerVerificationScreenState();
}

class _VolunteerVerificationScreenState
    extends ConsumerState<VolunteerVerificationScreen> {
  final _picker = ImagePicker();

  XFile? _idFront;
  XFile? _idBack;
  bool _uploading = false;
  double _uploadProgress = 0;

  Future<void> _pickImage({required bool isFront}) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (file == null) return;
    setState(() {
      if (isFront) {
        _idFront = file;
      } else {
        _idBack = file;
      }
    });
  }

  Future<String> _uploadFile(XFile file, String path) async {
    final storageRef = FirebaseStorage.instance.ref().child(path);

    UploadTask task;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      task = storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      task = storageRef.putFile(File(file.path));
    }

    task.snapshotEvents.listen((snap) {
      if (mounted) {
        setState(() {
          _uploadProgress =
              snap.bytesTransferred / (snap.totalBytes == 0 ? 1 : snap.totalBytes);
        });
      }
    });

    final snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _submit() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || _idFront == null || _idBack == null) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      final frontUrl = await _uploadFile(
        _idFront!,
        'verifications/$uid/id_front.jpg',
      );
      final backUrl = await _uploadFile(
        _idBack!,
        'verifications/$uid/id_back.jpg',
      );

      await FirestoreService.instance.updateVerificationStatus(
        uid,
        VerificationStatus.pending.name,
        idFrontUrl: frontUrl,
        idBackUrl: backUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification submitted! We will review it shortly.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: ${e.message}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SakhiTheme.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SakhiTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Volunteer Verification')),
      body: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (user) {
            if (user == null) {
              return const Center(child: Text('Not logged in'));
            }

            // Already pending / verified / rejected — show appropriate state.
            if (user.verificationStatus == VerificationStatus.pending) {
              return _buildStatusView(
                theme,
                icon: Icons.hourglass_top_rounded,
                color: SakhiTheme.searching,
                title: 'Verification Pending',
                subtitle:
                    'Your documents are being reviewed. This usually takes '
                    '24–48 hours. You will be notified once verified.',
              );
            }
            if (user.verificationStatus == VerificationStatus.verified) {
              return _buildStatusView(
                theme,
                icon: Icons.verified_rounded,
                color: SakhiTheme.safe,
                title: 'Verified',
                subtitle:
                    'Your identity has been confirmed. '
                    'Thank you for helping keep our community safe!',
              );
            }
            if (user.verificationStatus == VerificationStatus.rejected) {
              return _buildStatusView(
                theme,
                icon: Icons.block_rounded,
                color: SakhiTheme.danger,
                title: 'Verification Rejected',
                subtitle:
                    'Your submission was rejected. Please re-submit '
                    'with valid, legible government-issued ID images.',
                showResubmit: true,
              );
            }

            // Unverified — show upload UI.
            return _buildUploadForm(theme);
          },
        ),
      ),
    );
  }

  Widget _buildStatusView(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    bool showResubmit = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (showResubmit) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => setState(() {}), // forces rebuild to show form
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Re-submit Documents'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Explanation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SakhiTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: SakhiTheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: SakhiTheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why do we verify volunteers?',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Women\'s safety is our top priority. Verifying '
                        'your government-issued ID ensures that only '
                        'trusted individuals can view exact locations of '
                        'people in distress. Your data is encrypted and '
                        'handled securely.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ID Front
          Text(
            'Government ID — Front',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildImagePicker(
            file: _idFront,
            onTap: () => _pickImage(isFront: true),
          ),
          const SizedBox(height: 24),

          // ID Back
          Text(
            'Government ID — Back',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildImagePicker(
            file: _idBack,
            onTap: () => _pickImage(isFront: false),
          ),
          const SizedBox(height: 32),

          // Upload progress
          if (_uploading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                minHeight: 6,
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(SakhiTheme.primary),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Uploading… ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  (_idFront != null && _idBack != null && !_uploading)
                      ? _submit
                      : null,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_rounded),
              label: Text(
                _uploading ? 'Uploading…' : 'Submit for Verification',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: SakhiTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker({
    required XFile? file,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: _uploading ? null : onTap,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: file != null
                ? SakhiTheme.safe.withValues(alpha: 0.4)
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: kIsWeb
                    ? Image.network(file.path, fit: BoxFit.cover)
                    : Image.file(File(file.path), fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_rounded,
                    size: 36,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to upload',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
