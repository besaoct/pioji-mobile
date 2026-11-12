import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/context_ext.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/logo.dart';
import '../../../core/widgets/states.dart';
import '../application/auth_controller.dart';
import '../domain/user.dart';
import '../../../core/design/app_icons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _banner;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    final errs = <String, String>{
      if (email.isEmpty) 'email': 'Enter your email.',
      if (password.isEmpty) 'password': 'Enter your password.',
    };
    setState(() {
      _errors = errs;
      _banner = null;
    });
    if (errs.isNotEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final failure = await ref.read(authControllerProvider.notifier).signIn(email, password);
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (failure) {
        case null:
          break;
        case ValidationFailure(:final fieldErrors):
          _errors = fieldErrors;
          _banner = fieldErrors.isEmpty ? failure.message : null;
        case UnauthorizedFailure():
          _banner = "That email and password don't match.";
        case OfflineFailure():
          _banner = "You're offline. Connect to sign in.";
        default:
          _banner = failure.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auth = ref.watch(authControllerProvider).value;
    final expired = auth is SignedOut && auth.sessionExpired;
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, 48, AppSpace.xl, AppSpace.xxl),
            children: [
              const Center(child: AppLogo(size: 56)),
              const SizedBox(height: AppSpace.lg),
              const Text('Sign in', textAlign: TextAlign.center, style: AppText.largeTitle),
              const SizedBox(height: AppSpace.xs),
              Text('Use your admin account to continue.',
                  textAlign: TextAlign.center, style: AppText.callout.copyWith(color: c.textSecondary)),
              const SizedBox(height: AppSpace.xxl + 4),
              if (expired && _banner == null) ...[
                const FormBanner('Your session expired. Sign in again.'),
                const SizedBox(height: AppSpace.md),
              ],
              if (_banner != null) ...[FormBanner(_banner!), const SizedBox(height: AppSpace.md)],
              AutofillGroup(
                child: GroupedSection(
                  children: [
                    FieldInput(
                      label: 'Email',
                      hint: 'name@company.com',
                      controller: _email,
                      error: _errors['email'],
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email, AutofillHints.username],
                    ),
                    FieldInput(
                      label: 'Password',
                      hint: 'Password',
                      controller: _password,
                      error: _errors['password'],
                      obscureText: _hidden,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      autofillHints: const [AutofillHints.password],
                      trailing: Semantics(
                        button: true,
                        label: _hidden ? 'Show password' : 'Hide password',
                        child: GestureDetector(
                          onTap: () => setState(() => _hidden = !_hidden),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: AppIcon(_hidden ? AppIcons.eye : AppIcons.eyeOff, color: c.textTertiary, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: LinkButton(
                  label: 'Forgot password?',
                  style: AppText.callout,
                  onPressed: () => context.toast('Reset your password from the web admin panel.'),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              PrimaryButton(label: 'Sign in', onPressed: _submit, loading: _busy),
              const SizedBox(height: AppSpace.xxxl),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  LinkButton(label: 'Terms of service', style: AppText.footnote, onPressed: () => context.pushNamed(Routes.legal, pathParameters: {'doc': 'terms'})),
                  LinkButton(label: 'Privacy policy', style: AppText.footnote, onPressed: () => context.pushNamed(Routes.legal, pathParameters: {'doc': 'privacy'})),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
