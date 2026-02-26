import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../services/firestore_service.dart';

/// Allows the user to set a 4-digit Safe PIN and a 4-digit Duress PIN.
/// The Duress PIN silently keeps an SOS session active while visually
/// appearing to cancel it—critical for anti-coercion scenarios.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _safePinController = TextEditingController();
  final _confirmSafeController = TextEditingController();
  final _duressController = TextEditingController();
  final _confirmDuressController = TextEditingController();

  bool _saving = false;
  bool _obscureSafe = true;
  bool _obscureDuress = true;
  bool _pinsConfigured = false;

  @override
  void initState() {
    super.initState();
    // Do NOT pre-fill PIN controllers — PINs should never be displayed.
    // Instead, set a flag indicating whether PINs are already configured.
    final user = ref.read(currentUserProvider).value;
    _pinsConfigured = user?.safePin != null && user?.duressPin != null;
  }

  @override
  void dispose() {
    _safePinController.dispose();
    _confirmSafeController.dispose();
    _duressController.dispose();
    _confirmDuressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Final cross-field safety check: duress PIN must differ from safe PIN
    if (_duressController.text.trim() == _safePinController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Duress PIN must differ from Safe PIN'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SakhiTheme.danger,
        ),
      );
      return;
    }

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      await FirestoreService.instance.savePins(
        uid: uid,
        safePin: _safePinController.text.trim(),
        duressPin: _duressController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PINs saved successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Failed to save PINs: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save PINs. Please try again.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SakhiTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Setup Safety PINs')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Explanation card ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SakhiTheme.connected.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: SakhiTheme.connected.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shield_rounded,
                        color: SakhiTheme.connected,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Anti-Coercion Protection',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: SakhiTheme.connected,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'If someone forces you to cancel an SOS, '
                              'enter your Duress PIN instead. The app will '
                              'pretend to cancel but silently keep the alert '
                              'active and notify volunteers of escalation.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Safe PIN ──
                Text(
                  'Safe PIN',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: SakhiTheme.safe,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter this PIN to genuinely cancel an SOS.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 8),
                _buildPinField(
                  controller: _safePinController,
                  label: '4-digit Safe PIN',
                  obscure: _obscureSafe,
                  onToggle: () =>
                      setState(() => _obscureSafe = !_obscureSafe),
                  validator: (v) {
                    if (v == null || v.length != 4) {
                      return 'Enter exactly 4 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildPinField(
                  controller: _confirmSafeController,
                  label: 'Confirm Safe PIN',
                  obscure: _obscureSafe,
                  onToggle: () =>
                      setState(() => _obscureSafe = !_obscureSafe),
                  validator: (v) {
                    if (v != _safePinController.text) {
                      return 'PINs do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // ── Duress PIN ──
                Text(
                  'Duress PIN',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: SakhiTheme.danger,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter this PIN when forced to cancel. The session '
                  'stays active secretly.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 8),
                _buildPinField(
                  controller: _duressController,
                  label: '4-digit Duress PIN',
                  obscure: _obscureDuress,
                  onToggle: () =>
                      setState(() => _obscureDuress = !_obscureDuress),
                  validator: (v) {
                    if (v == null || v.length != 4) {
                      return 'Enter exactly 4 digits';
                    }
                    if (v == _safePinController.text) {
                      return 'Duress PIN must differ from Safe PIN';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildPinField(
                  controller: _confirmDuressController,
                  label: 'Confirm Duress PIN',
                  obscure: _obscureDuress,
                  onToggle: () =>
                      setState(() => _obscureDuress = !_obscureDuress),
                  validator: (v) {
                    if (v != _duressController.text) {
                      return 'PINs do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // ── Save button ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.lock_rounded, size: 20),
                    label: Text(_saving ? 'Saving…' : 'Save PINs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SakhiTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}
