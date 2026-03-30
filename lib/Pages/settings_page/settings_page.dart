import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:reins/Models/settings_route_arguments.dart';

import 'subwidgets/subwidgets.dart';

class SettingsPage extends StatelessWidget {
  final SettingsRouteArguments? arguments;

  const SettingsPage({super.key, this.arguments});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.pacifico()),
      ),
      body: SafeArea(
        child: _SettingsPageContent(arguments: arguments),
      ),
    );
  }
}

class _SettingsPageContent extends StatelessWidget {
  final SettingsRouteArguments? arguments;

  const _SettingsPageContent({required this.arguments});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const ThemesSettings(),
        const SizedBox(height: 16),
        _ProviderSettings(
          autoFocusServerAddress: arguments?.autoFocusServerAddress ?? false,
        ),
        const SizedBox(height: 16),
        const ReinsSettings(),
      ],
    );
  }
}

class _ProviderSettings extends StatelessWidget {
  final bool autoFocusServerAddress;

  const _ProviderSettings({required this.autoFocusServerAddress});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Providers',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: const Text('Ollama Settings'),
                subtitle: const Text('Configure your local or remote Ollama server'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/settings/ollama',
                    arguments: SettingsRouteArguments(
                      autoFocusServerAddress: autoFocusServerAddress,
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.vpn_key_outlined),
                title: const Text('API Keys'),
                subtitle: const Text('Connect cloud model providers'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/settings/api-keys'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
