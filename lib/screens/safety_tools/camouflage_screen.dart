import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../services/camouflage_service.dart';

/// Screen that lets the user pick a disguise launcher icon to make
/// the app look like a harmless utility (Calculator, Calendar, Notes).
class CamouflageScreen extends StatefulWidget {
  const CamouflageScreen({super.key});

  @override
  State<CamouflageScreen> createState() => _CamouflageScreenState();
}

class _CamouflageScreenState extends State<CamouflageScreen> {
  final _service = CamouflageService.instance;
  String? _activeIcon; // null = default
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final current = await _service.currentIcon;
    if (mounted) {
      setState(() {
        _activeIcon = current;
        _loading = false;
      });
    }
  }

  // ── Icon-change flow ──

  Future<void> _onOptionTap(String? iconName) async {
    if (iconName == _activeIcon) return; // already active

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(child: Text('Change App Icon')),
          ],
        ),
        content: const Text(
          'Changing the launcher icon may briefly close the app or '
          'return you to the home screen.\n\n'
          'Do you wish to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);

    try {
      await _service.changeAppIcon(iconName);
      if (mounted) {
        setState(() {
          _activeIcon = iconName;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              iconName == null
                  ? 'Reverted to default Sakhi icon'
                  : 'App icon changed to "${CamouflageService.options[iconName]!.label}"',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change icon: ${e.message}'),
            backgroundColor: SakhiTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camouflage Mode'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // ── Explanation card ──
                Card(
                  color: cs.primaryContainer.withAlpha(60),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          color: cs.primary,
                          size: 36,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Disguise your app icon so it looks like an '
                            'everyday utility. This helps keep SAKHI hidden '
                            'from prying eyes.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Choose an icon',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap an option to switch your launcher icon.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 16),

                // ── Icon grid ──
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.88,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: CamouflageService.options.entries.map((entry) {
                    final key = entry.key; // nullable
                    final opt = entry.value;
                    final isActive = key == _activeIcon;
                    return _IconOptionCard(
                      option: opt,
                      isActive: isActive,
                      onTap: () => _onOptionTap(key),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),

                // ── Note ──
                Card(
                  color: cs.tertiaryContainer.withAlpha(50),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 20, color: cs.tertiary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'On Android the app may briefly close when the '
                            'icon changes. This is normal — it will reopen '
                            'automatically.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withAlpha(180),
                              height: 1.4,
                            ),
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

// ─────────────────────────────────────────────────────
// Single icon option card
// ─────────────────────────────────────────────────────

class _IconOptionCard extends StatelessWidget {
  final CamouflageOption option;
  final bool isActive;
  final VoidCallback onTap;

  const _IconOptionCard({
    required this.option,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isActive
            ? cs.primaryContainer.withAlpha(90)
            : cs.surfaceContainerHighest.withAlpha(60),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? cs.primary : cs.outlineVariant.withAlpha(80),
          width: isActive ? 2.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon preview — use real asset image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: option.previewIcon != null
                      ? Image.asset(
                          option.previewIcon!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 64,
                          width: 64,
                          decoration: BoxDecoration(
                            color: cs.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.shield_rounded,
                            size: 36,
                            color: cs.primary,
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  option.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isActive ? cs.primary : cs.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  option.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isActive) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Active',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
