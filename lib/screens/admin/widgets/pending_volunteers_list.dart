import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../models/user_model.dart';
import '../../../providers/providers.dart';
import '../../../services/firestore_service.dart';

/// Displays a list of volunteers whose KYC verification is pending,
/// and lets the admin inspect documents and approve/reject applications.
class PendingVolunteersList extends ConsumerWidget {
  const PendingVolunteersList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingVolunteersProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Text(
                'Verification Requests',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              pendingAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (list) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: SakhiTheme.searching.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${list.length} pending',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SakhiTheme.searching,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Review uploaded Government ID documents and approve or reject volunteer applications.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),

          // ── Content ──
          Expanded(
            child: pendingAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48,
                        color: SakhiTheme.danger.withValues(alpha: 0.6)),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load requests',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$e',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              data: (volunteers) {
                if (volunteers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded,
                            size: 64,
                            color: SakhiTheme.safe.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text(
                          'All caught up!',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No pending verification requests.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      theme.colorScheme.surfaceContainerHighest,
                    ),
                    columnSpacing: 28,
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Phone')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Submitted')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: volunteers.map((v) {
                      final submittedAt = v.verificationSubmittedAt;
                      final dateStr = submittedAt != null
                          ? DateFormat('dd MMM yyyy, hh:mm a')
                              .format(submittedAt)
                          : '—';

                      return DataRow(
                        cells: [
                          // Name
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                      SakhiTheme.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    v.name.isNotEmpty
                                        ? v.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: SakhiTheme.primary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  v.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Phone
                          DataCell(
                            Text(v.phone.isNotEmpty ? v.phone : '—'),
                          ),
                          // Status badge
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: SakhiTheme.searching
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'PENDING',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: SakhiTheme.searching,
                                ),
                              ),
                            ),
                          ),
                          // Submitted date
                          DataCell(
                            Text(
                              dateStr,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          // Actions
                          DataCell(
                            FilledButton.icon(
                              onPressed: () => _openReviewDialog(context, v),
                              icon: const Icon(Icons.visibility_rounded,
                                  size: 16),
                              label: const Text('Review'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                textStyle: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openReviewDialog(BuildContext context, UserModel volunteer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VolunteerReviewDialog(volunteer: volunteer),
    );
  }
}

// ─────────────────────────────────────────────────────
// Document Review Dialog
// ─────────────────────────────────────────────────────

class _VolunteerReviewDialog extends StatefulWidget {
  final UserModel volunteer;
  const _VolunteerReviewDialog({required this.volunteer});

  @override
  State<_VolunteerReviewDialog> createState() => _VolunteerReviewDialogState();
}

class _VolunteerReviewDialogState extends State<_VolunteerReviewDialog> {
  bool _processing = false;

  Future<void> _approve() async {
    setState(() => _processing = true);
    try {
      await FirestoreService.instance.approveVolunteer(widget.volunteer.uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.volunteer.name} has been approved as a verified volunteer.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SakhiTheme.safe,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SakhiTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _reject() async {
    // Confirm rejection
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Application?'),
        content: Text(
          'Are you sure you want to reject ${widget.volunteer.name}\'s '
          'verification application? Their uploaded ID documents will be '
          'deleted for privacy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: SakhiTheme.danger,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);
    try {
      // 1. Delete uploaded ID images from Firebase Storage
      await _deleteStorageFiles(widget.volunteer.uid);

      // 2. Update Firestore status
      await FirestoreService.instance.rejectVolunteer(widget.volunteer.uid);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.volunteer.name}\'s application has been rejected.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SakhiTheme.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SakhiTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  /// Deletes the uploaded ID images from Firebase Storage.
  /// Best-effort: logs errors but does not rethrow so the rejection
  /// still proceeds even if storage cleanup fails.
  Future<void> _deleteStorageFiles(String uid) async {
    final storage = FirebaseStorage.instance;
    final paths = [
      'verifications/$uid/id_front.jpg',
      'verifications/$uid/id_back.jpg',
    ];
    for (final path in paths) {
      try {
        await storage.ref(path).delete();
      } on FirebaseException catch (e) {
        // object-not-found is fine (already deleted or never uploaded)
        if (e.code != 'object-not-found') {
          debugPrint('[Admin] Failed to delete $path: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = widget.volunteer;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title Bar ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  (v.photoUrl != null && v.photoUrl!.isNotEmpty)
                      ? CircleAvatar(
                          radius: 22,
                          backgroundImage: NetworkImage(v.photoUrl!),
                          backgroundColor:
                              SakhiTheme.primary.withValues(alpha: 0.1),
                        )
                      : CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              SakhiTheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            v.name.isNotEmpty ? v.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: SakhiTheme.primary,
                              fontSize: 18,
                            ),
                          ),
                        ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Volunteer Verification Review',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed:
                        _processing ? null : () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // ── Body ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile info
                    _buildInfoSection(theme, v),
                    const SizedBox(height: 24),

                    // ID documents
                    Text(
                      'Uploaded Government ID',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Zoom in using scroll or pinch to inspect the document details.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDocumentImages(theme, v),
                  ],
                ),
              ),
            ),

            // ── Action Buttons ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Reject
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _processing ? null : _reject,
                      icon: const Icon(Icons.cancel_rounded, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SakhiTheme.danger,
                        side: const BorderSide(color: SakhiTheme.danger),
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Approve
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _processing ? null : _approve,
                      icon: _processing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.verified_rounded,
                              size: 18,
                            ),
                      label: Text(
                        _processing ? 'Processing…' : 'Approve Volunteer',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: SakhiTheme.safe,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Profile Info Section ──
  Widget _buildInfoSection(ThemeData theme, UserModel v) {
    final submitted = v.verificationSubmittedAt;
    final dateStr = submitted != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(submitted)
        : 'Unknown';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile photo row
            if (v.photoUrl != null && v.photoUrl!.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: SakhiTheme.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      v.photoUrl!,
                      fit: BoxFit.cover,
                      width: 64,
                      height: 64,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person_rounded,
                        size: 32,
                        color: SakhiTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Profile Photo',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Wrap(
              spacing: 40,
              runSpacing: 12,
              children: [
                _InfoTile(
              icon: Icons.person_rounded,
              label: 'Full Name',
              value: v.name,
            ),
            _InfoTile(
              icon: Icons.phone_rounded,
              label: 'Phone',
              value: v.phone.isNotEmpty ? v.phone : 'Not provided',
            ),
            _InfoTile(
              icon: Icons.badge_rounded,
              label: 'Role',
              value: v.role.name.toUpperCase(),
            ),
            _InfoTile(
              icon: Icons.calendar_today_rounded,
              label: 'Submitted',
              value: dateStr,
            ),
            _InfoTile(
              icon: Icons.fingerprint_rounded,
              label: 'User ID',
              value: v.uid.length > 12 ? '${v.uid.substring(0, 12)}…' : v.uid,
            ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Document Images ──
  Widget _buildDocumentImages(ThemeData theme, UserModel v) {
    final hasNoDocuments =
        (v.idFrontUrl == null || v.idFrontUrl!.isEmpty) &&
        (v.idBackUrl == null || v.idBackUrl!.isEmpty);

    if (hasNoDocuments) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: SakhiTheme.danger.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: SakhiTheme.danger.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.image_not_supported_rounded,
                size: 40,
                color: SakhiTheme.danger.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            const Text(
              'No ID documents uploaded',
              style: TextStyle(
                color: SakhiTheme.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final children = <Widget>[
          if (v.idFrontUrl != null && v.idFrontUrl!.isNotEmpty)
            _DocumentCard(
              label: 'ID Front',
              imageUrl: v.idFrontUrl!,
              theme: theme,
            ),
          if (v.idBackUrl != null && v.idBackUrl!.isNotEmpty)
            _DocumentCard(
              label: 'ID Back',
              imageUrl: v.idBackUrl!,
              theme: theme,
            ),
        ];

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children
                .map(
                  (child) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: child,
                    ),
                  ),
                )
                .toList(),
          );
        }
        return Column(
          children: children
              .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: c,
                  ))
              .toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────
// Supporting Widgets
// ─────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Card wrapping an InteractiveViewer for document image inspection.
class _DocumentCard extends StatelessWidget {
  final String label;
  final String imageUrl;
  final ThemeData theme;

  const _DocumentCard({
    required this.label,
    required this.imageUrl,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
          ),
          clipBehavior: Clip.antiAlias,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                final progress = loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null;
                return Center(
                  child: CircularProgressIndicator(value: progress),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_rounded,
                          size: 40,
                          color: SakhiTheme.danger.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
