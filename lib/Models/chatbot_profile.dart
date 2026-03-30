import 'package:uuid/uuid.dart';

/// Represents a reusable chatbot persona profile.
class ChatbotProfile {
  final String id;
  final String name;
  final int? age;
  final String profession;
  final String bio;
  final String? traits;
  final String? speakingStyle;
  final String? tone;
  final String? interests;
  final String? backstory;
  final String? relationshipToUser;
  final String? goals;
  final String? boundaries;
  final String? quirks;
  final String? catchphrases;
  final String? avatarPath;
  final bool isDefault;

  ChatbotProfile({
    String? id,
    required this.name,
    required this.age,
    required this.profession,
    required this.bio,
    this.traits,
    this.speakingStyle,
    this.tone,
    this.interests,
    this.backstory,
    this.relationshipToUser,
    this.goals,
    this.boundaries,
    this.quirks,
    this.catchphrases,
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
      speakingStyle: map['speaking_style'] as String?,
      tone: map['tone'] as String?,
      interests: map['interests'] as String?,
      backstory: map['backstory'] as String?,
      relationshipToUser: map['relationship_to_user'] as String?,
      goals: map['goals'] as String?,
      boundaries: map['boundaries'] as String?,
      quirks: map['quirks'] as String?,
      catchphrases: map['catchphrases'] as String?,
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
      if (speakingStyle != null && speakingStyle!.trim().isNotEmpty) 'Speaking style: ${speakingStyle!.trim()}',
      if (tone != null && tone!.trim().isNotEmpty) 'Tone: ${tone!.trim()}',
      if (interests != null && interests!.trim().isNotEmpty) 'Interests: ${interests!.trim()}',
      if (backstory != null && backstory!.trim().isNotEmpty) 'Backstory: ${backstory!.trim()}',
      if (relationshipToUser != null && relationshipToUser!.trim().isNotEmpty)
        'Relationship to user: ${relationshipToUser!.trim()}',
      if (goals != null && goals!.trim().isNotEmpty) 'Goals: ${goals!.trim()}',
      if (boundaries != null && boundaries!.trim().isNotEmpty) 'Boundaries: ${boundaries!.trim()}',
      if (quirks != null && quirks!.trim().isNotEmpty) 'Quirks: ${quirks!.trim()}',
      if (catchphrases != null && catchphrases!.trim().isNotEmpty) 'Catchphrases: ${catchphrases!.trim()}',
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
      'speaking_style': speakingStyle?.trim().isEmpty == true ? null : speakingStyle?.trim(),
      'tone': tone?.trim().isEmpty == true ? null : tone?.trim(),
      'interests': interests?.trim().isEmpty == true ? null : interests?.trim(),
      'backstory': backstory?.trim().isEmpty == true ? null : backstory?.trim(),
      'relationship_to_user': relationshipToUser?.trim().isEmpty == true ? null : relationshipToUser?.trim(),
      'goals': goals?.trim().isEmpty == true ? null : goals?.trim(),
      'boundaries': boundaries?.trim().isEmpty == true ? null : boundaries?.trim(),
      'quirks': quirks?.trim().isEmpty == true ? null : quirks?.trim(),
      'catchphrases': catchphrases?.trim().isEmpty == true ? null : catchphrases?.trim(),
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
    String? speakingStyle,
    bool clearSpeakingStyle = false,
    String? tone,
    bool clearTone = false,
    String? interests,
    bool clearInterests = false,
    String? backstory,
    bool clearBackstory = false,
    String? relationshipToUser,
    bool clearRelationshipToUser = false,
    String? goals,
    bool clearGoals = false,
    String? boundaries,
    bool clearBoundaries = false,
    String? quirks,
    bool clearQuirks = false,
    String? catchphrases,
    bool clearCatchphrases = false,
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
      speakingStyle: clearSpeakingStyle ? null : (speakingStyle ?? this.speakingStyle),
      tone: clearTone ? null : (tone ?? this.tone),
      interests: clearInterests ? null : (interests ?? this.interests),
      backstory: clearBackstory ? null : (backstory ?? this.backstory),
      relationshipToUser: clearRelationshipToUser ? null : (relationshipToUser ?? this.relationshipToUser),
      goals: clearGoals ? null : (goals ?? this.goals),
      boundaries: clearBoundaries ? null : (boundaries ?? this.boundaries),
      quirks: clearQuirks ? null : (quirks ?? this.quirks),
      catchphrases: clearCatchphrases ? null : (catchphrases ?? this.catchphrases),
      avatarPath: clearAvatarPath ? null : (avatarPath ?? this.avatarPath),
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
