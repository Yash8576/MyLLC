import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _emailError;
  bool _showPassword = false;
  bool _isLoading = false;
  bool _rememberMe = false;

  // Account Type - default to CONSUMER
  String _accountType = 'CONSUMER';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final email = _emailController.text.trim();

    if (_nameController.text.isEmpty ||
        email.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() => _emailError = null);
      _showError('Please fill in all fields');
      return;
    }

    if (!_emailRegex.hasMatch(email)) {
      setState(() => _emailError = 'Please check your email address');
      return;
    }

    setState(() => _emailError = null);

    if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().register(
            email,
            _passwordController.text,
            _nameController.text.trim(),
            rememberMe: _rememberMe,
            accountType: _accountType,
            privacyProfile: 'PUBLIC',
          );
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        if (e is AuthException) {
          _showError(e.message);
        } else {
          _showError('Signup failed. Please try again.');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.destructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Buzz',
                          style: textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: 'Cart',
                          style: textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.electricBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Social commerce, reimagined',
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.darkMutedForeground
                          : AppColors.lightMutedForeground,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Create an account',
                            style: textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sign up to get started',
                            style: textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkMutedForeground
                                  : AppColors.lightMutedForeground,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Name field
                          Text(
                            'Name',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _nameController,
                            enabled: !_isLoading,
                            decoration: const InputDecoration(
                              hintText: 'Your name',
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Email field
                          Text(
                            'Email',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'Enter your email',
                              errorText: _emailError,
                            ),
                            onChanged: (value) {
                              if (_emailError != null &&
                                  _emailRegex.hasMatch(value.trim())) {
                                setState(() => _emailError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          // Password field
                          Text(
                            'Password',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _passwordController,
                            obscureText: !_showPassword,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(
                                      () => _showPassword = !_showPassword);
                                },
                              ),
                            ),
                            onSubmitted: (_) => _handleSignup(),
                          ),
                          const SizedBox(height: 12),

                          // Retype Password field
                          Text(
                            'Retype Password',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: !_showPassword,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'Retype your password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(
                                      () => _showPassword = !_showPassword);
                                },
                              ),
                            ),
                            onSubmitted: (_) => _handleSignup(),
                          ),
                          const SizedBox(height: 16),

                          // Account Type Selection
                          Text(
                            'Account Type',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _isLoading
                                      ? null
                                      : () => setState(
                                          () => _accountType = 'CONSUMER'),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _accountType == 'CONSUMER'
                                          ? AppColors.electricBlue.withAlpha(26)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _accountType == 'CONSUMER'
                                            ? AppColors.electricBlue
                                            : (isDark
                                                ? AppColors.darkBorder
                                                : AppColors.lightBorder),
                                        width:
                                            _accountType == 'CONSUMER' ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.shopping_bag_outlined,
                                          size: 18,
                                          color: _accountType == 'CONSUMER'
                                              ? AppColors.electricBlue
                                              : (isDark
                                                  ? AppColors
                                                      .darkMutedForeground
                                                  : AppColors
                                                      .lightMutedForeground),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Consumer',
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontWeight:
                                                _accountType == 'CONSUMER'
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                            color: _accountType == 'CONSUMER'
                                                ? AppColors.electricBlue
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _isLoading
                                      ? null
                                      : () => setState(
                                          () => _accountType = 'SELLER'),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _accountType == 'SELLER'
                                          ? AppColors.electricBlue.withAlpha(26)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _accountType == 'SELLER'
                                            ? AppColors.electricBlue
                                            : (isDark
                                                ? AppColors.darkBorder
                                                : AppColors.lightBorder),
                                        width: _accountType == 'SELLER' ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.store_outlined,
                                          size: 18,
                                          color: _accountType == 'SELLER'
                                              ? AppColors.electricBlue
                                              : (isDark
                                                  ? AppColors
                                                      .darkMutedForeground
                                                  : AppColors
                                                      .lightMutedForeground),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Seller',
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: _accountType == 'SELLER'
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: _accountType == 'SELLER'
                                                ? AppColors.electricBlue
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Remember me
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: _isLoading
                                    ? null
                                    : (value) {
                                        setState(
                                            () => _rememberMe = value ?? false);
                                      },
                              ),
                              Expanded(
                                child: Text(
                                  'Remember me for 30 days',
                                  style: textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Signup button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSignup,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        strokeCap: StrokeCap.round,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Create Account',
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Login link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: textTheme.bodySmall,
                              ),
                              TextButton(
                                onPressed: () => context.go('/Login'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Sign in',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.electricBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
}
