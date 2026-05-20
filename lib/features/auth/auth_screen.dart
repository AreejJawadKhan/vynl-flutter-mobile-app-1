import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import 'providers/auth_provider.dart' as ap;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();
  bool _loading    = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _error = null; });
    final auth = context.read<ap.AuthProvider>();
    final result = await auth.signInWithGoogle();
    if (mounted && result == null) {
      setState(() {
        _loading = false;
        _error = 'Google sign-in cancelled or failed.';
      });
    }
  }

  Future<void> _emailSignIn() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<ap.AuthProvider>();
      await auth.signInWithEmail(
          _emailCtrl.text.trim(), _passCtrl.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(e.toString());
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<ap.AuthProvider>().sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent. Check your inbox.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = _friendlyError(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<ap.AuthProvider>();
      await auth.registerWithEmail(
        _emailCtrl.text.trim(),
        _passCtrl.text,
        _nameCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created. Check your email to verify your address.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(e.toString());
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('email-already-in-use')) return 'That email is already registered.';
    if (raw.contains('wrong-password'))       return 'Incorrect password.';
    if (raw.contains('user-not-found'))       return 'No account found with that email.';
    if (raw.contains('weak-password'))        return 'Password must be at least 6 characters.';
    if (raw.contains('invalid-email'))        return 'Please enter a valid email address.';
    if (raw.contains('invalid-display-name')) return 'Please enter a display name.';
    if (raw.contains('network-request-failed')) return 'No internet connection.';
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    // Use resizeToAvoidBottomInset to handle keyboard properly
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          // Scrollable so keyboard never causes overflow
          padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),

              // Logo
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.darkBerry,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.album_rounded,
                    color: AppColors.white, size: 48),
              ),

              const SizedBox(height: AppConstants.spaceL),
              Text('vynl', style: AppTextStyles.display),
              Text('Listen together.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.stoneDark)),

              const SizedBox(height: 36),

              // Google button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _googleSignIn,
                  icon: const Icon(Icons.login, size: 22,
                      color: AppColors.darkBerry),
                  label: Text('Continue with Google',
                      style: AppTextStyles.button
                          .copyWith(color: AppColors.darkBerry)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.darkBerry, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppConstants.radiusM),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppConstants.spaceL),

              // Divider
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or email', style: AppTextStyles.bodySmall),
                ),
                const Expanded(child: Divider()),
              ]),

              const SizedBox(height: AppConstants.spaceM),

              // Tabs
              TabBar(
                controller: _tab,
                tabs: const [
                  Tab(text: 'Sign In'),
                  Tab(text: 'Register'),
                ],
              ),

              const SizedBox(height: AppConstants.spaceM),

              // Tab content — fixed height to avoid layout jump
              SizedBox(
                height: 260,
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _SignInForm(
                      emailCtrl: _emailCtrl,
                      passCtrl:  _passCtrl,
                      onSubmit:  _emailSignIn,
                      onForgotPassword: _forgotPassword,
                      loading:   _loading,
                    ),
                    _RegisterForm(
                      nameCtrl:  _nameCtrl,
                      emailCtrl: _emailCtrl,
                      passCtrl:  _passCtrl,
                      onSubmit:  _register,
                      loading:   _loading,
                    ),
                  ],
                ),
              ),

              // Error message
              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(
                      top: AppConstants.spaceM),
                  padding: const EdgeInsets.all(AppConstants.spaceM),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius:
                    BorderRadius.circular(AppConstants.radiusM),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(_error!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error),
                      textAlign: TextAlign.center),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInForm extends StatelessWidget {
  final TextEditingController emailCtrl, passCtrl;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final bool loading;
  const _SignInForm({
    required this.emailCtrl,
    required this.passCtrl,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: AppConstants.spaceM),
        TextField(
          controller: passCtrl,
          obscureText: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: AppConstants.spaceL),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: loading ? null : onSubmit,
            child: loading
                ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: AppColors.white, strokeWidth: 2.5))
                : const Text('Sign In'),
          ),
        ),
        const SizedBox(height: AppConstants.spaceS),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: loading ? null : onForgotPassword,
            child: const Text('Forgot password?'),
          ),
        ),
      ],
    );
  }
}

class _RegisterForm extends StatelessWidget {
  final TextEditingController nameCtrl, emailCtrl, passCtrl;
  final VoidCallback onSubmit;
  final bool loading;
  const _RegisterForm({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.onSubmit,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: AppConstants.spaceM),
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: AppConstants.spaceM),
        TextField(
          controller: passCtrl,
          obscureText: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Password (min 6 chars)',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: AppConstants.spaceL),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: loading ? null : onSubmit,
            child: loading
                ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: AppColors.white, strokeWidth: 2.5))
                : const Text('Create Account'),
          ),
        ),
      ],
    );
  }
}