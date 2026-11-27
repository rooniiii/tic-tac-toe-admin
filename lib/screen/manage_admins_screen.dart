import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/admin_model.dart';
import '../services/admin_service.dart';
import '../theme/app_theme.dart';

class ManageAdminsScreen extends StatefulWidget {
  const ManageAdminsScreen({super.key});

  @override
  State<ManageAdminsScreen> createState() => _ManageAdminsScreenState();
}

class _ManageAdminsScreenState extends State<ManageAdminsScreen> {
  final AdminService _adminService = AdminService();

  final _createFormKey = GlobalKey<FormState>();

  final _nameFieldKey = GlobalKey<FormFieldState<String>>();
  final _emailFieldKey = GlobalKey<FormFieldState<String>>();
  final _passwordFieldKey = GlobalKey<FormFieldState<String>>();
  final _confirmFieldKey = GlobalKey<FormFieldState<String>>();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  late final Stream<List<AdminModel>> _adminsStream;

  bool _isCreating = false;
  bool _isAddingByUid = false;
  bool _showPassword = false;
  bool _submitted = false;

  String? _busyUid;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _adminsStream = _adminService.getAdmins();

    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus &&
          (_nameController.text.isNotEmpty || _submitted)) {
        _nameFieldKey.currentState?.validate();
      }
    });

    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus &&
          (_emailController.text.isNotEmpty || _submitted)) {
        _emailFieldKey.currentState?.validate();
      }
    });

    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus &&
          (_passwordController.text.isNotEmpty || _submitted)) {
        _passwordFieldKey.currentState?.validate();
      }
    });

    _confirmFocus.addListener(() {
      if (!_confirmFocus.hasFocus &&
          (_confirmController.text.isNotEmpty || _submitted)) {
        _confirmFieldKey.currentState?.validate();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();

    _uidController.dispose();
    _searchController.dispose();

    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();

    super.dispose();
  }

  String _cleanError(Object e) =>
      e.toString().replaceFirst('Exception: ', '');

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.surface,
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    Color actionColor = AppTheme.purple,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(color: AppTheme.neonCyan),
        ),
        content: Text(
          body,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );

    return result == true;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _createAdmin() async {
    _submitted = true;

    if (!_createFormKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _isCreating = true);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    try {
      await _adminService.createAdmin(
        name: name,
        email: email,
        password: _passwordController.text,
      );

      if (!mounted) return;

      _clearCreateForm();

      _showMessage(
        'Admin $name created. They can now sign in with $email.',
      );
    } on EmailAlreadyRegisteredException catch (e) {
      if (!mounted) return;

      if (!e.isKnownPlayer) {
        _showMessage(e.toString());
        return;
      }

      final promote = await _confirm(
        title: 'Email Already Registered',
        body: '${e.email} already belongs to the player '
            '"${e.playerName ?? e.email}".\n\n'
            'Grant Admin access to that existing account instead? '
            'They will sign in with their current game password.',
        action: 'Grant Access',
      );

      if (!promote) return;

      try {
        await _adminService.addAdmin(
          e.playerUid!,
          name: name.isNotEmpty ? name : (e.playerName ?? ''),
          email: e.email,
        );

        _clearCreateForm();

        _showMessage('Admin access granted to ${e.email}.');
      } catch (err) {
        _showMessage(_cleanError(err));
      }
    } catch (e) {
      _showMessage(_cleanError(e));
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _clearCreateForm() {
    _submitted = false;

    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmController.clear();

    _createFormKey.currentState?.reset();

    if (mounted) setState(() {});
  }

  Future<void> _addByUid() async {
    final uid = _uidController.text.trim();

    if (uid.isEmpty) {
      _showMessage('Please enter a Firebase Authentication UID.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _isAddingByUid = true);

    try {
      await _adminService.addAdmin(uid);

      if (!mounted) return;

      _uidController.clear();
      _showMessage('Admin access granted.');
    } catch (e) {
      _showMessage(_cleanError(e));
    } finally {
      if (mounted) {
        setState(() => _isAddingByUid = false);
      }
    }
  }

  Future<void> _sendReset(AdminModel admin) async {
    if (admin.email.isEmpty) {
      _showMessage(
        'No email on record for this Admin. '
        'It will be filled in the next time they sign in.',
      );
      return;
    }

    final ok = await _confirm(
      title: 'Send Password Reset?',
      body: 'A password reset link will be emailed to ${admin.email}.',
      action: 'Send Email',
    );

    if (!ok) return;

    setState(() => _busyUid = admin.uid);

    try {
      await _adminService.sendPasswordReset(admin.email);

      _showMessage('Password reset email sent to ${admin.email}.');
    } catch (e) {
      _showMessage(_cleanError(e));
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  Future<void> _removeAdmin(AdminModel admin, bool isCurrentAdmin) async {
    final ok = await _confirm(
      title: 'Remove Admin Access?',
      body: isCurrentAdmin
          ? 'You are removing your own Admin access. '
              'You will be signed out. Continue?'
          : '${admin.displayName} will lose access to this Admin Panel. '
              'Their login itself is not deleted.',
      action: 'Remove Access',
      actionColor: Colors.redAccent,
    );

    if (!ok || !mounted) return;

    setState(() => _busyUid = admin.uid);

    try {
      await _adminService.removeAdmin(admin.uid);
      _showMessage('Admin access removed.');
    } catch (e) {
      _showMessage(_cleanError(e));
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  InputDecoration _input(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      prefixIcon: Icon(icon, color: AppTheme.neonCyan),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppTheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppTheme.purple.withValues(alpha: 0.4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppTheme.neonCyan,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _primaryButton({
    required bool busy,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required String busyLabel,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(busy ? busyLabel : label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.purple,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Create Admin Form
  // ---------------------------------------------------------------------------

  Widget _createAdminForm() {
    return Form(
      key: _createFormKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        children: [
          // FULL NAME
          TextFormField(
            key: _nameFieldKey,
            controller: _nameController,
            focusNode: _nameFocus,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[a-zA-Z ]'),
              ),
            ],
            maxLength: 40,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            decoration: _input(
              'Full Name',
              Icons.badge_outlined,
            ).copyWith(
              helperText: 'Maximum 40 characters',
              helperStyle: const TextStyle(color: Colors.white54),
              counterStyle: const TextStyle(color: Colors.white54),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';

              if (value.isEmpty) {
                return _submitted ? 'Name is required' : null;
              }

              if (value.length < 3) {
                return 'Name must be at least 3 letters';
              }

              if (value.length > 40) {
                return 'Name must be at most 40 characters';
              }

              if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(value)) {
                return 'Only alphabets are allowed';
              }

              return null;
            },
            onChanged: (_) {
              if (_submitted ||
                  (_nameFieldKey.currentState?.hasError ?? false)) {
                _nameFieldKey.currentState?.validate();
              }
            },
          ),

          const SizedBox(height: 12),

          // EMAIL
          TextFormField(
            key: _emailFieldKey,
            controller: _emailController,
            focusNode: _emailFocus,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            maxLength: AdminService.maxEmailLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            decoration: _input(
              'Email Address',
              Icons.email_outlined,
            ).copyWith(
              helperText:
                  'Maximum ${AdminService.maxEmailLength} characters',
              helperStyle: const TextStyle(color: Colors.white54),
              counterStyle: const TextStyle(color: Colors.white54),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';

              if (value.isEmpty) {
                return _submitted ? 'Email is required' : null;
              }

              if (value.length > AdminService.maxEmailLength) {
                return 'At most ${AdminService.maxEmailLength} characters';
              }

              final ok = RegExp(
                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
              ).hasMatch(value);

              return ok ? null : 'Enter a valid email';
            },
            onChanged: (_) {
              if (_submitted ||
                  (_emailFieldKey.currentState?.hasError ?? false)) {
                _emailFieldKey.currentState?.validate();
              }
            },
          ),

          const SizedBox(height: 12),

          // PASSWORD
          TextFormField(
            key: _passwordFieldKey,
            controller: _passwordController,
            focusNode: _passwordFocus,
            style: const TextStyle(color: Colors.white),
            obscureText: !_showPassword,
            textInputAction: TextInputAction.next,
            maxLength: 40,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            decoration: _input(
              'Temporary Password',
              Icons.lock_outline,
              suffix: IconButton(
                onPressed: () {
                  setState(() => _showPassword = !_showPassword);
                },
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.white54,
                ),
              ),
            ).copyWith(
              helperText:
                  '8–40 characters • 1 uppercase (A-Z) • '
                  '1 lowercase (a-z) • 1 number (0-9) • '
                  '1 special character (!@#\$)',
              helperMaxLines: 3,
              helperStyle: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
              counterStyle: const TextStyle(color: Colors.white54),
            ),
            validator: (v) {
              final value = v ?? '';

              if (value.isEmpty) {
                return _submitted ? 'Password is required' : null;
              }

              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }

              if (value.length > 40) {
                return 'Password must be at most 40 characters';
              }

              if (!RegExp(r'[A-Z]').hasMatch(value)) {
                return 'At least one uppercase letter is required';
              }

              if (!RegExp(r'[a-z]').hasMatch(value)) {
                return 'At least one lowercase letter is required';
              }

              if (!RegExp(r'[0-9]').hasMatch(value)) {
                return 'At least one number is required';
              }

              if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(value)) {
                return 'At least one special character is required';
              }

              return null;
            },
            onChanged: (_) {
              if (_submitted ||
                  (_passwordFieldKey.currentState?.hasError ?? false)) {
                _passwordFieldKey.currentState?.validate();
              }

              if (_confirmController.text.isNotEmpty ||
                  _submitted ||
                  (_confirmFieldKey.currentState?.hasError ?? false)) {
                _confirmFieldKey.currentState?.validate();
              }
            },
          ),

          const SizedBox(height: 12),

          // CONFIRM PASSWORD
          TextFormField(
            key: _confirmFieldKey,
            controller: _confirmController,
            focusNode: _confirmFocus,
            style: const TextStyle(color: Colors.white),
            obscureText: !_showPassword,
            maxLength: 40,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            decoration: _input(
              'Confirm Password',
              Icons.lock_reset,
              suffix: IconButton(
                onPressed: () {
                  setState(() => _showPassword = !_showPassword);
                },
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.white54,
                ),
              ),
            ).copyWith(
              helperText: 'Maximum 40 characters',
              helperStyle: const TextStyle(color: Colors.white54),
              counterStyle: const TextStyle(color: Colors.white54),
            ),
            validator: (v) {
              final value = v ?? '';

              if (value.isEmpty) {
                return _submitted ? 'Please retype the password' : null;
              }

              if (value.length > 40) {
                return 'Password must be at most 40 characters';
              }

              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }

              return null;
            },
            onChanged: (_) {
              _confirmFieldKey.currentState?.validate();
            },
          ),

          const SizedBox(height: 12),

          _primaryButton(
            busy: _isCreating,
            onPressed: _createAdmin,
            icon: Icons.person_add_alt_1,
            label: 'Create Admin',
            busyLabel: 'Creating...',
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.neonYellow.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.neonYellow.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.neonYellow,
                  size: 19,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Creates a new login and gives it Admin access. Share '
                    'the temporary password privately; the new Admin can '
                    'change it with "Forgot password" on the login screen.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Add existing account by UID
  // ---------------------------------------------------------------------------

  Widget _addByUidSection() {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        iconColor: AppTheme.neonCyan,
        collapsedIconColor: Colors.white54,
        title: const Text(
          'Add existing account by UID',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        subtitle: const Text(
          'For a login that already exists in Firebase Authentication.',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
          ),
        ),
        children: [
          TextField(
            controller: _uidController,
            style: const TextStyle(color: Colors.white),
            decoration: _input(
              'Firebase Authentication UID',
              Icons.fingerprint,
            ),
          ),
          const SizedBox(height: 10),
          _primaryButton(
            busy: _isAddingByUid,
            onPressed: _addByUid,
            icon: Icons.verified_user_outlined,
            label: 'Grant Admin Access',
            busyLabel: 'Adding...',
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Admin Card
  // ---------------------------------------------------------------------------

  Widget _adminCard(AdminModel admin, bool isCurrentAdmin) {
    final isBusy = _busyUid == admin.uid;

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCurrentAdmin
              ? AppTheme.neonCyan.withValues(alpha: 0.6)
              : AppTheme.purple.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: isCurrentAdmin
                  ? AppTheme.neonCyan.withValues(alpha: 0.15)
                  : AppTheme.purple.withValues(alpha: 0.2),
              child: Icon(
                Icons.admin_panel_settings,
                color: isCurrentAdmin
                    ? AppTheme.neonCyan
                    : AppTheme.neonPink,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          admin.name.isNotEmpty ? admin.name : 'Admin',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (isCurrentAdmin) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.neonCyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              color: AppTheme.neonCyan,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    admin.email.isNotEmpty
                        ? admin.email
                        : 'Email not recorded',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    admin.uid,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (isBusy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.neonCyan,
                  ),
                ),
              )
            else ...[
              IconButton(
                tooltip: 'Send Password Reset Email',
                onPressed: () => _sendReset(admin),
                icon: const Icon(
                  Icons.lock_reset,
                  color: AppTheme.neonYellow,
                ),
              ),
              IconButton(
                tooltip: 'Remove Admin Access',
                onPressed: () => _removeAdmin(
                  admin,
                  isCurrentAdmin,
                ),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.neonCyan,
        title: const Text(
          'Admin Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<AdminModel>>(
        stream: _adminsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load Admin records. Check Firestore rules.',
                style: TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppTheme.neonCyan,
              ),
            );
          }

          final admins = snapshot.data ?? [];
          final currentUid = _adminService.currentAdminUid;
          final query = _searchQuery.toLowerCase();

          final filteredAdmins = admins.where((admin) {
            return admin.uid.toLowerCase().contains(query) ||
                admin.name.toLowerCase().contains(query) ||
                admin.email.toLowerCase().contains(query);
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppTheme.neonCyan.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      color: AppTheme.neonCyan,
                      size: 35,
                    ),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Text(
                        'Total Admin Accounts',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      admins.length.toString(),
                      style: const TextStyle(
                        color: AppTheme.neonCyan,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              _sectionTitle(
                'Create New Admin',
                'Set up a new Admin login with email and password.',
              ),

              const SizedBox(height: 13),

              _createAdminForm(),

              const SizedBox(height: 8),

              _addByUidSection(),

              const SizedBox(height: 20),

              _sectionTitle(
                'Existing Admins',
                'All Admins have the same permissions.',
              ),

              const SizedBox(height: 13),

              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: _input(
                  'Search name, email or UID',
                  Icons.search,
                  suffix: IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: const Icon(
                      Icons.clear,
                      color: Colors.white70,
                    ),
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim());
                },
              ),

              const SizedBox(height: 15),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Admin Accounts',
                    style: TextStyle(
                      color: AppTheme.neonCyan,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${filteredAdmins.length} found',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (filteredAdmins.isEmpty)
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.person_search,
                        color: AppTheme.neonPink,
                        size: 38,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No Admin accounts found.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              else
                ...filteredAdmins.map(
                  (admin) => _adminCard(
                    admin,
                    admin.uid == currentUid,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}