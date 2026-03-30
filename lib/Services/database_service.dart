import 'dart:convert';
import 'dart:io';

import 'package:reins/Constants/constants.dart';
import 'package:reins/Models/chatbot_profile.dart';
import 'package:reins/Models/chat_model_provider.dart';
import 'package:reins/Models/ollama_chat.dart';
import 'package:reins/Models/ollama_message.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

class DatabaseService {
  late Database _db;

  Future<String> getDatabasesPathForPlatform() async {
    if (Platform.isLinux) {
      return PathManager.instance.documentsDirectory.path;
    } else {
      return await getDatabasesPath();
    }
  }

  Future<void> open(String databaseFile) async {
    _db = await openDatabase(
      path.join(await getDatabasesPathForPlatform(), databaseFile),
      version: 5,
      onCreate: (Database db, int version) async {
        await db.execute('''CREATE TABLE IF NOT EXISTS chats (
chat_id TEXT PRIMARY KEY,
model TEXT NOT NULL,
provider TEXT NOT NULL DEFAULT 'ollama',
chat_title TEXT NOT NULL,
system_prompt TEXT,
options TEXT,
profile_id TEXT
) WITHOUT ROWID;''');

        await db.execute('''CREATE TABLE IF NOT EXISTS messages (
message_id TEXT PRIMARY KEY,
chat_id TEXT NOT NULL,
content TEXT NOT NULL,
images TEXT,
role TEXT CHECK(role IN ('user', 'assistant', 'system')) NOT NULL,
timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
FOREIGN KEY (chat_id) REFERENCES chats(chat_id) ON DELETE CASCADE
) WITHOUT ROWID;''');

        // Create cleanup_jobs table
        await db.execute('''CREATE TABLE IF NOT EXISTS cleanup_jobs (
id INTEGER PRIMARY KEY AUTOINCREMENT,
image_paths TEXT NOT NULL
)''');

        // Create trigger to handle image deletion
        await db.execute('''CREATE TRIGGER IF NOT EXISTS delete_images_trigger
AFTER DELETE ON messages
WHEN OLD.images IS NOT NULL
BEGIN
  INSERT INTO cleanup_jobs (image_paths) VALUES (OLD.images);
END;''');

        await _createChatbotProfilesTable(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE chats ADD COLUMN profile_id TEXT;');
          await _createChatbotProfilesTable(db);
        }
        if (oldVersion >= 2 && oldVersion < 3) {
          await db.execute('ALTER TABLE chatbot_profiles ADD COLUMN speaking_style TEXT;');
          await db.execute('ALTER TABLE chatbot_profiles ADD COLUMN tone TEXT;');
          await db.execute('ALTER TABLE chatbot_profiles ADD COLUMN interests TEXT;');
          await db.execute('ALTER TABLE chatbot_profiles ADD COLUMN backstory TEXT;');
          await db.execute('ALTER TABLE chatbot_profiles ADD COLUMN relationship_to_user TEXT;');
          await db.execute('ALTER TABLE chatbot_profiles ADD COLUMN goals TEXT;');
          await db.execute('ALTER TABLE chatbot_profiles ADD COLUMN boundaries TEXT;');
          await db.execute('ALTER TABLE chatbot_profiles ADD COLUMN quirks TEXT;');
          await db.execute('ALTER TABLE chatbot_profiles ADD COLUMN catchphrases TEXT;');
        }
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE chats ADD COLUMN provider TEXT NOT NULL DEFAULT 'ollama';");
        }
        if (oldVersion < 5) {
          await db.execute("ALTER TABLE chatbot_profiles ADD COLUMN is_locked INTEGER NOT NULL DEFAULT 0;");
        }
      },
    );

