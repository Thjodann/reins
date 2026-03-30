import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:reins/Models/settings_route_arguments.dart';
import 'package:reins/Pages/settings_page/subwidgets/server_settings.dart';

class OllamaSettingsPage extends StatelessWidget {
  final SettingsRouteArguments? arguments;

  const OllamaSettingsPage({super.key, this.arguments});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ollama Settings', style: GoogleFonts.pacifico()),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            ServerSettings(
              autoFocusServerAddress: arguments?.autoFocusServerAddress ?? false,
              showSectionTitle: false,
            ),
          ],
        ),
      ),
    );
  }
}
