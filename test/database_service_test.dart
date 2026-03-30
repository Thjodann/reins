import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reins/Constants/constants.dart';
import 'package:reins/Models/chatbot_profile.dart';
import 'package:reins/Models/ollama_chat.dart';
import 'package:reins/Models/ollama_message.dart';
import 'package:reins/Services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  PathProviderPlatform.instance = FakePathProviderPlatform();
  await PathManager.initialize();

  final databasePath = path.join(await getDatabasesPath(), 'test_database.db');
  await databaseFactoryFfi.deleteDatabase(databasePath);

  final service = DatabaseService();
  await service.open('test_database.db');

  const model = "llama3.2";

  final assetsPath = path.join(Directory.current.path, 'test', 'assets');
  final imageFile = File(path.join(assetsPath, 'images', 'ollama.png'));

  test("Test database open", () async {
    await service.open('test_database.db');
  });

  test("Test database create chat", () async {
    final chat = await service.createChat(model);

    expect(chat.id, isNotEmpty);
    expect(chat.model, model);
    expect(chat.title, "New Chat");
    expect(chat.systemPrompt, isNull);
    expect(chat.options.toJson(), OllamaChatOptions().toJson());
  });

  test("Test database get chat", () async {
    final chat = await service.createChat(model);

    final retrievedChat = (await service.getChat(chat.id))!;
    expect(retrievedChat.id, chat.id);
    expect(retrievedChat.model, chat.model);
    expect(retrievedChat.title, chat.title);
    expect(retrievedChat.systemPrompt, chat.systemPrompt);
    expect(retrievedChat.options.toJson(), chat.options.toJson());
  });

  test("Test database update chat title", () async {
    final chat = await service.createChat(model);

    await service.updateChat(chat, newModel: "llama3.2");

    final updatedChat = (await service.getChat(chat.id))!;
    expect(updatedChat.model, "llama3.2");
    expect(updatedChat.title, "New Chat");
    expect(updatedChat.systemPrompt, isNull);
    expect(chat.options.toJson(), OllamaChatOptions().toJson());
  });

  test('Test database update chat system prompt', () async {
    const systemPrompt = "You are Mario from super mario bros, acting as an assistant.";

    final chat = await service.createChat(model);

    await service.updateChat(chat, newSystemPrompt: systemPrompt);

    final updatedChat = (await service.getChat(chat.id))!;
    expect(updatedChat.model, model);
    expect(updatedChat.title, "New Chat");
    expect(updatedChat.systemPrompt, systemPrompt);
    expect(chat.options.toJson(), OllamaChatOptions().toJson());

    await service.updateChat(updatedChat, newSystemPrompt: null);
  });

  test('Test database update chat options', () async {
    final chat = await service.createChat(model);

    await service.updateChat(
      chat,
      newOptions: OllamaChatOptions(
        mirostat: 1,
        mirostatEta: 0.1,
        mirostatTau: 0.1,
        contextSize: 1,
        repeatLastN: 1,
        repeatPenalty: 0.1,
        temperature: 0.1,
        seed: 1,
      ),
    );

    final updatedChat = (await service.getChat(chat.id))!;
    expect(updatedChat.model, model);
    expect(updatedChat.title, "New Chat");
    expect(updatedChat.systemPrompt, isNull);
    expect(updatedChat.options.mirostat, 1);
    expect(updatedChat.options.mirostatEta, 0.1);
    expect(updatedChat.options.mirostatTau, 0.1);
    expect(updatedChat.options.contextSize, 1);
    expect(updatedChat.options.repeatLastN, 1);
    expect(updatedChat.options.repeatPenalty, 0.1);
    expect(updatedChat.options.temperature, 0.1);
    expect(updatedChat.options.seed, 1);
  });

  test("Test database delete chat", () async {
    final chat = await service.createChat(model);

    await service.deleteChat(chat.id);

    expect(await service.getChat(chat.id), isNull);
  });

  test('Test database create and fetch chatbot profile', () async {
    final profile = ChatbotProfile(
      name: 'Test Profile',
      age: 28,
      profession: 'Engineer',
      bio: 'Helps users with concise answers.',
      traits: 'Thoughtful and pragmatic',
      speakingStyle: 'Brief and structured',
      tone: 'Calm and encouraging',
      interests: 'Systems design, automation',
      backstory: 'Former team lead turned AI companion',
      relationshipToUser: 'Collaborative copilot',
      goals: 'Keep the user focused and productive',
      boundaries: 'Avoid legal/medical certainty',
      quirks: 'Occasionally uses short checklists',
      catchphrases: 'Let us break it down.',
    );

    final created = await service.createChatbotProfile(profile, isDefault: true);
    final fetched = await service.getChatbotProfile(created.id);
    final defaultProfile = await service.getDefaultChatbotProfile();

    expect(fetched, isNotNull);
    expect(fetched!.name, 'Test Profile');
    expect(fetched.profession, 'Engineer');
    expect(fetched.speakingStyle, 'Brief and structured');
    expect(fetched.relationshipToUser, 'Collaborative copilot');
    expect(defaultProfile?.id, created.id);
  });

  test('Test database enforces a single default chatbot profile', () async {
    final first = await service.createChatbotProfile(
      ChatbotProfile(name: 'Default One', age: 30, profession: 'Writer', bio: 'First default profile.'),
      isDefault: true,
    );
    final second = await service.createChatbotProfile(
      ChatbotProfile(name: 'Default Two', age: 31, profession: 'Analyst', bio: 'Second default profile.'),
      isDefault: true,
    );

    final defaultProfile = await service.getDefaultChatbotProfile();
    final profiles = await service.getAllChatbotProfiles();
    final defaultCount = profiles.where((profile) => profile.isDefault).length;
    final firstProfile = await service.getChatbotProfile(first.id);
    final secondProfile = await service.getChatbotProfile(second.id);

    expect(defaultProfile, isNotNull);
    expect(defaultProfile!.id, second.id);
    expect(defaultCount, 1);
    expect(firstProfile, isNotNull);
    expect(firstProfile!.isDefault, isFalse);
    expect(secondProfile, isNotNull);
    expect(secondProfile!.isDefault, isTrue);
  });

  test('Test database set default chatbot profile clears previous default', () async {
    final first = await service.createChatbotProfile(
      ChatbotProfile(name: 'Alpha', age: 25, profession: 'Coach', bio: 'Encouraging persona.'),
      isDefault: true,
    );
    final second = await service.createChatbotProfile(
      ChatbotProfile(name: 'Beta', age: 26, profession: 'Mentor', bio: 'Structured helper persona.'),
    );

    await service.setDefaultChatbotProfile(second.id);

    final defaultProfile = await service.getDefaultChatbotProfile();
    final firstProfile = await service.getChatbotProfile(first.id);
    final secondProfile = await service.getChatbotProfile(second.id);

    expect(defaultProfile, isNotNull);
    expect(defaultProfile!.id, second.id);
    expect(firstProfile, isNotNull);
    expect(firstProfile!.isDefault, isFalse);
    expect(secondProfile, isNotNull);
    expect(secondProfile!.isDefault, isTrue);
  });

  test('Test database update chatbot profile trims and nulls optional text fields', () async {
    final created = await service.createChatbotProfile(
      ChatbotProfile(
        name: '  Prof  ',
        age: 27,
        profession: '  Engineer  ',
        bio: '  Builds systems.  ',
        speakingStyle: '  ',
        tone: '  warm  ',
      ),
    );

    await service.updateChatbotProfile(
      created.copyWith(
        name: '  Updated Name  ',
        profession: '  Updated Profession  ',
        bio: '  Updated Bio  ',
        traits: '  ',
        speakingStyle: '  concise  ',
        tone: '  ',
      ),
    );

    final updated = await service.getChatbotProfile(created.id);
    expect(updated, isNotNull);
    expect(updated!.name, 'Updated Name');
    expect(updated.profession, 'Updated Profession');
    expect(updated.bio, 'Updated Bio');
    expect(updated.traits, isNull);
    expect(updated.speakingStyle, 'concise');
    expect(updated.tone, isNull);
  });

  test('Test database create chat with profile linkage', () async {
    final profile = await service.createChatbotProfile(
      ChatbotProfile(name: 'Persona A', age: 35, profession: 'Therapist', bio: 'A calming and grounded assistant.'),
    );

    final chat = await service.createChat(model, profileId: profile.id, systemPrompt: profile.toSystemPrompt());

    final fetchedChat = await service.getChat(chat.id);

    expect(fetchedChat, isNotNull);
    expect(fetchedChat!.profileId, profile.id);
    expect(fetchedChat.systemPrompt, contains('Persona A'));
  });

  test('Test deleting chatbot profile clears chat profile references', () async {
    final profile = await service.createChatbotProfile(
      ChatbotProfile(name: 'Persona B', age: 22, profession: 'Designer', bio: 'Creative visual thinker.'),
    );

    final chat = await service.createChat(model, profileId: profile.id, systemPrompt: profile.toSystemPrompt());
    await service.deleteChatbotProfile(profile.id);

    final fetchedChat = await service.getChat(chat.id);
    expect(fetchedChat, isNotNull);
    expect(fetchedChat!.profileId, isNull);
  });

  test('Test database delete chat with images', () async {
    List<File> images = [];
    for (var i = 0; i < 10; i++) {
      final image = File(path.join(assetsPath, 'images', 'test_image$i.png'));
      await imageFile.copy(image.path);

      images.add(image);
    }

    final chat = await service.createChat(model);

    for (final image in images) {
      await service.addMessage(
        OllamaMessage("Hello, this is a test message.", images: [image], role: OllamaMessageRole.user),
        chat: chat,
      );
    }

    await service.deleteChat(chat.id);

    expect(await service.getChat(chat.id), isNull);
    // Wait for the images to be deleted
    await Future.delayed(Duration(seconds: 1));
    for (final image in images) {
      expect(await image.exists(), isFalse);
    }
  });

  test("Test database get all chats", () async {
    final createdChat = await service.createChat(model);
    final chats = await service.getAllChats();

    if (chats.isNotEmpty) {
      final matchingChat = chats.where((chat) => chat.id == createdChat.id).first;
      expect(matchingChat.id, isNotEmpty);
      expect(matchingChat.model, model);
      expect(matchingChat.title, "New Chat");
      expect(matchingChat.systemPrompt, isNull);
      expect(matchingChat.options.toJson(), OllamaChatOptions().toJson());
    }
  }, retry: 5);

  test("Test database add message", () async {
    final chat = await service.createChat(model);
    final message = OllamaMessage("Hello, this is a test message.", role: OllamaMessageRole.user);

    await service.addMessage(message, chat: chat);

    final messages = await service.getMessages(chat.id);
    expect(messages.length, 1);
    expect(messages.first.id, message.id);
    expect(messages.first.content, message.content);
    expect(messages.first.role, message.role);
  });

  test('Test database add message with images', () async {
    final chat = await service.createChat(model);
    final message = OllamaMessage("Hello, this is a test message.", images: [imageFile], role: OllamaMessageRole.user);

    await service.addMessage(message, chat: chat);

    final messages = await service.getMessages(chat.id);
    expect(messages.length, 1);
    expect(messages.first.id, message.id);
    expect(messages.first.content, message.content);
    expect(messages.first.images!.first.path, message.images!.first.path);
    expect(messages.first.role, message.role);
  });

  test("Test database get message", () async {
    final chat = await service.createChat(model);
    final message = OllamaMessage("Hello, this is a test message.", role: OllamaMessageRole.user);

    await service.addMessage(message, chat: chat);

    final retrievedMessage = await service.getMessage(message.id);
    expect(retrievedMessage, isNotNull);
    expect(retrievedMessage!.id, message.id);
    expect(retrievedMessage.content, message.content);
    expect(retrievedMessage.role, message.role);
  });

  test('Test database get message with images', () async {
    final chat = await service.createChat(model);
    final message = OllamaMessage("Hello, this is a test message.", images: [imageFile], role: OllamaMessageRole.user);

    await service.addMessage(message, chat: chat);

    final retrievedMessage = await service.getMessage(message.id);
    expect(retrievedMessage, isNotNull);
    expect(retrievedMessage!.id, message.id);
    expect(retrievedMessage.content, message.content);
    expect(retrievedMessage.images!.first.path, message.images!.first.path);
    expect(retrievedMessage.role, message.role);
  });

  test('Test database update message', () async {
    final chat = await service.createChat(model);

    final message = OllamaMessage("Message", role: OllamaMessageRole.user);
    await service.addMessage(message, chat: chat);

    await service.updateMessage(message, newContent: "Updated message");
    final retrievedMessage = (await service.getMessage(message.id))!;

    expect(retrievedMessage, isNotNull);
    expect(retrievedMessage.id, message.id);
    expect(retrievedMessage.content, 'Updated message');
    expect(retrievedMessage.role, message.role);
  });

  test('Test database delete message', () async {
    final chat = await service.createChat(model);
    final message = OllamaMessage("Hello, this is a test message.", role: OllamaMessageRole.user);

    await service.addMessage(message, chat: chat);
    expect(await service.getMessage(message.id), isNotNull);

    await service.deleteMessage(message.id);
    expect(await service.getMessage(message.id), isNull);
  });

  test('Test database delete message with images', () async {
    final testImagePath = path.join(assetsPath, 'images', 'test_image.png');
    await imageFile.copy(testImagePath);
    final testImageFile = File(testImagePath);

    final chat = await service.createChat(model);
    final message = OllamaMessage(
      "Hello, this is a test message.",
      images: [testImageFile],
      role: OllamaMessageRole.user,
    );

    await service.addMessage(message, chat: chat);
    expect(await service.getMessage(message.id), isNotNull);

    await service.deleteMessage(message.id);
    expect(await service.getMessage(message.id), isNull);

    // Wait for the image to be deleted
    await Future.delayed(Duration(seconds: 1));
    expect(await testImageFile.exists(), isFalse);
  });

  test("Test database get messages", () async {
    final chat = await service.createChat(model);
    final message = OllamaMessage("Hello, this is a test message.", role: OllamaMessageRole.user);

    await service.addMessage(message, chat: chat);

    final messages = await service.getMessages(chat.id);
    expect(messages.length, 1);
    expect(messages.first.id, message.id);
    expect(messages.first.content, message.content);
    expect(messages.first.role, message.role);
  });

  test("Test database delete messages", () async {
    final chat = await service.createChat(model);
    final message = OllamaMessage("Hello, this is a test message.", role: OllamaMessageRole.user);

    await service.addMessage(message, chat: chat);
    expect(await service.getMessage(message.id), isNotNull);

    await service.deleteMessages([message]);
    expect(await service.getMessage(message.id), isNull);
  });

  test('Test database delete messages with images', () async {
    List<File> images = [];
    for (var i = 0; i < 10; i++) {
      final image = File(path.join(assetsPath, 'images', 'test_image$i.png'));
      await imageFile.copy(image.path);

      images.add(image);
    }

    final chat = await service.createChat(model);

    List<OllamaMessage> messages = [];
    for (final image in images) {
      final message = OllamaMessage("Hello, this is a test message.", images: [image], role: OllamaMessageRole.user);
      await service.addMessage(message, chat: chat);
      messages.add(message);
    }

    await service.deleteMessages(messages);

    for (final message in messages) {
      expect(await service.getMessage(message.id), isNull);
    }

    // Wait for the images to be deleted
    await Future.delayed(Duration(seconds: 1));
    for (final image in images) {
      expect(await image.exists(), isFalse);
    }
  });
}

class FakePathProviderPlatform extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return path.join(Directory.current.path, 'test', 'assets');
  }
}