    await ensureBuiltInProfiles();
  }

  Future<void> _createChatbotProfilesTable(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS chatbot_profiles (
profile_id TEXT PRIMARY KEY,
name TEXT NOT NULL,
age INTEGER,
profession TEXT NOT NULL,
bio TEXT NOT NULL,
traits TEXT,
speaking_style TEXT,
tone TEXT,
interests TEXT,
backstory TEXT,
relationship_to_user TEXT,
goals TEXT,
boundaries TEXT,
quirks TEXT,
catchphrases TEXT,
avatar_path TEXT,
is_default INTEGER NOT NULL DEFAULT 0,
is_locked INTEGER NOT NULL DEFAULT 0,
created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
) WITHOUT ROWID;''');
  }

  Future<void> close() async => _db.close();

  // Chat Operations

  Future<OllamaChat> createChat(
    String model, {
    ChatModelProvider provider = ChatModelProvider.ollama,
    String? systemPrompt,
    String? profileId,
  }) async {
    final id = Uuid().v4();

    await _db.insert('chats', {
      'chat_id': id,
      'model': model,
      'provider': provider.value,
      'chat_title': 'New Chat',
      'system_prompt': systemPrompt,
      'options': null,
      'profile_id': profileId,
    });

    return (await getChat(id))!;
  }

  Future<OllamaChat?> getChat(String chatId) async {
    final List<Map<String, dynamic>> maps = await _db.query('chats', where: 'chat_id = ?', whereArgs: [chatId]);

    if (maps.isEmpty) {
      return null;
    } else {
      return OllamaChat.fromMap(maps.first);
    }
  }

  Future<void> updateChat(
    OllamaChat chat, {
    String? newModel,
    ChatModelProvider? newProvider,
    String? newTitle,
    String? newSystemPrompt,
    OllamaChatOptions? newOptions,
    String? newProfileId,
  }) async {
    await _db.update(
      'chats',
      {
        'model': newModel ?? chat.model,
        'provider': (newProvider ?? chat.provider).value,
        'chat_title': newTitle ?? chat.title,
        'system_prompt': newSystemPrompt ?? chat.systemPrompt,
        'options': newOptions?.toJson() ?? chat.options.toJson(),
        'profile_id': newProfileId ?? chat.profileId,
      },
      where: 'chat_id = ?',
      whereArgs: [chat.id],
    );
  }

  Future<void> deleteChat(String chatId) async {
    await _db.delete('chats', where: 'chat_id = ?', whereArgs: [chatId]);

    await _db.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);

    // ? Should we run with Isolate.run?
    _cleanupDeletedImages();
  }

  Future<List<OllamaChat>> getAllChats() async {
    final List<Map<String, dynamic>> maps = await _db.rawQuery(
      '''SELECT chats.chat_id, chats.model, chats.provider, chats.chat_title, chats.system_prompt, chats.options, chats.profile_id, MAX(messages.timestamp) AS last_update
FROM chats
LEFT JOIN messages ON chats.chat_id = messages.chat_id
GROUP BY chats.chat_id
ORDER BY last_update DESC;''',
    );

    return List.generate(maps.length, (i) {
      return OllamaChat.fromMap(maps[i]);
    });
  }

  // Chatbot Profile Operations

  Future<ChatbotProfile> createChatbotProfile(ChatbotProfile profile, {bool isDefault = false}) async {
    await _db.transaction((txn) async {
      if (isDefault) {
        await _clearDefaultProfile(txn);
      }

      await txn.insert('chatbot_profiles', profile.toDatabaseMap(isDefault: isDefault));
    });

    return (await getChatbotProfile(profile.id))!;
  }

  Future<ChatbotProfile?> getChatbotProfile(String profileId) async {
    final maps = await _db.query('chatbot_profiles', where: 'profile_id = ?', whereArgs: [profileId], limit: 1);

    if (maps.isEmpty) {
      return null;
    }

    return ChatbotProfile.fromMap(maps.first);
  }

  Future<List<ChatbotProfile>> getAllChatbotProfiles() async {
    final maps = await _db.query('chatbot_profiles', orderBy: 'is_default DESC, updated_at DESC');

    return maps.map(ChatbotProfile.fromMap).toList();
  }

  Future<void> ensureBuiltInProfiles() async {
    final builtInProfile = ChatbotProfile.builtInOllama();
    final existing = await _db.query(
      'chatbot_profiles',
      columns: ['profile_id', 'is_default'],
      where: 'profile_id = ?',
      whereArgs: [builtInProfile.id],
      limit: 1,
    );

    await _db.transaction((txn) async {
      if (existing.isEmpty) {
        await _clearDefaultProfile(txn);
        await txn.insert('chatbot_profiles', builtInProfile.toDatabaseMap(isDefault: true, includeTimestamps: true));
        return;
      }

      final shouldRemainDefault = (existing.first['is_default'] as int? ?? 0) == 1;
      await txn.update(
        'chatbot_profiles',
        builtInProfile.toDatabaseMap(isDefault: shouldRemainDefault, includeTimestamps: true),
        where: 'profile_id = ?',
        whereArgs: [builtInProfile.id],
      );
    });
  }

  Future<void> updateChatbotProfile(ChatbotProfile profile, {bool? isDefault}) async {
    final existing = await getChatbotProfile(profile.id);
    if (existing == null) return;
    if (existing.isLocked) {
      throw StateError('This profile is locked and cannot be customized.');
    }

    await _db.transaction((txn) async {
      if (isDefault == true) {
        await _clearDefaultProfile(txn);
      }

      await txn.update(
        'chatbot_profiles',
        profile.toDatabaseMap(isDefault: isDefault ?? profile.isDefault, includeTimestamps: true),
        where: 'profile_id = ?',
        whereArgs: [profile.id],
      );
    });
  }

  Future<void> setDefaultChatbotProfile(String profileId) async {
    await _db.transaction((txn) async {
      await _clearDefaultProfile(txn);
      await txn.update(
        'chatbot_profiles',
        {'is_default': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
    });
  }

  Future<ChatbotProfile?> getDefaultChatbotProfile() async {
    final maps = await _db.query('chatbot_profiles', where: 'is_default = ?', whereArgs: [1], limit: 1);

    if (maps.isEmpty) {
      return null;
    }

    return ChatbotProfile.fromMap(maps.first);
  }

  Future<void> deleteChatbotProfile(String profileId) async {
    final existing = await getChatbotProfile(profileId);
    if (existing == null || existing.isLocked) {
      return;
    }

    await _db.transaction((txn) async {
      await txn.delete('chatbot_profiles', where: 'profile_id = ?', whereArgs: [profileId]);

      await txn.update('chats', {'profile_id': null}, where: 'profile_id = ?', whereArgs: [profileId]);
    });
  }

  Future<void> _clearDefaultProfile(Transaction txn) async {
    await txn.update(
      'chatbot_profiles',
      {'is_default': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'is_default = ?',
      whereArgs: [1],
    );
  }

  // Message Operations

  Future<void> addMessage(OllamaMessage message, {required OllamaChat chat}) async {
    await _db.insert('messages', {'chat_id': chat.id, ...message.toDatabaseMap()});
  }

  Future<OllamaMessage?> getMessage(String messageId) async {
    final List<Map<String, dynamic>> maps = await _db.query(
      'messages',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );

    if (maps.isEmpty) {
      return null;
    } else {
      return OllamaMessage.fromDatabase(maps.first);
    }
  }

  Future<void> updateMessage(OllamaMessage message, {String? newContent}) async {
    await _db.update(
      'messages',
      {'content': newContent ?? message.content},
      where: 'message_id = ?',
      whereArgs: [message.id],
    );
  }

  Future<void> deleteMessage(String messageId) async {
    await _db.delete('messages', where: 'message_id = ?', whereArgs: [messageId]);

    _cleanupDeletedImages();
  }

  Future<List<OllamaMessage>> getMessages(String chatId) async {
    final List<Map<String, dynamic>> maps = await _db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return OllamaMessage.fromDatabase(maps[i]);
    });
  }

  Future<void> deleteMessages(List<OllamaMessage> messages) async {
    await _db.transaction((txn) async {
      for (final message in messages) {
        await txn.delete('messages', where: 'message_id = ?', whereArgs: [message.id]);
      }
    });

    _cleanupDeletedImages();
  }

  // ? Should we trigger this cleanup on every message deletion?
  // ? Or should we run it on every app start?
  Future<void> _cleanupDeletedImages() async {
    final List<Map<String, dynamic>> results = await _db.query(
      'cleanup_jobs',
      columns: ['id', 'image_paths'],
      where: 'image_paths IS NOT NULL',
    );

    for (final result in results) {
      try {
        final images = _constructImages(result['image_paths']);
        if (images == null) continue;

        for (final image in images) {
          if (await image.exists()) {
            await image.delete();
          }
        }

        // Delete the row after images are deleted
        await _db.delete('cleanup_jobs', where: 'id = ?', whereArgs: [result['id']]);
      } catch (_) {}
    }
  }

  static List<File>? _constructImages(String? raw) {
    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((imageRelativePath) {
        return File(path.join(PathManager.instance.documentsDirectory.path, imageRelativePath));
      }).toList();
    }

    return null;
  }
}
