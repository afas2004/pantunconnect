import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../repositories/auth_repository.dart';

enum AuthStatus { idle, loading, success, error }

/// Mirrors ui/screens/auth/AuthViewModel.kt (AuthState sealed class -> AuthStatus enum here).
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authRepository);

  final AuthRepository _authRepository;

  AuthStatus status = AuthStatus.idle;
  String? errorMessage;

  User? get currentUser => _authRepository.currentUser;
  Stream<User?> get authStateChanges => _authRepository.authStateChanges;

  Future<void> login(String email, String pass) async {
    status = AuthStatus.loading;
    notifyListeners();
    try {
      await _authRepository.login(email, pass);
      status = AuthStatus.success;
    } catch (e) {
      status = AuthStatus.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> register(String email, String pass, String username) async {
    status = AuthStatus.loading;
    notifyListeners();
    try {
      await _authRepository.register(email, pass, username);
      status = AuthStatus.success;
    } catch (e) {
      status = AuthStatus.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    status = AuthStatus.loading;
    notifyListeners();
    try {
      await _authRepository.signInWithGoogle();
      status = AuthStatus.success;
    } catch (e) {
      status = AuthStatus.error;
      errorMessage = 'Google sign-in gagal: $e';
    }
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    status = AuthStatus.loading;
    notifyListeners();
    try {
      await _authRepository.resetPassword(email);
      status = AuthStatus.success;
    } catch (e) {
      status = AuthStatus.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _authRepository.logout();
    resetState();
  }

  void resetState() {
    status = AuthStatus.idle;
    errorMessage = null;
    notifyListeners();
  }
}
