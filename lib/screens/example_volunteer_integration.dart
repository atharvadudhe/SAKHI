import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/constants.dart';
import '../../models/user_model.dart';
import '../../providers/volunteer_providers.dart';
import '../../screens/find_volunteer_screen.dart';
import '../../screens/volunteer_mode_screen.dart';
import '../../widgets/volunteer_widgets.dart';

/**
 * EXAMPLE: Volunteer Mode Integration in Main Navigation
 * 
 * This file demonstrates how to integrate the Volunteer Mode feature
 * into your main app. This is a complete working example you can
 * copy and adapt to your needs.
 */

/// Example main screen that shows different options based on user role
class ExampleVolunteerMainScreen extends ConsumerWidget {
  final String currentUserId;
  final UserModel currentUser; // Get from auth + Firestore

  const ExampleVolunteerMainScreen({
    Key? key,
    required this.currentUserId,
    required this.currentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SAKHI - Volunteer Mode'),
        elevation: 0,
        backgroundColor: Colors.pink.shade400,
      ),
      body: _buildBody(context, ref),
      bottomNavigationBar: _buildNavigationBar(context),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    // Check if user is a volunteer
    final isVolunteer = currentUser.role == UserRole.volunteer;
    final isVerified =
        currentUser.verificationStatus == VerificationStatus.verified;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info card
          _buildUserCard(context),
          const SizedBox(height: 24),

          // Main features
          if (!isVolunteer) ...[
            _buildFindVolunteerSection(context),
          ] else if (isVerified) ...[
            _buildVolunteerSection(context, ref),
          ] else ...[
            _buildVerificationRequiredCard(),
          ],
        ],
      ),
    );
  }

  /// User info card
  Widget _buildUserCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: currentUser.photoUrl != null
                  ? NetworkImage(currentUser.photoUrl!)
                  : null,
              child: currentUser.photoUrl == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentUser.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentUser.role.name.toUpperCase(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (currentUser.role == UserRole.volunteer)
                    VolunteerAvailabilityBadge(
                      isAvailable: currentUser.isAvailable,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Find volunteer section for regular users
  Widget _buildFindVolunteerSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Find a Walking Buddy',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Search for verified volunteers nearby to help you with your walk.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FindVolunteerScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink.shade400,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.person_search),
            label: const Text('Browse Volunteers'),
          ),
        ),
        const SizedBox(height: 16),
        // Your pending requests
        _buildUserRequestsSection(),
      ],
    );
  }

  /// Volunteer section for volunteers
  Widget _buildVolunteerSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Volunteer Mode',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Help users find walking companions. You\'ll receive requests in real-time.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VolunteerModeScreen(
                    volunteerId: currentUserId,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade400,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.volunteer_activism),
            label: const Text('Open Volunteer Mode'),
          ),
        ),
        const SizedBox(height: 24),
        // Volunteer stats
        _buildVolunteerStatsSection(ref),
      ],
    );
  }

  /// Verification required card
  Widget _buildVerificationRequiredCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.orange.shade700,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verification Required',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete your KYC verification to become an active volunteer.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
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

  /// User's pending requests section
  Widget _buildUserRequestsSection() {
    // This would typically be in a separate widget with StreamBuilder
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Requests',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: Colors.orange),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No pending requests',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Find a volunteer to get started',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Volunteer statistics section
  Widget _buildVolunteerStatsSection(WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Statistics',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // Use the volunteer stats provider
        ref.watch(volunteerStatsProvider(currentUserId)).when(
          data: (stats) {
            return Row(
              children: [
                _buildStatCard(
                  'Accepted',
                  stats['accepted'] ?? 0,
                  Colors.green,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Rejected',
                  stats['rejected'] ?? 0,
                  Colors.red,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Completed',
                  stats['completed'] ?? 0,
                  Colors.blue,
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, st) => Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Error loading stats: $error',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Statistics card widget
  Widget _buildStatCard(String label, int count, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom navigation bar
  Widget _buildNavigationBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavButton(
            icon: Icons.home,
            label: 'Home',
            onPressed: () {},
          ),
          _buildNavButton(
            icon: Icons.person_search,
            label: 'Find Buddy',
            onPressed: currentUser.role != UserRole.volunteer
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FindVolunteerScreen(),
                      ),
                    );
                  }
                : null,
          ),
          _buildNavButton(
            icon: Icons.volunteer_activism,
            label: 'Volunteer',
            onPressed: currentUser.role == UserRole.volunteer &&
                    currentUser.verificationStatus ==
                        VerificationStatus.verified
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VolunteerModeScreen(
                          volunteerId: currentUserId,
                        ),
                      ),
                    );
                  }
                : null,
          ),
          _buildNavButton(
            icon: Icons.person,
            label: 'Profile',
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  /// Navigation button
  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Opacity(
      opacity: onPressed != null ? 1.0 : 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(icon),
            onPressed: onPressed,
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// EXAMPLE USAGE IN main.dart
// =====================================================================

/*
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAKHI',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;

        return FutureBuilder<UserModel?>(
          future: FirestoreService.instance.getUser(user.uid),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final userModel = snapshot.data!;

            return ExampleVolunteerMainScreen(
              currentUserId: user.uid,
              currentUser: userModel,
            );
          },
        );
      },
    );
  }
}
*/
