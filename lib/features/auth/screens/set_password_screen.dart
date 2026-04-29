import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/colour_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_field.dart';
import '../widgets/auth_info_box.dart';
import '../widgets/auth_shell.dart';

class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.status == AuthStatus.loading;

    return AuthShell(
      title: 'Set a new password',
      subtitle:
          'Your account was created with a temporary password. Choose a new one to continue.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthInfoBox(
              variant: AuthInfoBoxVariant.amber,
              message:
                  'Temporary password expires in 24 hours. You must set a new password to finish signing in.',
            ),
            const SizedBox(height: 20),
            if (auth.status == AuthStatus.error && auth.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  auth.errorMessage!,
                  style: const TextStyle(color: LnColors.lnDanger),
                  textAlign: TextAlign.center,
                ),
              ),
            AuthField(
              label: 'New password',
              hint: 'Min. 8 characters, one number, one symbol.',
              child: TextFormField(
                controller: _passwordCtrl,
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureNew ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                style: const TextStyle(fontSize: 14, color: LnColors.lnText),
                obscureText: _obscureNew,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.length < 8) {
                    return 'Minimum 8 characters';
                  }
                  if (!RegExp(r'\d').hasMatch(v)) {
                    return 'Include at least one number';
                  }
                  if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(v)) {
                    return 'Include at least one symbol';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            AuthField(
              label: 'Confirm password',
              child: TextFormField(
                controller: _confirmCtrl,
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                style: const TextStyle(fontSize: 14, color: LnColors.lnText),
                obscureText: _obscureConfirm,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) =>
                    v != _passwordCtrl.text ? 'Passwords do not match' : null,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : _submit,
              child: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue'),
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    TextInput.finishAutofillContext();
    ref.read(authProvider.notifier).confirmNewPassword(_passwordCtrl.text);
  }
}
