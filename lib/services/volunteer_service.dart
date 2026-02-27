import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/constants.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

// /// Extension on FirestoreService for Volunteer operations
// extension VolunteerService on FirestoreService {
//   // ───────── Collections ─────────
//   static const String _walkingRequestsCollection = 'walkingRequests';

//   // ───────── Constants ─────────
//   static const String _earthRadiusKm = '6371'; // Earth's radius in kilometers

//   /// Find nearby verified and available volunteers for a user
//   ///
//   /// Returns a list of verified volunteers within [volunteerSearchRadiusKm]
//   /// sorted by distance (nearest first).
//   ///
//   /// Filters:
//   /// - role == "volunteer"
//   /// - verificationStatus == "verified"
//   /// - isAvailable == true
//   /// - currentLocation is not null
//   ///
//   /// DEBUG MODE: Set _debugVolunteerSearch = true to enable detailed logging
//   static const bool _debugVolunteerSearch = true;
//   static const bool _relaxedFilteringMode = false; // Set true to bypass distance filter

//   Future<List<UserModel>> fetchNearbyVerifiedVolunteers(LatLng userLocation) async {
//     try {
//       if (_debugVolunteerSearch) {
//         print('═══════════════════════════════════════════════════════════');
//         print('🔍 DEBUG: fetchNearbyVerifiedVolunteers() STARTED');
//         print('═══════════════════════════════════════════════════════════');
//         print('📍 User Location: lat=${userLocation.latitude}, lng=${userLocation.longitude}');
//         print('📏 Search Radius: ${AppConstants.volunteerSearchRadiusKm} km');
//         print('🔓 Relaxed Filtering Mode: $_relaxedFilteringMode');
//       }

//       // Fetch all volunteers (we'll filter in-memory due to Firestore query limitations)
//       if (_debugVolunteerSearch) {
//         print('\n🔄 Querying Firestore for volunteers...');
//         print('  Query: role == "${UserRole.volunteer.name}"');
//         print('  Query: verificationStatus == "${VerificationStatus.verified.name}"');
//         print('  Query: isAvailable == true');
//       }

//       final snapshot = await db
//           .collection(AppConstants.usersCollection)
//           .where('role', isEqualTo: UserRole.volunteer.name)
//           .where('verificationStatus', isEqualTo: 'verified')
//           .where('isAvailable', isEqualTo: true)
//           .get();

//       if (_debugVolunteerSearch) {
//         print('✅ Firestore query returned: ${snapshot.docs.length} documents');
//       }

//       final volunteers = <UserModel>[];
//       int filteredOutCount = 0;

//       for (int i = 0; i < snapshot.docs.length; i++) {
//         final doc = snapshot.docs[i];
//         final data = doc.data();

//         if (_debugVolunteerSearch) {
//           print('\n────────────────────────────────────────────────────────');
//           print('📋 User #${i + 1} - UID: ${doc.id}');
//           print('────────────────────────────────────────────────────────');
//         }

//         // Check raw Firestore data
//         if (_debugVolunteerSearch) {
//           print('Raw Firestore Fields:');
//           print('  role: ${data['role']} (type: ${data['role'].runtimeType})');
//           print('  verificationStatus: ${data['verificationStatus']} (type: ${data['verificationStatus'].runtimeType})');
//           print('  isAvailable: ${data['isAvailable']} (type: ${data['isAvailable'].runtimeType})');
//           print('  currentLocation: ${data['currentLocation']} (type: ${data['currentLocation'].runtimeType})');
//         }

//         final volunteer = UserModel.fromJson(data);

//         // if (_debugVolunteerSearch) {
//         //   print('Parsed UserModel:');
//         //   print('  uid: ${volunteer.uid}');
//         //   print('  name: ${volunteer.name}');
//         //   print('  role: ${volunteer.role} (enum)');
//         //   print('  verificationStatus: ${volunteer.verificationStatus} (enum)');
//         //   print('  isAvailable: ${volunteer.isAvailable}');
//         //   print('  currentLocation: ${volunteer.currentLocation}');
//         // }

