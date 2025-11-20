import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { client, trainer, admin }

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final UserRole role;
  final DateTime createdAt;
  final String status; // active or suspended

  // Client-specific fields
  final String? goals; // fitness, weightGain, weightLoss
  final Map<String, dynamic>? preferences;

  // Trainer-specific fields
  final List<String>? expertise;
  final double? rating;
  final double? hourlyRate;
  final bool? verified;
  final List<String>? certifications;
  final List<String>? videoUrls;
  final int? clients;
  final double? totalEarnings;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    required this.role,
    required this.createdAt,
    this.status = 'active',
    this.goals,
    this.preferences,
    this.expertise,
    this.rating,
    this.hourlyRate,
    this.verified,
    this.certifications,
    this.videoUrls,
    this.clients,
    this.totalEarnings,
  });

  // Convert UserRole enum to string
  static String roleToString(UserRole role) {
    switch (role) {
      case UserRole.client:
        return 'client';
      case UserRole.trainer:
        return 'trainer';
      case UserRole.admin:
        return 'admin';
    }
  }

  // Convert string to UserRole enum
  static UserRole stringToRole(String role) {
    switch (role.toLowerCase()) {
      case 'client':
        return UserRole.client;
      case 'trainer':
        return UserRole.trainer;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.client;
    }
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'role': roleToString(role),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      if (role == UserRole.client) ...{
        'goals': goals,
        'preferences': preferences ?? {},
      },
      if (role == UserRole.trainer) ...{
        'expertise': expertise ?? [],
        'rating': rating ?? 0.0,
        'hourlyRate': hourlyRate ?? 0.0,
        'verified': verified ?? false,
        'certifications': certifications ?? [],
        'videoUrls': videoUrls ?? [],
        'clients': clients ?? 0,
        'totalEarnings': totalEarnings ?? 0.0,
      },
    };
  }

  // Create UserModel from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      avatarUrl: map['avatarUrl'],
      role: stringToRole(map['role'] ?? 'client'),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: map['status'] ?? 'active',
      goals: map['goals'],
      preferences: map['preferences'],
      expertise: map['expertise'] != null
          ? List<String>.from(map['expertise'])
          : null,
      rating: map['rating']?.toDouble(),
      hourlyRate: map['hourlyRate']?.toDouble(),
      verified: map['verified'],
      certifications: map['certifications'] != null
          ? List<String>.from(map['certifications'])
          : null,
      videoUrls: map['videoUrls'] != null
          ? List<String>.from(map['videoUrls'])
          : null,
      clients: map['clients'],
      totalEarnings: map['totalEarnings']?.toDouble(),
    );
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    UserRole? role,
    DateTime? createdAt,
    String? status,
    String? goals,
    Map<String, dynamic>? preferences,
    List<String>? expertise,
    double? rating,
    double? hourlyRate,
    bool? verified,
    List<String>? certifications,
    List<String>? videoUrls,
    int? clients,
    double? totalEarnings,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      goals: goals ?? this.goals,
      preferences: preferences ?? this.preferences,
      expertise: expertise ?? this.expertise,
      rating: rating ?? this.rating,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      verified: verified ?? this.verified,
      certifications: certifications ?? this.certifications,
      videoUrls: videoUrls ?? this.videoUrls,
      clients: clients ?? this.clients,
      totalEarnings: totalEarnings ?? this.totalEarnings,
    );
  }

  bool get isClient => role == UserRole.client;
  bool get isTrainer => role == UserRole.trainer;
  bool get isAdmin => role == UserRole.admin;
  bool get isActive => status == 'active';
}
