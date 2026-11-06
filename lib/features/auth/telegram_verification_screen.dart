import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/space_theme.dart';
import '../../services/repository/space_providers.dart';
import 'auth_controller.dart';
import 'auth_state.dart';

class TelegramVerificationScreen extends ConsumerStatefulWidget {
  const TelegramVerificationScreen({super.key, required this.extra});

  final Object? extra;

  @override
  ConsumerState<TelegramVerificationScreen> createState() =>
      _TelegramVerificationScreenState();
}

class _TelegramVerificationScreenState
    extends ConsumerState<TelegramVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  AuthSetupDraft? get _draft =>
      widget.extra is AuthSetupDraft ? widget.extra! as AuthSetupDraft : null;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final draft = _draft;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: SpaceColors.cyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: SpaceColors.border),
                          ),
                          child: const Icon(
                            Icons.security_rounded,
                            color: SpaceColors.cyan,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verify Telegram',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            Text(
                              draft == null
                                  ? 'Missing phone'
                                  : draft.telegramPhone,
                              style: const TextStyle(
                                color: SpaceColors.cyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enter the OTP code Telegram sent to your app or phone.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 22,
                        letterSpacing: 6,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Enter OTP Code',
                        hintText: '12345',
                        prefixIcon: Icon(
                          Icons.sms_rounded,
                          color: SpaceColors.cyan,
                        ),
                      ),
                      onSubmitted: (_) => _verifyOtp(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            _isVerifying || auth.isLoading || draft == null
                            ? null
                            : _verifyOtp,
                        icon: _isVerifying || auth.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.lock_open_rounded),
                        label: Text(
                          _isVerifying
                              ? 'Authenticating...'
                              : 'Verify & Unlock Vault',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: _isResending || draft == null
                            ? null
                            : _resendOtp,
                        icon: _isResending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Resend Code'),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: SpaceColors.danger),
                      ),
                    ],
                    if (auth.hasError) ...[
                      const SizedBox(height: 14),
                      Text(
                        auth.error.toString(),
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
    );
  }

  Future<void> _verifyOtp() async {
    final draft = _draft;
    if (draft == null || _otpController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final verified = await ref
          .read(telegramServiceProvider)
          .verifyPhoneOtp(
            phoneNumber: draft.telegramPhone,
            otp: _otpController.text.trim(),
          );

      if (!verified || !mounted) {
        setState(() {
          _errorMessage = 'Invalid OTP code. Please check and re-enter.';
        });
        return;
      }

      await ref.read(authControllerProvider.notifier).initializeVault(draft);
      if (mounted) {
        final authState = ref.read(authControllerProvider);
        if (authState.hasError) {
          setState(() {
            _errorMessage = 'Vault initialization: ${authState.error}';
          });
        } else {
          context.go('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    final draft = _draft;
    if (draft == null) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      await ref.read(telegramServiceProvider).sendPhoneOtp(draft.telegramPhone);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP code resent via Telegram.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to resend code: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }
}
