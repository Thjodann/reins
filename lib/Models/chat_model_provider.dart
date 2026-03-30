/// Supported providers for chat models.
enum ChatModelProvider {
  ollama('ollama'),
  openAi('openai');

  final String value;

  const ChatModelProvider(this.value);

  /// Parses a stored provider value into an enum.
  static ChatModelProvider fromValue(String? value) {
    return ChatModelProvider.values.firstWhere(
      (provider) => provider.value == value,
      orElse: () => ChatModelProvider.ollama,
    );
  }

  /// Human-friendly provider label for UI.
  String get displayName {
    switch (this) {
      case ChatModelProvider.ollama:
        return 'Ollama';
      case ChatModelProvider.openAi:
        return 'OpenAI';
    }
  }
}
