class CatProfile {
  final String id;
  final String name;
  final String? photoPath;
  final String? breed;

  const CatProfile({
    required this.id,
    required this.name,
    this.photoPath,
    this.breed,
  });

  CatProfile copyWith({
    String? id,
    String? name,
    String? photoPath,
    String? breed,
  }) {
    return CatProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      breed: breed ?? this.breed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'photoPath': photoPath,
    'breed': breed,
  };

  factory CatProfile.fromJson(Map<String, dynamic> json) {
    return CatProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      photoPath: json['photoPath'] as String?,
      breed: json['breed'] as String?,
    );
  }
}
