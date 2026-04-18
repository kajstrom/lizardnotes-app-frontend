import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/colour_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_field.dart';
import '../widgets/auth_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      switch (next.status) {
        case AuthStatus.requiresNewPassword:
          context.go(RouteNames.setPassword);
        case AuthStatus.requiresMfaSetup:
          context.go(RouteNames.mfaSetupScan);
        case AuthStatus.requiresMfaCode:
          context.go(RouteNames.mfaCode);
        case AuthStatus.authenticated:
          context.go(RouteNames.appFolders);
        default:
          break;
      }
    });

    final auth = ref.watch(authProvider);
    final isLoading = auth.status == AuthStatus.loading;

    return AuthShell(
      title: 'Sign in',
      subtitle: 'Welcome back to LizardNotes.',
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
                  style: const TextStyle(color: LnColors.lnDanger),
                  textAlign: TextAlign.center,
                ),
              ),
            AuthField(
              label: 'Email',
              child: TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(),
                style: const TextStyle(
                    fontSize: 14, color: LnColors.lnText),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your email' : null,
              ),
            ),
            const SizedBox(height: 16),
            AuthField(
              label: 'Password',
              child: TextFormField(
                controller: _passwordCtrl,
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                style: const TextStyle(
                    fontSize: 14, color: LnColors.lnText),
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your password' : null,
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
                  : const Text('Sign in'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go(RouteNames.forgotPassword),
              child: const Text('Forgot password?'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(authProvider.notifier)
        .signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
  }
}