//         // Check 1: Location is not null
//         // if (volunteer.currentLocation == null) {
//         //   if (_debugVolunteerSearch) {
//         //     print('❌ FILTERED OUT: currentLocation is NULL');
//         //     filteredOutCount++;
//         //   }
//         //   continue;
//         // }

//         // if (_debugVolunteerSearch) {
//         //   print('✓ Location check passed');
//         //   print('  lat: ${volunteer.currentLocation!.latitude}');
//         //   print('  lng: ${volunteer.currentLocation!.longitude}');
//         // }

//         // Calculate distance using Haversine formula
//         // final distance = _calculateHaversineDistance(
//         //   userLocation.latitude,
//         //   userLocation.longitude,
//         //   volunteer.currentLocation!.latitude,
//         //   volunteer.currentLocation!.longitude,
//         // );

//         // if (_debugVolunteerSearch) {
//         //   print('📏 Haversine Distance Calculation:');
//         //   print('  Distance: ${distance.toStringAsFixed(2)} km');
//         //   print('  Max Radius: ${AppConstants.volunteerSearchRadiusKm} km');
//         //   print('  Within Radius: ${distance <= AppConstants.volunteerSearchRadiusKm}');
//         // }

//         // Check 2: Within search radius (unless relaxed mode)
//         // if (!_relaxedFilteringMode && distance > AppConstants.volunteerSearchRadiusKm) {
//         //   if (_debugVolunteerSearch) {
//         //     print('❌ FILTERED OUT: Too far (${distance.toStringAsFixed(2)} km > ${AppConstants.volunteerSearchRadiusKm} km)');
//         //     filteredOutCount++;
//         //   }
//         //   continue;
//         // }

//         if (_debugVolunteerSearch) {
//           print('✅ PASSED ALL FILTERS - Adding to results');
//         }

//         volunteers.add(volunteer);
//       }

//       // Sort by distance (nearest first)
//       if (_debugVolunteerSearch) {
//         print('\n────────────────────────────────────────────────────────');
//         print('📊 FILTERING SUMMARY:');
//         print('  Total from Firestore: ${snapshot.docs.length}');
//         print('  Filtered Out: $filteredOutCount');
//         print('  Final Result: ${volunteers.length} volunteers');
//       }

//       if (volunteers.isNotEmpty) {
//         volunteers.sort((a, b) {
//           final distanceA = _calculateHaversineDistance(
//             userLocation.latitude,
//             userLocation.longitude,
//             a.currentLocation!.latitude,
//             a.currentLocation!.longitude,
//           );
//           final distanceB = _calculateHaversineDistance(
//             userLocation.latitude,
//             userLocation.longitude,
//             b.currentLocation!.latitude,
//             b.currentLocation!.longitude,
//           );
//           return distanceA.compareTo(distanceB);
//         });

//         if (_debugVolunteerSearch) {
//           print('\n📍 SORTED BY DISTANCE:');
//           for (int i = 0; i < volunteers.length; i++) {
//             final dist = _calculateHaversineDistance(
//               userLocation.latitude,
//               userLocation.longitude,
//               volunteers[i].currentLocation!.latitude,
//               volunteers[i].currentLocation!.longitude,
//             );
//             print('  #${i + 1}: ${volunteers[i].name} - ${dist.toStringAsFixed(2)} km');
//           }
//         }
//       }

//       if (_debugVolunteerSearch) {
//         print('\n═══════════════════════════════════════════════════════════');
//         print('✅ DEBUG: fetchNearbyVerifiedVolunteers() COMPLETED');
//         print('═══════════════════════════════════════════════════════════\n');
//       }

//       return volunteers;
//     } catch (e) {
//       print('❌ ERROR in fetchNearbyVerifiedVolunteers: $e');
//       print('Stack trace: $e');
//       rethrow;
//     }
//   }

//   /// DEBUG: Fetch ALL users from Firestore (no filters) to diagnose filtering issues
//   /// 
//   /// Use this to see what's actually in the database and why they're being filtered out
//   Future<void> debugFetchAllUsers() async {
//     try {
//       print('\n╔════════════════════════════════════════════════════════════╗');
//       print('║ 🔍 DEBUG: Fetching ALL Users (NO FILTERS)                  ║');
//       print('╚════════════════════════════════════════════════════════════╝\n');

