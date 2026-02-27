import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../config/theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  UserRole _selectedRole = UserRole.user;
  bool _isLoading = false;
  XFile? _profileImage;
  String? _photoValidationError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 600,
    );
    if (file == null) return;
    setState(() {
      _profileImage = file;
      _photoValidationError = null;
    });
  }

  Future<String?> _uploadProfilePhoto(String uid) async {
    if (_profileImage == null) return null;
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_photos/$uid.jpg');

    UploadTask task;
    final bytes = await _profileImage!.readAsBytes();
    task = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

    final snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate photo for volunteers
    if (_selectedRole == UserRole.volunteer && _profileImage == null) {
      setState(() {
        _photoValidationError =
            'Profile photo is required for volunteers';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = AuthService.instance.currentUser?.uid;

      // Upload profile photo if selected
      String? photoUrl;
      if (_profileImage != null && uid != null) {
        photoUrl = await _uploadProfilePhoto(uid);
      }

      await AuthService.instance.createProfile(
        name: _nameController.text.trim(),
        role: _selectedRole,
        photoUrl: photoUrl,
      );

      if (mounted) {
        switch (_selectedRole) {
          case UserRole.volunteer:
            context.go('/walking-buddy/volunteer-dashboard');
          case UserRole.admin:
          case UserRole.user:
            context.go('/home');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String msg = e.toString();
      if (msg.contains('unavailable') || msg.contains('not responding')) {
        msg = 'Could not connect to the server. Please check your internet '
              'connection and try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: SakhiTheme.danger,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                // Profile photo picker
                Center(
                  child: GestureDetector(
                    onTap: _pickProfileImage,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: SakhiTheme.primary.withValues(alpha: 0.1),
                                border: Border.all(
                                  color: _photoValidationError != null
                                      ? SakhiTheme.danger
                                      : (_profileImage != null
                                          ? SakhiTheme.safe
                                          : Colors.transparent),
                                  width: 2,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _profileImage != null
                                  ? FutureBuilder<List<int>>(
                                      future: _profileImage!.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Image.memory(
                                            snapshot.data! as dynamic,
                                            fit: BoxFit.cover,
                                            width: 100,
                                            height: 100,
                                          );
                                        }
                                        return const Icon(
                                          Icons.person_rounded,
                                          size: 50,
                                          color: SakhiTheme.primary,
                                        );
                                      },
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      size: 50,
                                      color: SakhiTheme.primary,
                                    ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: SakhiTheme.primary,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _profileImage != null ? 'Tap to change' : 'Add Photo',
                          style: TextStyle(
                            fontSize: 12,
                            color: _photoValidationError != null
                                ? SakhiTheme.danger
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_selectedRole == UserRole.volunteer)
                          Text(
                            'Required for volunteers',
                            style: TextStyle(
                              fontSize: 11,
                              color: _photoValidationError != null
                                  ? SakhiTheme.danger
                                  : SakhiTheme.searching,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (_photoValidationError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _photoValidationError!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: SakhiTheme.danger,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Set Up Your Profile',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tell us a bit about yourself to personalize your safety experience.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 32),
                // Name field
                Text(
                  'Your Name',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Enter your name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                // Role selection
                Text(
                  'I want to',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.shield_rounded,
                        title: 'Stay Safe',
                        subtitle: 'Get protection\n& monitoring',
                        isSelected: _selectedRole == UserRole.user,
                        color: SakhiTheme.primary,
                        onTap: () =>
                            setState(() {
                              _selectedRole = UserRole.user;
                              _photoValidationError = null;
                            }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.volunteer_activism_rounded,
                        title: 'Volunteer',
                        subtitle: 'Help others\nstay safe',
                        isSelected: _selectedRole == UserRole.volunteer,
                        color: SakhiTheme.safe,
                        onTap: () =>
                            setState(() {
                              _selectedRole = UserRole.volunteer;
                              _photoValidationError = null;
                            }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Get started
                ElevatedButton(
                  onPressed: _isLoading ? null : _createProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SakhiTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Get Started'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : Theme.of(context).cardTheme.color ?? Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: isSelected ? color : Colors.grey),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
