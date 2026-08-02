import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neomorphic_box.dart';
import '../../widgets/neomorphic_button.dart';

/// Mirrors ui/screens/auth/RegisterScreen.kt (Exhibit 3, "Create Account").
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.onNavigateToLogin, required this.onRegisterSuccess});

  final VoidCallback onNavigateToLogin;
  final VoidCallback onRegisterSuccess;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.status == AuthStatus.success) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onRegisterSuccess();
            auth.resetState();
          });
        }

        return Scaffold(
          backgroundColor: AppColors.backgroundNeutral,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              // Same fix as login_screen.dart - without a max width the card stretches to the
              // full browser width on desktop; 420 keeps it a normal card and is a no-op on
              // narrower/mobile viewports.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: NeomorphicBox(
                backgroundColor: const Color(0xFFF5F5F5),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Create Account',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const Text('Join the Pantun Community', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 24),
                      NeomorphicButton(
                        onPressed: () => auth.register(
                          _emailController.text.trim(),
                          _passwordController.text,
                          _usernameController.text.trim(),
                        ),
                        child: auth.status == AuthStatus.loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Register',
                                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      TextButton(
                        onPressed: widget.onNavigateToLogin,
                        child: const Text('Already have an account? Login', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      if (auth.status == AuthStatus.error)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(auth.errorMessage ?? '', style: const TextStyle(color: Colors.red, fontSize: 12)),
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
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
