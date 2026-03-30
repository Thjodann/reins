import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:reins/Models/ollama_chat.dart';
import 'package:reins/Models/ollama_exception.dart';
import 'package:reins/Models/ollama_message.dart';
import 'package:reins/Utils/http_error_formatter.dart';

/// OpenAI API client for auth checks, model listing, and chat streaming.
class OpenAiService {
  final http.Client _httpClient;
  final String _baseUrl;

  OpenAiService({
    http.Client? httpClient,
    String baseUrl = 'https://api.openai.com',
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl;

  /// Verifies whether the provided OpenAI API key is valid.
  Future<void> authenticate(String apiKey) async {
    await listModels(apiKey, limit: 1);
  }

  /// Lists available OpenAI model IDs.
  Future<List<String>> listModels(
    String apiKey, {
    int? limit,
  }) async {
    try {
      final response = await _httpClient
          .get(
            _constructUrl('/v1/models'),
            headers: _headersFor(apiKey),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw OllamaException(
          HttpErrorFormatter.formatHttpError(
            response.statusCode,
            body: response.body,
          ),
        );
      }

      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (jsonBody['data'] as List<dynamic>? ?? <dynamic>[])
          .cast<Map<String, dynamic>>();

      final modelIds = data
          .map((model) => model['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList()
        ..sort();

      if (limit != null && limit >= 0 && modelIds.length > limit) {
        return modelIds.take(limit).toList();
      }

      return modelIds;
    } on OllamaException {
      rethrow;
    } catch (error) {
      throw OllamaException(HttpErrorFormatter.formatException(error));
    }
  }

  /// Streams completion chunks from OpenAI chat completions API.
  Stream<OllamaMessage> chatStream(
    List<OllamaMessage> messages, {
    required OllamaChat chat,
    required String apiKey,
  }) async* {
    try {
      final request = http.Request('POST', _constructUrl('/v1/chat/completions'));
      request.headers.addAll(_headersFor(apiKey));
      request.body = jsonEncode({
        'model': chat.model,
        'stream': true,
        'messages': await _toOpenAiMessages(
          messages,
          systemPrompt: chat.systemPrompt,
        ),
      });

      final response = await _httpClient.send(request).timeout(
            const Duration(seconds: 20),
          );
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw OllamaException(
          HttpErrorFormatter.formatHttpError(response.statusCode, body: body),
        );
      }

      await for (final chunk in _parseSseResponse(response.stream)) {
        final textDelta = _extractDeltaText(chunk);
        if (textDelta == null) {
          continue;
        }

        yield OllamaMessage(
          textDelta,
          role: OllamaMessageRole.assistant,
          model: chat.model,
        );
      }
    } on OllamaException {
      rethrow;
    } catch (error) {
      throw OllamaException(HttpErrorFormatter.formatException(error));
    }
  }

  Uri _constructUrl(String path) {
    final baseUri = Uri.parse(_baseUrl);
    return baseUri.replace(path: path);
  }

  Map<String, String> _headersFor(String apiKey) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${apiKey.trim()}',
    };
  }

  Future<List<Map<String, dynamic>>> _toOpenAiMessages(
    List<OllamaMessage> messages, {
    String? systemPrompt,
  }) async {
    final openAiMessages = <Map<String, dynamic>>[];

    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      openAiMessages.add({
        'role': 'system',
        'content': systemPrompt.trim(),
      });
    }

    for (final message in messages) {
      if (message.images == null || message.images!.isEmpty) {
        openAiMessages.add({
          'role': message.role.name,
          'content': message.content,
        });
        continue;
      }

      final content = <Map<String, dynamic>>[
        {
          'type': 'text',
          'text': message.content,
        },
      ];

      for (final image in message.images!) {
        final bytes = await image.readAsBytes();
        final base64 = base64Encode(bytes);
        content.add({
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$base64'},
        });
      }

      openAiMessages.add({
        'role': message.role.name,
        'content': content,
      });
    }

    return openAiMessages;
  }

  Stream<Map<String, dynamic>> _parseSseResponse(
    Stream<List<int>> stream,
  ) async* {
    var buffer = '';
    await for (final chunk in stream.transform(utf8.decoder)) {
      buffer += chunk;

      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (!line.startsWith('data:')) {
          continue;
        }

        final payload = line.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') {
          continue;
        }

        try {
          final jsonPayload = jsonDecode(payload) as Map<String, dynamic>;
          yield jsonPayload;
        } catch (_) {
          // Ignore malformed partial events and keep streaming.
        }
      }
    }
  }

  String? _extractDeltaText(Map<String, dynamic> data) {
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      return null;
    }

    final choice = choices.first as Map<String, dynamic>;
    final delta = choice['delta'] as Map<String, dynamic>?;
    return delta?['content']?.toString();
  }
}
