import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neomorphic_box.dart';
import '../../widgets/neomorphic_button.dart';

/// Mirrors ui/screens/auth/LoginScreen.kt (Exhibit 2, "Welcome Back").
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onNavigateToRegister,
    required this.onNavigateToForgotPassword,
    required this.onLoginSuccess,
  });

  final VoidCallback onNavigateToRegister;
  final VoidCallback onNavigateToForgotPassword;
  final VoidCallback onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.status == AuthStatus.success) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onLoginSuccess();
            auth.resetState();
          });
        }

        return Scaffold(
          backgroundColor: AppColors.backgroundNeutral,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              // Without a max width, TextField (and everything else in the Column) stretches to
              // fill whatever loose width Center/SingleChildScrollView hand it - on mobile that's
              // the screen width anyway, but on desktop it meant a login card stretching the full
              // browser width instead of reading as a real card. 420 keeps it a normal card size
              // on wide viewports while staying a no-op on narrow ones.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: NeomorphicBox(
                backgroundColor: const Color(0xFFF5F5F5),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Welcome Back',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const Text('PANTUN-CONNECT', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: widget.onNavigateToForgotPassword,
                          child: const Text('Forgot Password?', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      NeomorphicButton(
                        onPressed: () => auth.login(_emailController.text.trim(), _passwordController.text),
                        child: auth.status == AuthStatus.loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Login',
                                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 16),
                      // Google Sign In
                      NeomorphicButton(
                        backgroundColor: Colors.white,
                        elevation: 2,
                        onPressed: () => auth.signInWithGoogle(),
                        child: const Text('Sign in with Google',
                            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      ),
                      TextButton(
                        onPressed: widget.onNavigateToRegister,
                        child: const Text("Don't have an account? Register", style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      if (auth.status == AuthStatus.error)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            auth.errorMessage ?? '',
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
