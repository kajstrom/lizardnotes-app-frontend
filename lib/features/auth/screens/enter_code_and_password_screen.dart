import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/colour_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_field.dart';
import '../widgets/auth_info_box.dart';
import '../widgets/auth_shell.dart';

class EnterCodeAndPasswordScreen extends ConsumerStatefulWidget {
  const EnterCodeAndPasswordScreen({super.key});

  @override
  ConsumerState<EnterCodeAndPasswordScreen> createState() =>
      _EnterCodeAndPasswordScreenState();
}

class _EnterCodeAndPasswordScreenState
    extends ConsumerState<EnterCodeAndPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.status == AuthStatus.unauthenticated &&
          next.errorMessage == null) {
        // Reset complete — go back to login.
        context.go(RouteNames.login);
      }
    });

    final auth = ref.watch(authProvider);
    final isLoading = auth.status == AuthStatus.loading;
    final email = auth.pendingEmail ?? '';

    return AuthShell(
      title: 'Enter reset code',
      subtitle:
          'Check your inbox and enter the code below with your new password.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthInfoBox(
              variant: AuthInfoBoxVariant.green,
              message: email.isNotEmpty
                  ? 'A code was sent to $email. It expires in 15 minutes.'
                  : 'A reset code has been sent to your email. It expires in 15 minutes.',
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
              label: 'Code from email',
              child: TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  hintText: '6-digit code',
                ),
                style: const TextStyle(fontSize: 14, color: LnColors.lnText),
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter the reset code' : null,
              ),
            ),
            const SizedBox(height: 16),
            AuthField(
              label: 'New password',
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
                onFieldSubmitted: (_) => _submit(email),
                validator: (v) =>
                    v != _passwordCtrl.text ? 'Passwords do not match' : null,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : () => _submit(email),
              child: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Reset password'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: isLoading || email.isEmpty
                  ? null
                  : () => ref.read(authProvider.notifier).forgotPassword(email),
              child: const Text('Resend code'),
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _submit(String email) {
    if (!_formKey.currentState!.validate()) return;
    TextInput.finishAutofillContext();
    ref.read(authProvider.notifier).confirmForgotPassword(
          email,
          _codeCtrl.text.trim(),
          _passwordCtrl.text,
        );
  }
}
