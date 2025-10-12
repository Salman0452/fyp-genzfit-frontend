class TrainerModel {
  final String id;
  final String name;
  final String specialization;
  final String experience;
  final double rating;
  final int reviewCount;
  final String price;
  final String? imageUrl;
  final List<String> certifications;
  final int availableSlots;
  final String? bio;
  final List<String>? specializations;

  TrainerModel({
    required this.id,
    required this.name,
    required this.specialization,
    required this.experience,
    required this.rating,
    required this.reviewCount,
    required this.price,
    this.imageUrl,
    required this.certifications,
    required this.availableSlots,
    this.bio,
    this.specializations,
  });

  // Convert from JSON (for API response)
  factory TrainerModel.fromJson(Map<String, dynamic> json) {
    return TrainerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      specialization: json['specialization'] as String,
      experience: json['experience'] as String,
      rating: (json['rating'] as num).toDouble(),
      reviewCount: json['reviewCount'] as int,
      price: json['price'] as String,
      imageUrl: json['imageUrl'] as String?,
      certifications: (json['certifications'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      availableSlots: json['availableSlots'] as int,
      bio: json['bio'] as String?,
      specializations: json['specializations'] != null
          ? (json['specializations'] as List<dynamic>)
              .map((e) => e as String)
              .toList()
          : null,
    );
  }

  // Convert to JSON (for API request)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'specialization': specialization,
      'experience': experience,
      'rating': rating,
      'reviewCount': reviewCount,
      'price': price,
      'imageUrl': imageUrl,
      'certifications': certifications,
      'availableSlots': availableSlots,
      'bio': bio,
      'specializations': specializations,
    };
  }

  // Convert to Map for route arguments
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'specialization': specialization,
      'experience': experience,
      'rating': rating,
      'reviewCount': reviewCount,
      'price': price,
      'image': imageUrl,
      'certifications': certifications,
      'availableSlots': availableSlots,
    };
  }

  // Create a copy with modified fields
  TrainerModel copyWith({
    String? id,
    String? name,
    String? specialization,
    String? experience,
    double? rating,
    int? reviewCount,
    String? price,
    String? imageUrl,
    List<String>? certifications,
    int? availableSlots,
    String? bio,
    List<String>? specializations,
  }) {
    return TrainerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      specialization: specialization ?? this.specialization,
      experience: experience ?? this.experience,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      certifications: certifications ?? this.certifications,
      availableSlots: availableSlots ?? this.availableSlots,
      bio: bio ?? this.bio,
      specializations: specializations ?? this.specializations,
    );
  }
}
