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
            separatorBuilder: (_, index) => const SizedBox(height: 12),
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
    final chatProvider = context.read<ChatProvider>();
    final draft = await _showProfileEditor();
    if (draft == null) return;
    if (!mounted) return;

    final profile = ChatbotProfile(
      name: draft.name,
      age: draft.age,
      profession: draft.profession,
      bio: draft.bio,
      traits: draft.traits,
      avatarPath: draft.avatarPath,
    );

    await chatProvider.createChatbotProfile(profile, setAsDefault: draft.isDefault);
  }

  Future<void> _editProfile(ChatbotProfile profile) async {
    final chatProvider = context.read<ChatProvider>();
    final imageService = context.read<ImageService>();

    final draft = await _showProfileEditor(initialProfile: profile);
    if (draft == null) return;
    if (!mounted) return;

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

    await chatProvider.updateChatbotProfile(updatedProfile, setAsDefault: draft.isDefault);

    // Remove the replaced avatar file if user selected a new one.
    if (profile.avatarPath != null && profile.avatarPath != draft.avatarPath) {
      await imageService.deleteAvatar(profile.avatarPath);
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
    if (!mounted) return;

    final imageService = context.read<ImageService>();
    final chatProvider = context.read<ChatProvider>();

    await imageService.deleteAvatar(profile.avatarPath);
    await chatProvider.deleteChatbotProfile(profile.id);
  }

  Future<_ProfileDraft?> _showProfileEditor({ChatbotProfile? initialProfile}) async {
    return await Navigator.of(context).push<_ProfileDraft>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => _ProfileEditorPage(initialProfile: initialProfile)),
    );
  }
}

class _ProfileEditorPage extends StatefulWidget {
  final ChatbotProfile? initialProfile;

  const _ProfileEditorPage({this.initialProfile});

  @override
  State<_ProfileEditorPage> createState() => _ProfileEditorPageState();
}

class _ProfileEditorPageState extends State<_ProfileEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _professionController;
  late final TextEditingController _bioController;
  late final TextEditingController _traitsController;

  String? _avatarPath;
  late bool _isDefault;
  bool _didSubmit = false;
  String? _validationError;

  ImageService get _imageService => context.read<ImageService>();
  PermissionService get _permissionService => context.read<PermissionService>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile?.name ?? '');
    _ageController = TextEditingController(text: widget.initialProfile?.age?.toString() ?? '');
    _professionController = TextEditingController(text: widget.initialProfile?.profession ?? '');
    _bioController = TextEditingController(text: widget.initialProfile?.bio ?? '');
    _traitsController = TextEditingController(text: widget.initialProfile?.traits ?? '');
    _avatarPath = widget.initialProfile?.avatarPath;
    _isDefault = widget.initialProfile?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _professionController.dispose();
    _bioController.dispose();
    _traitsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _cancelAndPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.initialProfile == null ? 'New Profile' : 'Edit Profile'),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _cancelAndPop),
          actions: [TextButton(onPressed: _saveProfile, child: const Text('Save'))],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 44,
                        backgroundImage: _avatarPath != null
                            ? FileImage(_imageService.getAvatarFile(_avatarPath)!)
                            : null,
                        child: _avatarPath == null ? const Icon(Icons.person_outline, size: 28) : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: _pickAvatar,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Upload Profile Picture'),
                        ),
                        if (_avatarPath != null)
                          TextButton(onPressed: _removeAvatar, child: const Text('Remove Picture')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Name *'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _professionController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Profession *'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _bioController,
                      minLines: 4,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Biography *'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _traitsController,
                      minLines: 2,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Traits', hintText: 'Optional style/tone guidance'),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isDefault,
                      onChanged: (value) => setState(() => _isDefault = value),
                      title: const Text('Use as default profile'),
                    ),
                    if (_validationError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(_validationError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final hasPermission = await _permissionService.requestPhotoPermission();
    if (!hasPermission) return;

    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);
    if (pickedImage == null) return;

    final newAvatarPath = await _imageService.compressAndSaveAvatar(pickedImage.path);
    if (newAvatarPath == null) return;

    if (_avatarPath != null && _avatarPath != widget.initialProfile?.avatarPath) {
      await _imageService.deleteAvatar(_avatarPath);
    }

    if (!mounted) return;
    setState(() => _avatarPath = newAvatarPath);
  }

  Future<void> _removeAvatar() async {
    if (_avatarPath != null && _avatarPath != widget.initialProfile?.avatarPath) {
      await _imageService.deleteAvatar(_avatarPath);
    }
    if (!mounted) return;
    setState(() => _avatarPath = null);
  }

  Future<void> _cleanupTemporaryAvatar() async {
    if (!_didSubmit && _avatarPath != null && _avatarPath != widget.initialProfile?.avatarPath) {
      await _imageService.deleteAvatar(_avatarPath);
    }
  }

  Future<void> _cancelAndPop() async {
    await _cleanupTemporaryAvatar();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _saveProfile() {
    final name = _nameController.text.trim();
    final profession = _professionController.text.trim();
    final bio = _bioController.text.trim();
    final ageInput = _ageController.text.trim();

    int? age;
    if (ageInput.isNotEmpty) {
      age = int.tryParse(ageInput);
    }

    if (name.isEmpty || profession.isEmpty || bio.isEmpty) {
      setState(() {
        _validationError = 'Name, profession, and biography are required.';
      });
      return;
    }

    if (ageInput.isNotEmpty && age == null) {
      setState(() {
        _validationError = 'Age must be a valid number.';
      });
      return;
    }

    _didSubmit = true;
    Navigator.of(context).pop(
      _ProfileDraft(
        name: name,
        age: age,
        profession: profession,
        bio: bio,
        traits: _traitsController.text.trim().isEmpty ? null : _traitsController.text.trim(),
        avatarPath: _avatarPath,
        isDefault: _isDefault,
      ),
    );
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
