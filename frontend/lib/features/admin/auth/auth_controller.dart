import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api_client.dart';
import '../../../core/constants.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.accessToken, this.refreshToken, this.email, this.error});

  final AuthStatus status;
  final String? accessToken;
  final String? refreshToken;
  final String? email;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated && accessToken != null;

  AuthState copyWith({
    AuthStatus? status,
    String? accessToken,
    String? refreshToken,
    String? email,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      email: email ?? this.email,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

const _accessTokenKey = 'admin_access_token';
const _refreshTokenKey = 'admin_refresh_token';
const _emailKey = 'admin_email';

/// Manages the single-administrator session: login, logout, and restoring
/// a previous session from secure storage on app start.
///
/// Security note: the access token is short-lived (30 min, enforced
/// server-side) and every mutating admin request still requires it to be
/// valid — persisting it in secure storage only saves the admin from
/// re-entering credentials on every page reload, it is not itself the
/// authorization boundary. See docs/SECURITY.md for the full threat model.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._storage) : super(const AuthState()) {
    _restoreSession();
  }

  final FlutterSecureStorage _storage;
  late final ApiClient _client = ApiClient(tokenProvider: () => state.accessToken);

  Future<void> _restoreSession() async {
    final access = await _storage.read(key: _accessTokenKey);
    final refresh = await _storage.read(key: _refreshTokenKey);
    final email = await _storage.read(key: _emailKey);
    if (access == null || refresh == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    state = AuthState(status: AuthStatus.authenticated, accessToken: access, refreshToken: refresh, email: email);
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(error: null, clearError: true);
    try {
      final client = ApiClient();
      final result = await client.post('/auth/login', body: {'email': email, 'password': password});
      final access = result['access_token'] as String;
      final refresh = result['refresh_token'] as String;
      final adminEmail = (result['admin'] as Map)['email'] as String;

      await _storage.write(key: _accessTokenKey, value: access);
      await _storage.write(key: _refreshTokenKey, value: refresh);
      await _storage.write(key: _emailKey, value: adminEmail);

      state = AuthState(status: AuthStatus.authenticated, accessToken: access, refreshToken: refresh, email: adminEmail);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.message);
      return false;
    } on ApiUnreachableException {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Could not reach the API at ${AppConfig.apiBaseUrl}. Is the backend running?',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _client.post('/auth/logout');
    } catch (_) {
      // Best-effort server-side revocation; local session is cleared regardless.
    }
    await _storage.deleteAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  ApiClient get client => _client;
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(secureStorageProvider));
});

/// The ApiClient used by public (non-admin) pages — no token attached.
final publicApiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// The ApiClient used by admin pages — automatically attaches the current
/// access token via [AuthController].
final adminApiClientProvider = Provider<ApiClient>((ref) => ref.watch(authControllerProvider.notifier).client);
