import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/telegram_config.dart';
import '../../core/theme/space_theme.dart';
import '../../services/repository/space_providers.dart';
import 'auth_controller.dart';
import 'auth_state.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _phoneController = TextEditingController(
    text: TelegramConfig.defaultPhone,
  );
  final _emailController = TextEditingController();
  bool _isSendingOtp = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [SpaceColors.canvas, Color(0xFF13213A), Color(0xFF171129)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: SpaceColors.cyan.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: SpaceColors.border),
                              ),
                              child: const Icon(
                                Icons.lock_rounded,
                                color: SpaceColors.cyan,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SpaceHere',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Decentralized encrypted storage vault',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Telegram Phone Number',
                            hintText: '+919281401356',
                            prefixIcon: Icon(
                              Icons.phone_rounded,
                              color: SpaceColors.cyan,
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().length < 8) {
                              return 'Enter a valid Telegram-linked phone number.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _pinController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Vault Security PIN',
                            hintText: 'Minimum 6 characters / PIN',
                            prefixIcon: Icon(
                              Icons.key_rounded,
                              color: SpaceColors.cyan,
                            ),
                            helperText:
                                'Used to derive your local AES-256 master key.',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().length < 6) {
                              return 'Use at least 6 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text(
                            'Optional Profile Email',
                            style: TextStyle(
                              fontSize: 13,
                              color: SpaceColors.muted,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email (Optional)',
                                  prefixIcon: Icon(
                                    Icons.alternate_email_rounded,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isSendingOtp || auth.isLoading
                                ? null
                                : _continueToOtp,
                            icon: _isSendingOtp || auth.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(
                              _isSendingOtp
                                  ? 'Sending OTP code...'
                                  : 'Send OTP & Continue',
                            ),
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: SpaceColors.danger),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continueToOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    final phone = _phoneController.text.trim();
    final pin = _pinController.text;
    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : '$phone@spacehere.local';

    try {
      await ref.read(telegramServiceProvider).sendPhoneOtp(phone);
      if (!mounted) return;

      context.go(
        '/telegram_otp',
        extra: AuthSetupDraft(
          email: email,
          vaultPin: pin,
          telegramPhone: phone,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to request Telegram OTP: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
      }
    }
  }
}
