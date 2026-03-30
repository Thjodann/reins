import 'package:uuid/uuid.dart';

/// Represents a reusable chatbot persona profile.
class ChatbotProfile {
  final String id;
  final String name;
  final int? age;
  final String profession;
  final String bio;
  final String? traits;
  final String? avatarPath;
  final bool isDefault;

  ChatbotProfile({
    String? id,
    required this.name,
    required this.age,
    required this.profession,
    required this.bio,
    this.traits,
    this.avatarPath,
    this.isDefault = false,
  }) : id = id ?? Uuid().v4();

  factory ChatbotProfile.fromMap(Map<String, dynamic> map) {
    return ChatbotProfile(
      id: map['profile_id'] as String,
      name: map['name'] as String,
      age: map['age'] as int?,
      profession: map['profession'] as String,
      bio: map['bio'] as String,
      traits: map['traits'] as String?,
      avatarPath: map['avatar_path'] as String?,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
    );
  }

  /// Produces a deterministic persona prompt to prepend as system prompt.
  String toSystemPrompt() {
    final sections = <String>[
      'You are role-playing this chatbot profile.',
      'Name: $name',
      if (age != null) 'Age: $age',
      'Profession: $profession',
      'Biography: $bio',
      if (traits != null && traits!.trim().isNotEmpty) 'Traits: ${traits!.trim()}',
      'Stay in character while being helpful, honest, and safe.',
    ];
    return sections.join('\n');
  }

  Map<String, dynamic> toDatabaseMap({bool? isDefault, bool includeTimestamps = false}) {
    return {
      'profile_id': id,
      'name': name.trim(),
      'age': age,
      'profession': profession.trim(),
      'bio': bio.trim(),
      'traits': traits?.trim().isEmpty == true ? null : traits?.trim(),
      'avatar_path': avatarPath,
      'is_default': (isDefault ?? this.isDefault) ? 1 : 0,
      if (includeTimestamps) 'updated_at': DateTime.now().toIso8601String(),
    };
  }

  ChatbotProfile copyWith({
    String? id,
    String? name,
    int? age,
    bool clearAge = false,
    String? profession,
    String? bio,
    String? traits,
    bool clearTraits = false,
    String? avatarPath,
    bool clearAvatarPath = false,
    bool? isDefault,
  }) {
    return ChatbotProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      age: clearAge ? null : (age ?? this.age),
      profession: profession ?? this.profession,
      bio: bio ?? this.bio,
      traits: clearTraits ? null : (traits ?? this.traits),
      avatarPath: clearAvatarPath ? null : (avatarPath ?? this.avatarPath),
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
