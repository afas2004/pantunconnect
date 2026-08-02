import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neomorphic_box.dart';

/// Mirrors ui/screens/auth/ForgotPasswordScreen.kt exactly, including copy text.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Scaffold(
          backgroundColor: AppColors.warmWhite,
          appBar: AppBar(
            title: const Text('Forgot Password'),
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              // Same fix as login_screen.dart/register_screen.dart - caps the card at a normal
              // width on desktop instead of stretching full-bleed; no-op on mobile.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: NeomorphicBox(
                backgroundColor: AppColors.warmWhite,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Reset Password',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 32),
                        child: Text(
                          'Enter your email to receive a password reset link',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => auth.resetPassword(_emailController.text.trim()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryAccentStrong,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: auth.status == AuthStatus.loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Send Reset Link', style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ),
                      if (auth.status == AuthStatus.success)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text('Reset link sent! Please check your email.', style: TextStyle(color: Color(0xFF4CAF50))),
                        ),
                      if (auth.status == AuthStatus.error)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(auth.errorMessage ?? '', style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
    super.dispose();
  }
}
