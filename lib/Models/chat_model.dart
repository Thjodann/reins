import 'package:reins/Models/chat_model_provider.dart';
import 'package:reins/Models/model_capabilities.dart';
import 'package:reins/Models/ollama_model.dart';

/// Provider-neutral representation of a selectable chat model.
class ChatModel {
  final ChatModelProvider provider;
  final String id;
  final String name;
  final String subtitle;
  final ModelCapabilities? capabilities;

  const ChatModel({
    required this.provider,
    required this.id,
    required this.name,
    this.subtitle = '',
    this.capabilities,
  });

  /// Unique key used for selection/persistence lookups.
  String get key => '${provider.value}:$id';

  /// Converts an existing [OllamaModel] into a provider-neutral model.
  factory ChatModel.fromOllamaModel(OllamaModel model) {
    return ChatModel(
      provider: ChatModelProvider.ollama,
      id: model.model,
      name: model.name,
      subtitle: model.parameterSize,
      capabilities: model.capabilities,
    );
  }

  /// Creates an OpenAI-backed chat model.
  factory ChatModel.fromOpenAiModelId(String modelId) {
    return ChatModel(
      provider: ChatModelProvider.openAi,
      id: modelId,
      name: modelId,
      subtitle: 'OpenAI',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatModel && other.key == key;
  }

  @override
  int get hashCode => key.hashCode;
}
