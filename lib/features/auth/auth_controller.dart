import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/repository/space_providers.dart';
import 'auth_state.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final session = await ref.read(spaceRepositoryProvider).readSession();
    if (session.hasVault && (session.email != null || session.phone != null)) {
      return AuthState(
        isAuthenticated: true,
        email: session.email ?? (session.phone != null ? '${session.phone}@spacehere.local' : 'user@spacehere.vault'),
        telegramPhone: session.phone,
      );
    }
    return const AuthState.unauthenticated();
  }

  Future<void> initializeVault(AuthSetupDraft draft) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(spaceRepositoryProvider)
          .initializeVault(
            email: draft.email,
            telegramPhone: draft.telegramPhone,
            vaultPin: draft.vaultPin,
          );
      return AuthState(
        isAuthenticated: true,
        email: draft.email,
        telegramPhone: draft.telegramPhone,
      );
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    await ref.read(spaceRepositoryProvider).clearSession();
    state = const AsyncData(AuthState.unauthenticated());
  }
}
