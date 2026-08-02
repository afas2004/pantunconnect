import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';

/// Mirrors data/repository/AuthRepository.kt.
///
/// Google Sign-In fix carried over from the Kotlin app: Firebase sign-in runs FIRST and is the
/// source of truth. The Kotlin version originally called an (undeployed) backend proxy before
/// Firebase, with no try/catch, so sign-in always failed even though Firebase itself worked fine.
/// There's no backend here at all (see gemini_service.dart for why), so this is simply: Firebase
/// only, then sync the user doc to Firestore.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> login(String email, String pass) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: pass);
    } catch (e) {
      // The auth plugin's platform channel can throw a decode error even when the sign-in
      // itself succeeded natively. Only rethrow if we're genuinely not signed in.
      if (_auth.currentUser == null) rethrow;
    }
    // Self-heal: accounts registered while Firestore rules were broken (or when register's
    // profile write failed) have no users/{uid} doc, which left the Profile screen empty.
    await _ensureUserDoc();
  }

  Future<void> register(String email, String pass, String username) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: pass);
    } catch (e) {
      // Same platform-channel quirk as login: the Firebase account is often created even
      // though the Dart side throws. If we ended up signed in, treat it as success so the
      // profile doc still gets written; otherwise it's a real failure (email in use, weak
      // password, etc.) - rethrow it.
      if (_auth.currentUser == null) rethrow;
    }
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) throw Exception('User creation failed');

    // Keep FirebaseAuth's displayName in sync so posts show the username immediately.
    try {
      await firebaseUser.updateDisplayName(username);
    } catch (_) {}

    final user = AppUser(id: firebaseUser.uid, username: username, email: email);
    await _firestore.collection('users').doc(firebaseUser.uid).set(user.toMap());
  }

  /// Creates the users/{uid} profile doc if it's missing (mirrors the doc shape register
  /// writes). Best-effort - never fails the sign-in that triggered it.
  Future<void> _ensureUserDoc() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;
    try {
      final docRef = _firestore.collection('users').doc(firebaseUser.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        final fallbackUsername = firebaseUser.displayName ??
            (firebaseUser.email?.split('@').first ?? 'User_${firebaseUser.uid.substring(0, 5)}');
        final user = AppUser(
          id: firebaseUser.uid,
          username: fallbackUsername,
          email: firebaseUser.email ?? '',
          profilePictureUrl: firebaseUser.photoURL ?? '',
        );
        await docRef.set(user.toMap());
      }
    } catch (_) {}
  }

  /// Signs in with Google. On web this uses Firebase's redirect flow; on Android/iOS (native)
  /// it goes through the google_sign_in package first to get credentials.
  ///
  /// Web previously used `signInWithPopup`, which opens a JS popup window and relies on
  /// third-party storage access to complete the credential exchange. iOS Safari - and every
  /// other iOS browser, since they're all WebKit under the hood, not just Safari itself - blocks
  /// that by default under Intelligent Tracking Prevention, so the popup either never opens or
  /// silently fails to complete. `signInWithRedirect` does a full-page navigation to Google and
  /// back instead, which sidesteps the popup/third-party-storage requirement entirely and is
  /// Firebase's own documented recommendation for Safari/iOS. Because it's a real page
  /// navigation, this method can't return a UserCredential the way the popup version did - the
  /// app reloads after the redirect back, and `completeGoogleRedirectSignIn()` (called from
  /// main.dart on every startup) picks up the result then.
  ///
  /// IMPORTANT (Web): requires a "Web" app to be registered in the Firebase Console for this
  /// project with an authorized OAuth client (Authentication > Sign-in method > Google), the
  /// same prerequisite noted on the Android side (google-services.json needs a populated
  /// oauth_client list). Without it this will fail with an auth/operation-not-allowed error.
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      await _auth.signInWithRedirect(googleProvider);
      return;
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    if (result.user == null) throw Exception('Google sign in failed');
    await _syncGoogleUser(result.user);
  }

  /// Web only: picks up the result of the `signInWithRedirect()` call above after the page has
  /// reloaded. Safe to call unconditionally on every startup (including native, where it's a
  /// no-op) - resolves quietly, not as an error, when there's no pending redirect to complete.
  Future<void> completeGoogleRedirectSignIn() async {
    if (!kIsWeb) return;
    try {
      final result = await _auth.getRedirectResult();
      await _syncGoogleUser(result.user);
    } catch (_) {
      // No pending redirect, or the redirect itself failed - there's no UI on the splash screen
      // to surface an error on anyway; a real failure just leaves the user logged out and back
      // at the login screen, same as if they'd cancelled.
    }
  }

  /// Shared by both the native-credential and web-redirect Google sign-in paths: creates the
  /// users/{uid} profile doc the first time a given Google account signs in.
  Future<void> _syncGoogleUser(User? firebaseUser) async {
    if (firebaseUser == null) return;
    final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
    if (!userDoc.exists) {
      final newUser = AppUser(
        id: firebaseUser.uid,
        username: firebaseUser.displayName ?? 'User_${firebaseUser.uid.substring(0, 5)}',
        email: firebaseUser.email ?? '',
        profilePictureUrl: firebaseUser.photoURL ?? '',
      );
      await _firestore.collection('users').doc(firebaseUser.uid).set(newUser.toMap());
    }
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> logout() async {
    await _auth.signOut();
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
  }
}
