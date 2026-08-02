import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_model.dart';
import '../repositories/storage_repository.dart';
import '../repositories/user_repository.dart';

/// Mirrors ui/screens/profile/EditProfileViewModel.kt, including the image-picker wiring added
/// on the Kotlin side (the "change photo" button used to be a no-op).
class EditProfileProvider extends ChangeNotifier {
  EditProfileProvider(this._userRepository, this._storageRepository, this._auth) {
    _loadUser();
  }

  final UserRepository _userRepository;
  final StorageRepository _storageRepository;
  final FirebaseAuth _auth;

  AppUser? user;
  bool isLoading = false;
  bool isUploadingPhoto = false;
  bool isSuccess = false;
  String? error;

  Future<void> _loadUser() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    isLoading = true;
    notifyListeners();
    user = await _userRepository.getUser(userId);
    isLoading = false;
    notifyListeners();
  }

  Future<void> uploadProfilePicture(XFile image) async {
    final userId = _auth.currentUser?.uid;
    final currentUser = user;
    if (userId == null || currentUser == null) return;

    isUploadingPhoto = true;
    error = null;
    notifyListeners();
    try {
      final url = await _storageRepository.uploadProfilePicture(userId, image);
      final updatedUser = currentUser.copyWith(profilePictureUrl: url);
      await _userRepository.updateUser(updatedUser);
      user = updatedUser;
    } catch (e) {
      error = e.toString();
    }
    isUploadingPhoto = false;
    notifyListeners();
  }

  Future<void> updateProfile(String username, String bio) async {
    final currentUser = user;
    if (currentUser == null) return;
    final updatedUser = currentUser.copyWith(username: username, bio: bio);

    isLoading = true;
    notifyListeners();
    try {
      await _userRepository.updateUser(updatedUser);
      user = updatedUser;
      isSuccess = true;
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }
}
