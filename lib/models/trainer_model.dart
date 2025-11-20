import 'package:cloud_firestore/cloud_firestore.dart';

class TrainerModel {
  final String id;
  final String userId;
  final String bio;
  final List<String> expertise;
  final List<String> certifications;
  final List<String> videoUrls;
  final double hourlyRate;
  final double rating;
  final int clients;
  final double totalEarnings;
  final bool verified;
  final Map<String, dynamic>? availability;

  TrainerModel({
    required this.id,
    required this.userId,
    required this.bio,
    required this.expertise,
    required this.certifications,
    required this.videoUrls,
    required this.hourlyRate,
    required this.rating,
    required this.clients,
    required this.totalEarnings,
    required this.verified,
    this.availability,
  });

  factory TrainerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TrainerModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      bio: data['bio'] ?? '',
      expertise: List<String>.from(data['expertise'] ?? []),
      certifications: List<String>.from(data['certifications'] ?? []),
      videoUrls: List<String>.from(data['videoUrls'] ?? []),
      hourlyRate: (data['hourlyRate'] ?? 0.0).toDouble(),
      rating: (data['rating'] ?? 0.0).toDouble(),
      clients: data['clients'] ?? 0,
      totalEarnings: (data['totalEarnings'] ?? 0.0).toDouble(),
      verified: data['verified'] ?? false,
      availability: data['availability'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'bio': bio,
      'expertise': expertise,
      'certifications': certifications,
      'videoUrls': videoUrls,
      'hourlyRate': hourlyRate,
      'rating': rating,
      'clients': clients,
      'totalEarnings': totalEarnings,
      'verified': verified,
      'availability': availability,
    };
  }

  TrainerModel copyWith({
    String? id,
    String? userId,
    String? bio,
    List<String>? expertise,
    List<String>? certifications,
    List<String>? videoUrls,
    double? hourlyRate,
    double? rating,
    int? clients,
    double? totalEarnings,
    bool? verified,
    Map<String, dynamic>? availability,
  }) {
    return TrainerModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bio: bio ?? this.bio,
      expertise: expertise ?? this.expertise,
      certifications: certifications ?? this.certifications,
      videoUrls: videoUrls ?? this.videoUrls,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      rating: rating ?? this.rating,
      clients: clients ?? this.clients,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      verified: verified ?? this.verified,
      availability: availability ?? this.availability,
    );
  }
}