//       final snapshot = await db.collection(AppConstants.usersCollection).get();

//       print('📊 TOTAL USERS IN FIRESTORE: ${snapshot.docs.length}\n');

//       for (int i = 0; i < snapshot.docs.length; i++) {
//         final doc = snapshot.docs[i];
//         final data = doc.data();

//         print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//         print('👤 User #${i + 1} (UID: ${doc.id})');
//         print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        
//         print('Basic Info:');
//         print('  name: "${data['name']}"');
//         print('  phone: "${data['phone']}"');
        
//         print('\nVolunteer Fields:');
//         print('  role: "${data['role']}" (matches "volunteer"? ${data['role'] == 'volunteer'})');
//         print('  isAvailable: ${data['isAvailable']} (type: ${data['isAvailable'].runtimeType})');
//         print('  verificationStatus: "${data['verificationStatus']}" (matches "verified"? ${data['verificationStatus'] == 'verified'})');
//         print('  verifiedStatus (old): ${data['verifiedStatus']} (DEPRECATED)');
        
//         print('\nLocation Fields:');
//         final loc = data['currentLocation'];
//         if (loc is GeoPoint) {
//           print('  currentLocation: GeoPoint(lat=${loc.latitude}, lng=${loc.longitude})');
//         } else if (loc == null) {
//           print('  currentLocation: NULL ⚠️');
//         } else {
//           print('  currentLocation: ${loc} (type: ${loc.runtimeType}) ⚠️ UNEXPECTED TYPE');
//         }
        
//         print('\nOther Fields:');
//         print('  uid: "${data['uid']}"');
//         print('  photoUrl: "${data['photoUrl']}"');
//         print('  lastHeartbeat: ${data['lastHeartbeat']}');
//         print('  safePin: ${data['safePin'] != null ? '***' : 'null'}');
//         print('  duressPin: ${data['duressPin'] != null ? '***' : 'null'}');
        
//         // Try to parse as model
//       //   print('\nParsing as UserModel:');
//       //   try {
//       //     final volunteer = UserModel.fromJson(data);
//       //     print('  ✅ Successfully parsed');
//       //     print('  role enum: ${volunteer.role}');
//       //     print('  verificationStatus enum: ${volunteer.verificationStatus}');
//       //     print('  isAvailable: ${volunteer.isAvailable}');
//       //     print('  currentLocation: ${volunteer.currentLocation}');
//       //   } catch (e) {
//       //     print('  ❌ Failed to parse: $e');
//       //   }
        
//       //   print('');
//       // }

//       print('╔════════════════════════════════════════════════════════════╗');
//       print('║ ✅ DEBUG: Finished fetching all users                     ║');
//       print('╚════════════════════════════════════════════════════════════╝\n');
      
//     } catch (e) {
//       print('❌ ERROR in debugFetchAllUsers: $e');
//     }
//   }

//   /// DEBUG: Check enum values
//   Future<void> debugCheckEnumValues() async {
//     print('\n╔════════════════════════════════════════════════════════════╗');
//     print('║ 📋 DEBUG: Enum Values Check                                ║');
//     print('╚════════════════════════════════════════════════════════════╝\n');
    
//     print('UserRole Enum Values:');
//     print('  UserRole.user.name = "${UserRole.user.name}"');
//     print('  UserRole.volunteer.name = "${UserRole.volunteer.name}"');
    
//     print('\nVerificationStatus Enum Values:');
//     print('  VerificationStatus.unverified.name = "${VerificationStatus.unverified.name}"');
//     print('  VerificationStatus.pending.name = "${VerificationStatus.pending.name}"');
//     print('  VerificationStatus.verified.name = "${VerificationStatus.verified.name}"');
//     print('  VerificationStatus.rejected.name = "${VerificationStatus.rejected.name}"');
    
//     print('\nAppConstants:');
//     print('  volunteerSearchRadiusKm = ${AppConstants.volunteerSearchRadiusKm}');
//     print('  usersCollection = "${AppConstants.usersCollection}"');
    
