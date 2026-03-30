import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:reins/Constants/constants.dart';
import 'package:reins/Providers/chat_provider.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'title_divider.dart';

class ChatDrawer extends StatelessWidget {
  const ChatDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const Expanded(child: ChatNavigationDrawer()),
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 10),
              child: IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  if (ResponsiveBreakpoints.of(context).isMobile) {
                    Navigator.pop(context);
                  }

                  Navigator.pushNamed(context, '/settings');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatNavigationDrawer extends StatelessWidget {
  const ChatNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final selectedIndex = chatProvider.selectedDestination == 0 ? 0 : chatProvider.selectedDestination + 1;

        return NavigationDrawer(
          selectedIndex: selectedIndex,
          onDestinationSelected: (destination) {
            if (destination == 0) {
              chatProvider.destinationChatSelected(0);
            } else if (destination == 1) {
              if (ResponsiveBreakpoints.of(context).isMobile) {
                Navigator.pop(context);
              }
              Navigator.pushNamed(context, '/profiles');
              return;
            } else {
              chatProvider.destinationChatSelected(destination - 1);
            }

            if (ResponsiveBreakpoints.of(context).isMobile) {
              Navigator.pop(context);
            }
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
              child: Text(AppConstants.appName, style: Theme.of(context).textTheme.titleSmall),
            ),
            NavigationDrawerDestination(
              icon: CircleAvatar(
                radius: 16,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: SvgPicture.asset(
                    AppConstants.ollamaIconSvg,
                    colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.onSurface, BlendMode.srcIn),
                  ),
                ),
              ),
              label: Text("New Chat"),
            ),
            const NavigationDrawerDestination(
              icon: Icon(Icons.manage_accounts_outlined),
              selectedIcon: Icon(Icons.manage_accounts),
              label: Text("Profiles"),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 16, 28, 10),
              child: TitleDivider(title: "Chats"),
            ),
            ...chatProvider.chats.map((chat) {
              return NavigationDrawerDestination(
                icon: const Icon(Icons.chat_outlined),
                label: Expanded(child: Text(chat.title, overflow: TextOverflow.ellipsis)),
                selectedIcon: const Icon(Icons.chat),
              );
            }),
          ],
        );
      },
    );
  }
}
