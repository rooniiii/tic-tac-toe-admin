import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../theme/app_theme.dart';

/// Lets the signed-in admin change their own password (current password
/// required). Pops with true on success.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  static Future<void> show(BuildContext context) async {
    // Captured now: the drawer that opened the dialog may be gone later.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
    if (changed == true) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Your password was changed.')),
      );
    }
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  final AdminService _service = AdminService();

  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validateNew(String? v) {
    final value = v ?? '';
    if (value.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Add an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Add a lowercase letter';
    if (!RegExp(r'\d').hasMatch(value)) return 'Add a number';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Add a special character';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _service.changeOwnPassword(
        currentPassword: _current.text,
        newPassword: _new.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        counterText: '',
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      scrollable: true,
      title: const Text(
        'Change my password',
        style: TextStyle(color: AppTheme.neonCyan),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _current,
                obscureText: _obscure,
                maxLength: 128,
                autofillHints: const [AutofillHints.password],
                decoration: _decoration('Current password'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your current password' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _new,
                obscureText: _obscure,
                maxLength: 128,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _decoration('New password'),
                validator: _validateNew,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                maxLength: 128,
                decoration: _decoration('Confirm new password'),
                validator: (v) =>
                    v != _new.text ? 'Passwords do not match' : null,
                onFieldSubmitted: (_) => _save(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('CHANGE'),
        ),
      ],
    );
  }
}
