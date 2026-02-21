import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/emergency_contact.dart';
import '../../providers/providers.dart';
import '../../services/firestore_service.dart';

class EmergencyContactsScreen extends ConsumerStatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  ConsumerState<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState
    extends ConsumerState<EmergencyContactsScreen> {
  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Emergency Contacts')),
        body: const Center(child: Text('Please log in')),
      );
    }

    final contactsAsync = ref.watch(emergencyContactsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Emergency Contacts'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(context, uid, null),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Contact'),
        backgroundColor: SakhiTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (contacts) {
          if (contacts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.contacts_rounded,
                      size: 72,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Emergency Contacts',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add trusted people who will be notified during emergencies.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: contacts.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: SakhiTheme.danger.withValues(alpha: 0.08),
                    border: Border.all(
                      color: SakhiTheme.danger.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: SakhiTheme.danger,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'These contacts will be notified when you trigger SOS or start a safety session.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final contact = contacts[index - 1];
              return _ContactCard(
                contact: contact,
                onEdit: () => _showAddEditDialog(context, uid, contact),
                onDelete: () => _confirmDelete(context, uid, contact),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddEditDialog(
    BuildContext context,
    String uid,
    EmergencyContact? existing,
  ) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    // Strip +91 prefix for editing since the input field displays +91 as prefixText
    final existingPhone = (existing?.phone ?? '').replaceFirst('+91', '');
    final phoneController = TextEditingController(text: existingPhone);
    final relationController = TextEditingController(
      text: existing?.relationship ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                existing == null ? 'Add Contact' : 'Edit Contact',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                  prefixText: '+91 ',
                ),
                validator: (v) => v == null || v.trim().length < 10
                    ? 'Enter 10-digit number'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: relationController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Relationship (optional)',
                  prefixIcon: Icon(Icons.group_outlined),
                  hintText: 'e.g. Mother, Friend, Roommate',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final contact = EmergencyContact(
                    id: existing?.id ?? '',
                    name: nameController.text.trim(),
                    phone: '+91${phoneController.text.trim()}',
                    relationship: relationController.text.trim(),
                  );
                  try {
                    if (existing == null) {
                      await FirestoreService.instance.addEmergencyContact(
                        uid,
                        contact,
                      );
                    } else {
                      await FirestoreService.instance.updateEmergencyContact(
                        uid,
                        contact,
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SakhiTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(existing == null ? 'Add' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    String uid,
    EmergencyContact contact,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Contact?'),
        content: Text('Remove ${contact.name} from emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirestoreService.instance.deleteEmergencyContact(
                uid,
                contact.id,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SakhiTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: SakhiTheme.danger.withValues(alpha: 0.1),
          ),
          child: const Icon(Icons.person_rounded, color: SakhiTheme.danger),
        ),
        title: Text(
          contact.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${contact.phone}${contact.relationship.isNotEmpty ? ' • ${contact.relationship}' : ''}',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20),
              onPressed: onEdit,
              color: Colors.grey,
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, size: 20),
              onPressed: onDelete,
              color: SakhiTheme.danger,
            ),
          ],
        ),
      ),
    );
  }
}