//     print('\nExpected Query Conditions:');
//     print('  role == "${UserRole.volunteer.name}"');
//     print('  verificationStatus == "${VerificationStatus.verified.name}"');
//     print('  isAvailable == true');
    
//     print('\n╔════════════════════════════════════════════════════════════╗');
//     print('║ ✅ DEBUG: Enum check complete                             ║');
//     print('╚════════════════════════════════════════════════════════════╝\n');
//   }

//   ///
//   /// Returns distance in kilometers
//   ///
//   /// Formula:
//   /// a = sin²(Δφ/2) + cos(φ1) * cos(φ2) * sin²(Δλ/2)
//   /// c = 2 * atan2(√a, √(1−a))
//   /// d = R * c
//   ///
//   /// where:
//   /// φ is latitude, λ is longitude, R is earth's radius (≈6371 km)
//   double _calculateHaversineDistance(
//     double startLatitude,
//     double startLongitude,
//     double endLatitude,
//     double endLongitude,
//   ) {
//     const earthRadiusKm = 6371.0;

//     // Convert degrees to radians
//     final dLat = _toRadians(endLatitude - startLatitude);
//     final dLng = _toRadians(endLongitude - startLongitude);

//     final lat1 = _toRadians(startLatitude);
//     final lat2 = _toRadians(endLatitude);

//     // Haversine formula
//     final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
//         math.sin(dLng / 2) *
//             math.sin(dLng / 2) *
//             math.cos(lat1) *
//             math.cos(lat2);

//     final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

//     return earthRadiusKm * c;
//   }

//   /// Convert degrees to radians
//   double _toRadians(double degrees) {
//     return degrees * math.pi / 180;
//   }

//   /// Get distance between user and volunteer in km
//   Future<double> getDistanceToVolunteer(
//     LatLng userLocation,
//     GeoPoint volunteerLocation,
//   ) async {
//     return _calculateHaversineDistance(
//       userLocation.latitude,
//       userLocation.longitude,
//       volunteerLocation.latitude,
//       volunteerLocation.longitude,
//     );
//   }

//   /// Check if a user has already sent a request to a volunteer
//   ///
//   /// Returns true if there's an active (non-rejected, non-expired) request
//   Future<bool> hasActiveRequestToVolunteer(
//     String userId,
//     String volunteerId,
//   ) async {
//     try {
//       final snapshot = await db
//           .collection(_walkingRequestsCollection)
//           .where('requesterId', isEqualTo: userId)
//           .where('volunteerId', isEqualTo: volunteerId)
//           .where('status', whereIn: ['pending', 'accepted']).get();

//       return snapshot.docs.isNotEmpty;
//     } catch (e) {
//       print('Error checking duplicate request: $e');
//       return false;
//     }
//   }

//   /// Stream volunteers that match search criteria in real-time
//   ///
//   /// Useful for monitoring volunteer availability changes
//   Stream<List<UserModel>> streamNearbyVerifiedVolunteers(LatLng userLocation) {
//     return db
//         .collection(AppConstants.usersCollection)
//         .where('role', isEqualTo: UserRole.volunteer.name)
//         .where('verificationStatus', isEqualTo: VerificationStatus.verified.name)
//         .where('isAvailable', isEqualTo: true)
//         .snapshots()
//         .asyncMap((snapshot) async {
//           final volunteers = <UserModel>[];

//           for (final doc in snapshot.docs) {
//             final volunteer = UserModel.fromJson(doc.data());

//             if (volunteer.currentLocation == null) continue;

//             final distance = _calculateHaversineDistance(
//               userLocation.latitude,
//               userLocation.longitude,
//               volunteer.currentLocation!.latitude,
//               volunteer.currentLocation!.longitude,
//             );

//             if (distance <= AppConstants.volunteerSearchRadiusKm) {
//               volunteers.add(volunteer);
//             }
//           }

//           // Sort by distance
//           volunteers.sort((a, b) {
//             final distanceA = _calculateHaversineDistance(
//               userLocation.latitude,
//               userLocation.longitude,
//               a.currentLocation!.latitude,
//               a.currentLocation!.longitude,
//             );
//             final distanceB = _calculateHaversineDistance(
//               userLocation.latitude,
//               userLocation.longitude,
//               b.currentLocation!.latitude,
//               b.currentLocation!.longitude,
//             );
//             return distanceA.compareTo(distanceB);
//           });

