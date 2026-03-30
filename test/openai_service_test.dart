import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reins/Models/chat_model_provider.dart';
import 'package:reins/Models/ollama_chat.dart';
import 'package:reins/Models/ollama_message.dart';
import 'package:reins/Services/openai_service.dart';
import 'package:test/test.dart';

void main() {
  test('listModels returns sorted model IDs', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/v1/models');
      expect(request.headers['authorization'], startsWith('Bearer '));
      return http.Response(
        jsonEncode({
          'data': [
            {'id': 'gpt-4.1'},
            {'id': 'gpt-5-mini'},
            {'id': 'gpt-4o-mini'},
          ],
        }),
        200,
      );
    });
    final service = OpenAiService(httpClient: client);

    final models = await service.listModels('sk-test');
    expect(models, ['gpt-4.1', 'gpt-4o-mini', 'gpt-5-mini']);
  });

  test('authenticate succeeds with valid response', () async {
    final client = MockClient((_) async => http.Response('{"data":[]}', 200));
    final service = OpenAiService(httpClient: client);

    await service.authenticate('sk-valid');
  });

  test('chatStream parses SSE delta chunks', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/v1/chat/completions');
      return http.Response(
        [
          'data: {"choices":[{"delta":{"content":"Hello"}}]}',
          'data: {"choices":[{"delta":{"content":" world"}}]}',
          'data: [DONE]',
        ].join('\n'),
        200,
      );
    });
    final service = OpenAiService(httpClient: client);
    final chat = OllamaChat(
      model: 'gpt-5-mini',
      provider: ChatModelProvider.openAi,
    );

    final stream = service.chatStream(
      [OllamaMessage('Hi', role: OllamaMessageRole.user)],
      chat: chat,
      apiKey: 'sk-test',
    );

    final chunks = <String>[];
    await for (final message in stream) {
      chunks.add(message.content);
    }

    expect(chunks.join(), 'Hello world');
  });
}
