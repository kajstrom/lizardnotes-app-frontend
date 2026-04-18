import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../providers/auth_provider.dart';
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
      if (next.status == AuthStatus.unauthenticated && next.errorMessage == null) {
        // Reset complete — go back to login.
        context.go(RouteNames.login);
      }
    });

    final auth = ref.watch(authProvider);
    final isLoading = auth.status == AuthStatus.loading;
    final email = auth.pendingEmail ?? '';

    return AuthShell(
      title: 'Set new password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthInfoBox(
              variant: AuthInfoBoxVariant.green,
              message:
                  'A reset code has been sent to your email. '
                  'Enter it below along with your new password.',
            ),
            const SizedBox(height: 20),
            if (auth.status == AuthStatus.error && auth.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  auth.errorMessage!,
                  style: const TextStyle(color: Color(0xFFc0524a)),
                  textAlign: TextAlign.center,
                ),
              ),
            TextFormField(
              controller: _codeCtrl,
              decoration: const InputDecoration(labelText: 'Reset code'),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter the reset code' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              decoration: InputDecoration(
                labelText: 'New password',
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureNew ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              obscureText: _obscureNew,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.length < 8) return 'Minimum 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmCtrl,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(email),
              validator: (v) =>
                  v != _passwordCtrl.text ? 'Passwords do not match' : null,
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
                  : () => ref
                      .read(authProvider.notifier)
                      .forgotPassword(email),
              child: const Text('Resend code'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(String email) {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).confirmForgotPassword(
          email,
          _codeCtrl.text.trim(),
          _passwordCtrl.text,
        );
  }
}
