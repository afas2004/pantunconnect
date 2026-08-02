import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Mirrors data/repository/StorageRepository.kt.
///
/// Uses XFile.readAsBytes() + putData() (rather than putFile(File)) throughout, since dart:io
/// File paths aren't available on Flutter Web - this keeps the same code path working on both
/// Android and Web, which a File-based approach wouldn't.
class StorageRepository {
  StorageRepository({FirebaseStorage? storage}) : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadProfilePicture(String userId, XFile file) async {
    final ref = _storage.ref().child('profile_pictures/$userId.jpg');
    final bytes = await file.readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<String> uploadPostImage(String postId, XFile file) async {
    final ref = _storage.ref().child('post_images/$postId.jpg');
    final bytes = await file.readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
