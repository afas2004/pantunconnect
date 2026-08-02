import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/edit_profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neomorphic_box.dart';

/// Mirrors ui/screens/profile/EditProfileScreen.kt, including the real image-picker wiring
/// added on the Kotlin side (the camera FAB used to be `onClick = { /* Image picker logic */ }`).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _initialized = false;
  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditProfileProvider>();
    final user = provider.user;

    if (user != null && !_initialized) {
      _usernameController.text = user.username;
      _bioController.text = user.bio;
      _initialized = true;
    }

    if (provider.isSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onBack());
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundNeutral,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        actions: [
          TextButton(
            onPressed: () => provider.updateProfile(_usernameController.text, _bioController.text),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryAccentStrong)),
          ),
        ],
      ),
      body: provider.isLoading && user == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.avatarLavender,
                        backgroundImage: (user?.profilePictureUrl.isNotEmpty ?? false)
                            ? CachedNetworkImageProvider(user!.profilePictureUrl)
                            : null,
                        child: (user?.profilePictureUrl.isEmpty ?? true)
                            ? Text(
                                _usernameController.text.isNotEmpty ? _usernameController.text[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                              )
                            : null,
                      ),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryAccentStrong,
                        child: IconButton(
                          icon: provider.isUploadingPhoto
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          onPressed: () async {
                            final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                            if (image != null) await provider.uploadProfilePicture(image);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  NeomorphicBox(
                    backgroundColor: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Username', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          TextField(controller: _usernameController, decoration: const InputDecoration(border: InputBorder.none)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  NeomorphicBox(
                    backgroundColor: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bio', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          TextField(controller: _bioController, minLines: 3, maxLines: 5, decoration: const InputDecoration(border: InputBorder.none)),
                        ],
                      ),
                    ),
                  ),
                  if (provider.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(provider.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
