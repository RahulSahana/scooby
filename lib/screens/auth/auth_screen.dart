import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../theme/app_colors.dart';
import '../connect/connect_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _hidePassword = true;
  bool _isBusy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _skip() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ConnectScreen()),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isBusy = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null &&
          (userCredential.user!.displayName == null ||
              userCredential.user!.displayName!.isEmpty)) {
        await userCredential.user!.updateDisplayName(googleUser.displayName);
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _messageFor(error.code));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Google Sign-In failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      if (_isSignUp) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        await credential.user?.updateDisplayName(_nameController.text.trim());
      } else {
        await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _messageFor(error.code));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'Could not connect. Check your internet and try again.',
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _messageFor(String code) {
    return switch (code) {
      'email-already-in-use' =>
        'An account already uses this email. Sign in instead.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' =>
        'Choose a stronger password with at least 6 characters.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Email or password is incorrect.',
      'too-many-requests' =>
        'Too many attempts. Wait a little, then try again.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      'operation-not-allowed' =>
        'This sign-in method is disabled in Firebase Console.',
      _ =>
        'We couldn’t ${_isSignUp ? 'create your account' : 'sign you in'}. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: themeColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Image.asset('lib/assets/eyes.png', width: 72, height: 64),
                  const SizedBox(height: 8),
                  Text(
                    'Scooby',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp
                        ? 'Create your Scooby account'
                        : 'Sign in to your account',
                    style: TextStyle(color: themeColors.secondaryText),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    color: themeColors.cardColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: themeColors.cardBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. GOOGLE SIGN IN BUTTON
                          OutlinedButton.icon(
                            onPressed: _isBusy ? null : _signInWithGoogle,
                            icon: const Icon(Icons.g_mobiledata, size: 28),
                            label: const Text(
                              'Continue with Google',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(child: Divider(color: themeColors.cardBorder)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: themeColors.secondaryText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: themeColors.cardBorder)),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // 2. EMAIL / PASSWORD FORM
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_isSignUp) ...[
                                  _inputField(
                                    controller: _nameController,
                                    label: 'Your name',
                                    icon: Icons.person_outline,
                                    textCapitalization: TextCapitalization.words,
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Enter your name.'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                _inputField(
                                  controller: _emailController,
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    if (email.isEmpty || !email.contains('@')) {
                                      return 'Enter a valid email address.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _inputField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  icon: Icons.lock_outline,
                                  obscureText: _hidePassword,
                                  suffix: IconButton(
                                    onPressed: () => setState(
                                      () => _hidePassword = !_hidePassword,
                                    ),
                                    icon: Icon(
                                      _hidePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                  validator: (value) {
                                    final password = value ?? '';
                                    if (password.isEmpty) {
                                      return 'Enter your password.';
                                    }
                                    if (_isSignUp && password.length < 6) {
                                      return 'Use at least 6 characters.';
                                    }
                                    return null;
                                  },
                                ),
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    _errorMessage!,
                                    style: TextStyle(color: scheme.error),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                const SizedBox(height: 22),
                                FilledButton(
                                  onPressed: _isBusy ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isBusy
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          _isSignUp ? 'Create account' : 'Sign in',
                                        ),
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: _isBusy
                                      ? null
                                      : () => setState(() {
                                          _isSignUp = !_isSignUp;
                                          _errorMessage = null;
                                        }),
                                  child: Text(
                                    _isSignUp
                                        ? 'Already have an account? Sign in'
                                        : 'New to Scooby? Create an account',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: _skip,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Skip for now (Continue as Guest)'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You’ll stay signed in on this device until you sign out.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: themeColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffix,
  }) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      autocorrect: false,
      style: TextStyle(color: colors.primaryText),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: colors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
