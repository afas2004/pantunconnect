import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/draft_model.dart';
import '../models/post_model.dart';
import '../repositories/post_repository.dart';
import '../repositories/storage_repository.dart';
import '../services/draft_service.dart';
import '../services/gemini_service.dart';

/// Mirrors ui/screens/create/CreatePantunViewModel.kt, including the "Smart Post Creator"
/// AI theme-classification addition made on the Kotlin side.
class CreatePantunProvider extends ChangeNotifier {
  CreatePantunProvider(
    this._postRepository,
    this._storageRepository,
    this._geminiService,
    this._draftService,
    this._auth,
  ) {
    _loadDrafts();
  }

  final PostRepository _postRepository;
  final StorageRepository _storageRepository;
  final GeminiService _geminiService;
  final DraftService _draftService;
  final FirebaseAuth _auth;

  List<Draft> drafts = [];
  bool isLoading = false;
  bool isSuccess = false;
  bool isClassifying = false;
  String? suggestedTheme;
  String? error;

  void _loadDrafts() {
    _draftService.watchDrafts().listen((value) {
      drafts = value;
      notifyListeners();
    });
  }

  Future<void> saveDraft(String content, String category, {XFile? image}) async {
    final draft = Draft(content: content, category: category, imageUrl: image?.path);
    await _draftService.insertDraft(draft);
  }

  Future<void> deleteDraft(Draft draft) async {
    await _draftService.deleteDraft(draft);
  }

  /// "Smart Post Creator": asks Gemini to classify the pantun's theme.
  Future<void> classifyTheme(String content) async {
    if (content.trim().isEmpty) return;
    isClassifying = true;
    notifyListeners();
    try {
      suggestedTheme = await _geminiService.classifyTheme(content);
    } catch (e) {
      error = e.toString();
    }
    isClassifying = false;
    notifyListeners();
  }

  void clearSuggestedTheme() {
    suggestedTheme = null;
  }

  Future<void> createPost(String content, String category, {XFile? image, int? draftId}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    isLoading = true;
    error = null;
    notifyListeners();
    try {
      var imageUrl = '';
      if (image != null) {
        // Best-effort: Firebase Storage requires the Blaze plan to provision, so on projects
        // without Storage set up this upload fails. The pantun itself should still post - text
        // is the content that matters; the background image is decoration.
        try {
          final tempId = DateTime.now().millisecondsSinceEpoch.toString();
          imageUrl = await _storageRepository.uploadPostImage(tempId, image);
        } catch (_) {
          imageUrl = '';
        }
      }

      final post = Post(
        authorId: currentUser.uid,
        authorName: currentUser.displayName ?? 'Anonymous',
        content: content,
        category: category,
        backgroundImageUrl: imageUrl,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      await _postRepository.createPost(post);

      if (draftId != null) {
        await _draftService.deleteDraftById(draftId);
      }

      isSuccess = true;
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  void resetSuccess() {
    isSuccess = false;
  }
}
