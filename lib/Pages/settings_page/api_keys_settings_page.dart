import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:reins/Models/ollama_exception.dart';
import 'package:reins/Models/ollama_request_state.dart';
import 'package:reins/Services/openai_service.dart';
import 'package:reins/Services/secure_storage_service.dart';

class ApiKeysSettingsPage extends StatefulWidget {
  const ApiKeysSettingsPage({super.key});

  @override
  State<ApiKeysSettingsPage> createState() => _ApiKeysSettingsPageState();
}

class _ApiKeysSettingsPageState extends State<ApiKeysSettingsPage> {
  final _openAiController = TextEditingController();

  OllamaRequestState _requestState = OllamaRequestState.uninitialized;
  bool _obscureOpenAiApiKey = true;
  String? _openAiErrorText;
  String? _openAiInfoText;

  bool get _isLoading => _requestState == OllamaRequestState.loading;

  @override
  void initState() {
    super.initState();
    _loadStoredKey();
  }

  @override
  void dispose() {
    _openAiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('API Keys', style: GoogleFonts.pacifico()),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'OpenAI',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _openAiController,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              obscureText: _obscureOpenAiApiKey,
              onChanged: (_) {
                setState(() {
                  _openAiErrorText = null;
                  _requestState = OllamaRequestState.uninitialized;
                });
              },
              decoration: InputDecoration(
                labelText: 'OpenAI API Key',
                hintText: 'sk-...',
                errorText: _openAiErrorText,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureOpenAiApiKey
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureOpenAiApiKey = !_obscureOpenAiApiKey;
                    });
                  },
                ),
              ),
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleTestAuthentication,
                  child: _ConnectionStatusIndicator(color: _connectionStatusColor),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _handleClearKey,
                  child: const Text('Clear Key'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _openAiInfoText ??
                  'Your API key is stored in secure platform keychain storage.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Color get _connectionStatusColor {
    switch (_requestState) {
      case OllamaRequestState.error:
        return Colors.red;
      case OllamaRequestState.loading:
        return Colors.orange;
      case OllamaRequestState.success:
        return Colors.green;
      case OllamaRequestState.uninitialized:
        return Colors.grey;
    }
  }

  Future<void> _loadStoredKey() async {
    final secureStorage = context.read<SecureStorageService>();
    final key = await secureStorage.readOpenAiApiKey();
    if (!mounted) return;

    setState(() {
      if (key != null && key.isNotEmpty) {
        _openAiController.text = key;
      }
      _openAiInfoText = secureStorage.isUsingSessionFallback
          ? 'Secure keychain is unavailable on this build. '
              'OpenAI key is active for this app session only.'
          : null;
      if (secureStorage.isUsingSessionFallback && _requestState == OllamaRequestState.uninitialized) {
        _requestState = OllamaRequestState.success;
      }
    });
  }

  void _syncStorageInfoText(SecureStorageService secureStorage) {
    _openAiInfoText = secureStorage.isUsingSessionFallback
        ? 'Secure keychain is unavailable on this build. '
            'OpenAI key is active for this app session only.'
        : null;
  }

  Future<void> _handleTestAuthentication() async {
    setState(() {
      _openAiErrorText = null;
      _requestState = OllamaRequestState.loading;
    });

    final key = _openAiController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _openAiErrorText = 'Please paste your OpenAI API key.';
        _requestState = OllamaRequestState.error;
      });
      return;
    }

    final openAiService = context.read<OpenAiService>();
    final secureStorage = context.read<SecureStorageService>();

    try {
      await openAiService.authenticate(key);
      await secureStorage.writeOpenAiApiKey(key);

      if (!mounted) return;
      setState(() {
        _syncStorageInfoText(secureStorage);
        _requestState = OllamaRequestState.success;
      });
    } on OllamaException catch (error) {
      if (!mounted) return;
      setState(() {
        _openAiErrorText = error.message;
        _requestState = OllamaRequestState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _openAiErrorText = 'Unable to authenticate this key.';
        _requestState = OllamaRequestState.error;
      });
    }
  }

  Future<void> _handleClearKey() async {
    final secureStorage = context.read<SecureStorageService>();
    await secureStorage.deleteOpenAiApiKey();
    if (!mounted) return;

    setState(() {
      _openAiController.clear();
      _openAiErrorText = null;
      _syncStorageInfoText(secureStorage);
      _requestState = OllamaRequestState.uninitialized;
    });
  }
}

class _ConnectionStatusIndicator extends StatelessWidget {
  final Color color;

  const _ConnectionStatusIndicator({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Test Authentication'),
        const SizedBox(width: 10),
        Container(
          width: MediaQuery.of(context).textScaler.scale(10),
          height: MediaQuery.of(context).textScaler.scale(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ],
    );
  }
}
