import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_shell.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.status == AuthStatus.loading;

    return AuthShell(
      title: 'Reset password',
      subtitle: "We'll send a reset code to your email.",
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your email' : null,
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
                  : const Text('Send reset code'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go(RouteNames.login),
              child: const Text('Back to sign in'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();
    await ref.read(authProvider.notifier).forgotPassword(email);
    if (mounted && ref.read(authProvider).status != AuthStatus.error) {
      context.go(RouteNames.forgotPasswordConfirm);
    }
  }
}
