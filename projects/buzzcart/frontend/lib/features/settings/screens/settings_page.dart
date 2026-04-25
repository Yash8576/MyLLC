import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/auth_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _messagesNotifications = true;
  bool _ordersNotifications = true;
  bool _isInitialized = false;
  bool _isSaving = false;
  bool _pendingVisibilitySave = false;
  Timer? _visibilitySaveDebounce;
  bool _isHibernated = false;
  String _visibilityMode = 'public';
  Map<String, bool> _visibilityPreferences = const {
    'photos': true,
    'videos': true,
    'reels': true,
    'purchases': true,
  };

  @override
  void dispose() {
    _visibilitySaveDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) {
      return;
    }

    _syncVisibilityState(user);
    _isInitialized = true;
  }

  void _syncVisibilityState(dynamic user) {
    final visibilityMode = (user.visibilityMode as String?)?.toLowerCase() ?? 'public';
    final preferences = Map<String, bool>.from(user.visibilityPreferences as Map<String, bool>);

    setState(() {
      _isHibernated = (user.status as String?)?.toLowerCase() == 'inactive';
      _visibilityMode = user.isSeller ? 'custom' : visibilityMode;
      _visibilityPreferences = {
        'photos': preferences['photos'] ?? true,
        'videos': preferences['videos'] ?? true,
        'reels': preferences['reels'] ?? true,
        'purchases': preferences['purchases'] ?? true,
      };
    });
  }

  Future<void> _updateSellerHibernate(bool value, AuthProvider authProvider) async {
    if (_isSaving) {
      return;
    }

    final previousValue = _isHibernated;
    setState(() {
      _isHibernated = value;
      _isSaving = true;
    });

    try {
      await authProvider.updateProfile({
        'status': value ? 'inactive' : 'active',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Account hibernated. Your profile is hidden until you unhibernate.'
                : 'Account unhibernated. Your profile is public again.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isHibernated = previousValue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update hibernate mode: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveVisibilitySettings(
    AuthProvider authProvider, {
    bool showSuccessMessage = false,
  }) async {
    final user = authProvider.user;
    if (user == null) return;

    if (_isSaving) {
      _pendingVisibilitySave = true;
      return;
    }

    setState(() => _isSaving = true);
    try {
        final visibilityMode = user.isSeller ? 'custom' : _visibilityMode;
      final privacyProfile = visibilityMode == 'private' ? 'PRIVATE' : 'PUBLIC';
      final visibilityPreferences = visibilityMode == 'custom'
          ? _visibilityPreferences
          : {
              'photos': visibilityMode == 'public',
              'videos': visibilityMode == 'public',
              'reels': visibilityMode == 'public',
              'purchases': visibilityMode == 'public',
            };

      await authProvider.updateProfile({
        'privacy_profile': privacyProfile,
        'visibility_mode': visibilityMode,
        'visibility_preferences': visibilityPreferences,
      });

      if (!mounted) return;
      setState(() {
        _visibilityMode = visibilityMode;
        _visibilityPreferences = Map<String, bool>.from(visibilityPreferences);
      });

      if (showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visibility settings saved')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save visibility settings: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      if (_pendingVisibilitySave) {
        _pendingVisibilitySave = false;
        unawaited(_saveVisibilitySettings(authProvider));
      }
    }
  }

  void _scheduleVisibilityAutoSave(AuthProvider authProvider) {
    _visibilitySaveDebounce?.cancel();
    _visibilitySaveDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      unawaited(_saveVisibilitySettings(authProvider));
    });
  }

  void _updateVisibilityMode(String mode, AuthProvider authProvider) {
    if (_visibilityMode == mode) {
      return;
    }

    setState(() {
      _visibilityMode = mode;
    });
    _scheduleVisibilityAutoSave(authProvider);
  }

  void _updateBucketVisibility(String bucket, bool value, AuthProvider authProvider) {
    if ((_visibilityPreferences[bucket] ?? true) == value) {
      return;
    }

    setState(() {
      _visibilityPreferences = {
        ..._visibilityPreferences,
        bucket: value,
      };
    });
    _scheduleVisibilityAutoSave(authProvider);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.palette),
                      SizedBox(width: 12),
                      Text(
                        'Appearance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customize how Buzz looks on your device',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _ThemeButton(
                              label: 'Light',
                              icon: Icons.light_mode,
                              selected: themeProvider.themeMode == ThemeMode.light,
                              onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ThemeButton(
                              label: 'Dark',
                              icon: Icons.dark_mode,
                              selected: themeProvider.themeMode == ThemeMode.dark,
                              onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ThemeButton(
                              label: 'System',
                              icon: Icons.settings_brightness,
                              selected: themeProvider.themeMode == ThemeMode.system,
                              onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Notifications Section
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.notifications),
                      SizedBox(width: 12),
                      Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Receive push notifications'),
                  value: _pushNotifications,
                  onChanged: (value) => setState(() => _pushNotifications = value),
                ),
                SwitchListTile(
                  title: const Text('Email Notifications'),
                  subtitle: const Text('Receive email updates'),
                  value: _emailNotifications,
                  onChanged: (value) => setState(() => _emailNotifications = value),
                ),
                SwitchListTile(
                  title: const Text('Messages'),
                  subtitle: const Text('Notifications for new messages'),
                  value: _messagesNotifications,
                  onChanged: (value) => setState(() => _messagesNotifications = value),
                ),
                SwitchListTile(
                  title: const Text('Orders'),
                  subtitle: const Text('Order updates and tracking'),
                  value: _ordersNotifications,
                  onChanged: (value) => setState(() => _ordersNotifications = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Privacy Section
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.privacy_tip),
                      SizedBox(width: 12),
                      Text(
                        'Privacy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Visibility',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (authProvider.isSeller)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      _isHibernated
                          ? 'Your seller account is hibernated and hidden from others.'
                          : 'Seller account visibility is custom. Configure what stays visible, or hibernate to hide everything.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                if (authProvider.isSeller)
                  SwitchListTile(
                    title: const Text('Hibernate Account'),
                    subtitle: const Text('Hide your profile and content until you turn this off'),
                    value: _isHibernated,
                    onChanged: _isSaving
                        ? null
                        : (value) => _updateSellerHibernate(value, authProvider),
                  ),
                if (!authProvider.isSeller)
                  RadioGroup<String>(
                    groupValue: _visibilityMode,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      _updateVisibilityMode(value, authProvider);
                    },
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          title: Text('Public'),
                          subtitle: Text('Anyone can view your profile and content'),
                          value: 'public',
                        ),
                        RadioListTile<String>(
                          title: Text('Private'),
                          subtitle: Text('Only followers can view your account'),
                          value: 'private',
                        ),
                        RadioListTile<String>(
                          title: Text('Custom'),
                          subtitle: Text('Choose what stays public and what stays private'),
                          value: 'custom',
                        ),
                      ],
                    ),
                  ),
                if (_visibilityMode == 'custom' || authProvider.isSeller) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Photos'),
                    subtitle: const Text('Show your photo gallery'),
                    value: _visibilityPreferences['photos'] ?? true,
                    onChanged: (value) => _updateBucketVisibility('photos', value, authProvider),
                  ),
                  SwitchListTile(
                    title: const Text('Videos'),
                    subtitle: const Text('Show your video gallery'),
                    value: _visibilityPreferences['videos'] ?? true,
                    onChanged: (value) => _updateBucketVisibility('videos', value, authProvider),
                  ),
                  SwitchListTile(
                    title: const Text('Reels'),
                    subtitle: const Text('Show your reels'),
                    value: _visibilityPreferences['reels'] ?? true,
                    onChanged: (value) => _updateBucketVisibility('reels', value, authProvider),
                  ),
                  SwitchListTile(
                    title: const Text('Purchases'),
                    subtitle: const Text('Show your purchases tab'),
                    value: _visibilityPreferences['purchases'] ?? true,
                    onChanged: (value) => _updateBucketVisibility('purchases', value, authProvider),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      if (_isSaving) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        const Text('Saving visibility...'),
                      ] else
                        const Text(
                          'Changes save automatically',
                          style: TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Account Section
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Edit Profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/profile');
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('About'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'BuzzCart',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '© 2024 BuzzCart. All rights reserved.',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && mounted) {
                  authProvider.logout();
                  if (mounted) {
                    navigator.pushReplacementNamed('/Login');
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Logged out successfully')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? Theme.of(context).primaryColor : Colors.grey,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Theme.of(context).primaryColor : null),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Theme.of(context).primaryColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