//           return volunteers;
//         });
//   }

//   /// Get all verified volunteers (no distance filter)
//   ///
//   /// Useful for admin dashboards or volunteer management
//   Future<List<UserModel>> getAllVerifiedVolunteers() async {
//     try {
//       final snapshot = await db
//           .collection(AppConstants.usersCollection)
//           .where('role', isEqualTo: UserRole.volunteer.name)
//           .where('verificationStatus', isEqualTo: VerificationStatus.verified.name)
//           .get();

//       return snapshot.docs
//           .map((doc) => UserModel.fromJson(doc.data()))
//           .toList();
//     } catch (e) {
//       print('Error fetching all verified volunteers: $e');
//       rethrow;
//     }
//   }

//   /// Stream of available & verified volunteers using exact Firestore field names
//   /// Query:
//   /// .where('role', isEqualTo: 'volunteer')
//   /// .where('verifiedStatus', isEqualTo: true)
//   /// .where('isAvailable', isEqualTo: true)
//   Stream<List<UserModel>> getAvailableVolunteers() {
//     // DEBUG: Fetch all users once and print to help debugging
//     db.collection(AppConstants.usersCollection).get().then((snapshot) {
//       try {
//         print('TOTAL USERS: ${snapshot.docs.length}');
//         print(snapshot.docs.map((d) => d.data()).toList());
//       } catch (_) {}
//     }).catchError((e) {
//       print('DEBUG fetch all users error: $e');
//     });

//     final currentUid = FirebaseAuth.instance.currentUser?.uid;

//     return db
//         .collection(AppConstants.usersCollection)
//         .where('role', isEqualTo: 'volunteer')
//         .where('verifiedStatus', isEqualTo: true)
//         .where('isAvailable', isEqualTo: true)
//         .snapshots()
//         .map((snapshot) {
//       final list = <UserModel>[];
//       for (final doc in snapshot.docs) {
//         final raw = doc.data() as Map<String, dynamic>;
//         final data = Map<String, dynamic>.from(raw);
//         if (!data.containsKey('uid') || data['uid'] == null) {
//           data['uid'] = doc.id;
//         }

//         try {
//           final user = UserModel.fromJson(data);
//           if (currentUid != null && user.uid == currentUid) continue; // exclude self
//           list.add(user);
//         } catch (e) {
//           // skip malformed
//         }
//       }
//       return list;
//     });
//   }

//   /// Fetch volunteers where role==volunteer, isVerified==true, isAvailable==true
//   /// No distance filtering — returns all matching volunteers.
//   Future<List<UserModel>> fetchVerifiedAvailableVolunteers() async {
//     try {
//       final snapshot = await db
//           .collection(AppConstants.usersCollection)
//           .where('role', isEqualTo: UserRole.volunteer.name)
//           .where('isVerified', isEqualTo: true)
//           .where('isAvailable', isEqualTo: true)
//           .get();

//       return snapshot.docs.map((doc) => UserModel.fromJson(doc.data())).toList();
//     } catch (e) {
//       print('Error fetching verified available volunteers: $e');
//       rethrow;
//     }
//   }

//   /// Get volunteer count nearby (for UI feedback)
//   Future<int> countNearbyVerifiedVolunteers(LatLng userLocation) async {
//     final volunteers = await fetchNearbyVerifiedVolunteers(userLocation);
//     return volunteers.length;
//   }
// }


Future<List<UserModel>> fetchNearbyVerifiedVolunteers(LatLng userLocation) async {
  try {
    final db = FirebaseFirestore.instance;
    final snapshot = await db
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: 'volunteer')
        .where('verificationStatus', isEqualTo: 'verified')
        .where('isAvailable', isEqualTo: true)
        .get();

    final volunteers = snapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] ??= doc.id;
      return UserModel.fromJson(data);
    }).toList();

    return volunteers;
  } catch (e) {
    print('Error fetching volunteers: $e');
    rethrow;
  }
}
