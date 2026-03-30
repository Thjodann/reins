import 'package:flutter_test/flutter_test.dart';
import 'package:reins/Models/chatbot_profile.dart';

void main() {
  test('ChatbotProfile.toSystemPrompt builds deterministic ordered prompt', () {
    final profile = ChatbotProfile(
      id: 'profile-1',
      name: 'Rhea',
      age: 32,
      profession: 'Therapist',
      bio: 'Grounded and practical.',
      traits: 'Empathetic, calm',
      speakingStyle: 'Short and clear',
      tone: 'Warm',
      interests: 'Journaling',
      backstory: 'Former educator',
      relationshipToUser: 'Coach',
      goals: 'Reduce overwhelm',
      boundaries: 'No medical advice',
      quirks: 'Uses reflective questions',
      catchphrases: 'Let us reset.',
    );

    final prompt = profile.toSystemPrompt();
    final lines = prompt.split('\n');

    expect(
      lines,
      equals([
        'You are role-playing this chatbot profile.',
        'Name: Rhea',
        'Age: 32',
        'Profession: Therapist',
        'Biography: Grounded and practical.',
        'Traits: Empathetic, calm',
        'Speaking style: Short and clear',
        'Tone: Warm',
        'Interests: Journaling',
        'Backstory: Former educator',
        'Relationship to user: Coach',
        'Goals: Reduce overwhelm',
        'Boundaries: No medical advice',
        'Quirks: Uses reflective questions',
        'Catchphrases: Let us reset.',
        'Stay in character while being helpful, honest, and safe.',
      ]),
    );
  });

  test('ChatbotProfile.toDatabaseMap trims and normalizes optional text', () {
    final profile = ChatbotProfile(
      id: 'profile-2',
      name: '  Nova  ',
      age: 29,
      profession: '  Engineer  ',
      bio: '  Clear and practical.  ',
      traits: ' ',
      speakingStyle: '  concise  ',
      tone: '',
      avatarPath: 'avatars/nova.jpg',
      isDefault: false,
    );

    final databaseMap = profile.toDatabaseMap(isDefault: true, includeTimestamps: true);

    expect(databaseMap['profile_id'], 'profile-2');
    expect(databaseMap['name'], 'Nova');
    expect(databaseMap['profession'], 'Engineer');
    expect(databaseMap['bio'], 'Clear and practical.');
    expect(databaseMap['traits'], isNull);
    expect(databaseMap['speaking_style'], 'concise');
    expect(databaseMap['tone'], isNull);
    expect(databaseMap['avatar_path'], 'avatars/nova.jpg');
    expect(databaseMap['is_default'], 1);
    expect(databaseMap['is_locked'], 0);
    expect(databaseMap['updated_at'], isNotNull);
  });

  test('ChatbotProfile.copyWith clear flags remove nullable fields', () {
    final profile = ChatbotProfile(
      id: 'profile-3',
      name: 'Kai',
      age: 40,
      profession: 'Designer',
      bio: 'Visual systems thinker.',
      traits: 'Observant',
      speakingStyle: 'Conversational',
      tone: 'Playful',
      avatarPath: 'avatars/kai.jpg',
    );

    final updated = profile.copyWith(
      clearAge: true,
      clearTraits: true,
      clearSpeakingStyle: true,
      clearTone: true,
      clearAvatarPath: true,
      goals: 'Keep things focused',
    );

    expect(updated.id, 'profile-3');
    expect(updated.name, 'Kai');
    expect(updated.age, isNull);
    expect(updated.traits, isNull);
    expect(updated.speakingStyle, isNull);
    expect(updated.tone, isNull);
    expect(updated.avatarPath, isNull);
    expect(updated.goals, 'Keep things focused');
  });

  test('ChatbotProfile.builtInOllama produces a locked built-in profile', () {
    final profile = ChatbotProfile.builtInOllama();

    expect(profile.id, ChatbotProfile.builtInOllamaProfileId);
    expect(profile.avatarPath, ChatbotProfile.builtInOllamaAvatarAssetPath);
    expect(profile.isDefault, isTrue);
    expect(profile.isLocked, isTrue);
  });
}
