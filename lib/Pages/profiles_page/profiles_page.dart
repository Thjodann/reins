import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:reins/Models/chatbot_profile.dart';
import 'package:reins/Providers/chat_provider.dart';
import 'package:reins/Services/services.dart';

class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chatbot Profiles')),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          final profiles = chatProvider.profiles;
          if (profiles.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No profiles yet.\nCreate one to auto-apply persona prompts to new chats.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final subtitle = [if (profile.age != null) '${profile.age} y/o', profile.profession].join(' - ');

              return Card(
                child: ListTile(
                  onTap: () => _editProfile(profile),
                  leading: _buildAvatar(profile.avatarPath),
                  title: Row(
                    children: [
                      Expanded(child: Text(profile.name, overflow: TextOverflow.ellipsis)),
                      if (profile.isDefault)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.star, color: Colors.amber),
                        ),
                    ],
                  ),
                  subtitle: Text('$subtitle\n${profile.bio}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'default') {
                        await context.read<ChatProvider>().setDefaultChatbotProfile(profile.id);
                      } else if (value == 'edit') {
                        await _editProfile(profile);
                      } else if (value == 'delete') {
                        await _deleteProfile(profile);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'default', child: Text('Set as default')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProfile,
        icon: const Icon(Icons.add),
        label: const Text('New Profile'),
      ),
    );
  }

  Widget _buildAvatar(String? avatarRelativePath) {
    final imageService = context.read<ImageService>();
    final avatarFile = imageService.getAvatarFile(avatarRelativePath);

    return CircleAvatar(
      backgroundImage: avatarFile != null ? FileImage(avatarFile) : null,
      child: avatarFile == null ? const Icon(Icons.person_outline) : null,
    );
  }

  Future<void> _createProfile() async {
    final draft = await _showProfileEditor();
    if (draft == null) return;

    final profile = ChatbotProfile(
      name: draft.name,
      age: draft.age,
      profession: draft.profession,
      bio: draft.bio,
      traits: draft.traits,
      avatarPath: draft.avatarPath,
    );

    await context.read<ChatProvider>().createChatbotProfile(profile, setAsDefault: draft.isDefault);
  }

  Future<void> _editProfile(ChatbotProfile profile) async {
    final draft = await _showProfileEditor(initialProfile: profile);
    if (draft == null) return;

    final updatedProfile = profile.copyWith(
      name: draft.name,
      age: draft.age,
      clearAge: draft.age == null,
      profession: draft.profession,
      bio: draft.bio,
      traits: draft.traits,
      clearTraits: draft.traits == null || draft.traits!.isEmpty,
      avatarPath: draft.avatarPath,
      clearAvatarPath: draft.avatarPath == null,
      isDefault: draft.isDefault,
    );

    await context.read<ChatProvider>().updateChatbotProfile(updatedProfile, setAsDefault: draft.isDefault);

    // Remove the replaced avatar file if user selected a new one.
    if (profile.avatarPath != null && profile.avatarPath != draft.avatarPath) {
      await context.read<ImageService>().deleteAvatar(profile.avatarPath);
    }
  }

  Future<void> _deleteProfile(ChatbotProfile profile) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete profile?'),
          content: Text('Delete "${profile.name}" permanently?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await context.read<ImageService>().deleteAvatar(profile.avatarPath);
    await context.read<ChatProvider>().deleteChatbotProfile(profile.id);
  }

  Future<_ProfileDraft?> _showProfileEditor({ChatbotProfile? initialProfile}) async {
    final imageService = context.read<ImageService>();
    final permissionService = context.read<PermissionService>();

    final nameController = TextEditingController(text: initialProfile?.name ?? '');
    final ageController = TextEditingController(text: initialProfile?.age?.toString() ?? '');
    final professionController = TextEditingController(text: initialProfile?.profession ?? '');
    final bioController = TextEditingController(text: initialProfile?.bio ?? '');
    final traitsController = TextEditingController(text: initialProfile?.traits ?? '');

    var avatarPath = initialProfile?.avatarPath;
    var isDefault = initialProfile?.isDefault ?? false;
    var didSubmit = false;
    String? validationError;

    Future<void> cleanupTemporaryAvatar() async {
      if (!didSubmit && avatarPath != null && avatarPath != initialProfile?.avatarPath) {
        await imageService.deleteAvatar(avatarPath);
      }
    }

    final draft = await showDialog<_ProfileDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(initialProfile == null ? 'New Profile' : 'Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: avatarPath != null ? FileImage(imageService.getAvatarFile(avatarPath)!) : null,
                      child: avatarPath == null ? const Icon(Icons.person_outline) : null,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        final hasPermission = await permissionService.requestPhotoPermission();
                        if (!hasPermission) return;

                        final picker = ImagePicker();
                        final pickedImage = await picker.pickImage(source: ImageSource.gallery);
                        if (pickedImage == null) return;

                        final newAvatarPath = await imageService.compressAndSaveAvatar(pickedImage.path);
                        if (newAvatarPath == null) return;

                        if (avatarPath != null && avatarPath != initialProfile?.avatarPath) {
                          await imageService.deleteAvatar(avatarPath);
                        }

                        setState(() {
                          avatarPath = newAvatarPath;
                        });
                      },
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Upload Profile Picture'),
                    ),
                    if (avatarPath != null)
                      TextButton(
                        onPressed: () async {
                          if (avatarPath != initialProfile?.avatarPath) {
                            await imageService.deleteAvatar(avatarPath);
                          }
                          setState(() {
                            avatarPath = null;
                          });
                        },
                        child: const Text('Remove Picture'),
                      ),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Name *'),
                    ),
                    TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age'),
                    ),
                    TextField(
                      controller: professionController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Profession *'),
                    ),
                    TextField(
                      controller: bioController,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Biography *'),
                    ),
                    TextField(
                      controller: traitsController,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Traits', hintText: 'Optional style/tone guidance'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isDefault,
                      onChanged: (value) => setState(() => isDefault = value),
                      title: const Text('Use as default profile'),
                    ),
                    if (validationError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(validationError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await cleanupTemporaryAvatar();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final profession = professionController.text.trim();
                    final bio = bioController.text.trim();
                    final ageInput = ageController.text.trim();

                    int? age;
                    if (ageInput.isNotEmpty) {
                      age = int.tryParse(ageInput);
                    }

                    if (name.isEmpty || profession.isEmpty || bio.isEmpty) {
                      setState(() {
                        validationError = 'Name, profession, and biography are required.';
                      });
                      return;
                    }

                    if (ageInput.isNotEmpty && age == null) {
                      setState(() {
                        validationError = 'Age must be a valid number.';
                      });
                      return;
                    }

                    didSubmit = true;
                    Navigator.of(context).pop(
                      _ProfileDraft(
                        name: name,
                        age: age,
                        profession: profession,
                        bio: bio,
                        traits: traitsController.text.trim().isEmpty ? null : traitsController.text.trim(),
                        avatarPath: avatarPath,
                        isDefault: isDefault,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (draft == null) {
      await cleanupTemporaryAvatar();
    }

    return draft;
  }
}

class _ProfileDraft {
  final String name;
  final int? age;
  final String profession;
  final String bio;
  final String? traits;
  final String? avatarPath;
  final bool isDefault;

  const _ProfileDraft({
    required this.name,
    required this.age,
    required this.profession,
    required this.bio,
    required this.traits,
    required this.avatarPath,
    required this.isDefault,
  });
}
