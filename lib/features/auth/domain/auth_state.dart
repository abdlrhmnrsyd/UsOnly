import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import 'user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserModel?>? _profileSubscription;

  @override
  AuthState build() {
    ref.onDispose(() {
      _authSubscription?.cancel();
      _profileSubscription?.cancel();
    });

    _listenToAuthChanges();
    return AuthState.initial();
  }

  void _listenToAuthChanges() {
    try {
      final repo = ref.read(authRepositoryProvider);
      _authSubscription?.cancel();
      _authSubscription = repo.authStateChanges.listen((user) {
        if (user != null) {
          _listenToUserProfile(user.uid);
        } else {
          _profileSubscription?.cancel();
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      }, onError: (e) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      });
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  void _listenToUserProfile(String uid) {
    try {
      final repo = ref.read(authRepositoryProvider);
      _profileSubscription?.cancel();
      _profileSubscription = repo.watchUserProfile(uid).listen((profile) {
        if (profile != null) {
          state = AuthState(status: AuthStatus.authenticated, user: profile);
        } else {
          // Fallback user from Firebase Auth
          final fbUser = repo.currentFirebaseUser;
          if (fbUser != null) {
            state = AuthState(
              status: AuthStatus.authenticated,
              user: UserModel(
                uid: fbUser.uid,
                email: fbUser.email ?? '',
                displayName: fbUser.displayName ?? 'User',
              ),
            );
          }
        }
      }, onError: (e) {
        final fbUser = repo.currentFirebaseUser;
        if (fbUser != null) {
          state = AuthState(
            status: AuthStatus.authenticated,
            user: UserModel(
              uid: fbUser.uid,
              email: fbUser.email ?? '',
              displayName: fbUser.displayName ?? 'User',
            ),
          );
        }
      });
    } catch (_) {}
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
          );
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on FirebaseAuthException catch (e) {
      String msg = 'Gagal masuk: ${e.message ?? e.code}';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Email atau kata sandi salah.';
      } else if (e.code == 'invalid-email') {
        msg = 'Format alamat email tidak valid.';
      } else if (e.code == 'network-request-failed') {
        msg = 'Koneksi gagal. Periksa jaringan internet Anda.';
      } else if (e.code == 'too-many-requests') {
        msg = 'Terlalu banyak percobaan. Silakan coba lagi nanti.';
      }
      state = AuthState(status: AuthStatus.error, errorMessage: msg);
    } on TimeoutException {
      final currentUser = ref.read(authRepositoryProvider).currentFirebaseUser;
      if (currentUser != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: UserModel(
            uid: currentUser.uid,
            email: currentUser.email ?? email,
            displayName: currentUser.displayName ?? 'User',
          ),
        );
        return;
      }
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Koneksi lambat (timeout). Silakan periksa jaringan internet Anda.',
      );
    } catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> register(String email, String password, String displayName) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await ref.read(authRepositoryProvider).register(
            email: email,
            password: password,
            displayName: displayName,
          );
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on FirebaseAuthException catch (e) {
      String msg = 'Pendaftaran gagal: ${e.message ?? e.code}';
      if (e.code == 'email-already-in-use') {
        // If account was already created during previous attempt, automatically log in
        try {
          final existingUser = await ref.read(authRepositoryProvider).login(
                email: email,
                password: password,
              );
          state = AuthState(status: AuthStatus.authenticated, user: existingUser);
          return;
        } catch (_) {
          msg = 'Email ini sudah terdaftar. Silakan langsung masuk di halaman login.';
        }
      } else if (e.code == 'weak-password') {
        msg = 'Kata sandi minimal 6 karakter.';
      } else if (e.code == 'invalid-email') {
        msg = 'Format alamat email tidak valid.';
      } else if (e.code == 'network-request-failed') {
        msg = 'Koneksi gagal. Periksa jaringan internet Anda.';
      } else if (e.code == 'operation-not-allowed') {
        msg = 'Metode pendaftaran email belum diaktifkan di Firebase Console.';
      }
      state = AuthState(status: AuthStatus.error, errorMessage: msg);
    } on TimeoutException {
      // Check if user was successfully registered on Firebase despite timeout
      final currentUser = ref.read(authRepositoryProvider).currentFirebaseUser;
      if (currentUser != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: UserModel(
            uid: currentUser.uid,
            email: currentUser.email ?? email,
            displayName: currentUser.displayName ?? displayName,
          ),
        );
        return;
      }
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Koneksi ke server timeout. Silakan periksa jaringan internet atau coba klik Masuk (Login).',
      );
    } catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await ref.read(authRepositoryProvider).sendPasswordReset(email);
  }

  void setCoupleId(String coupleId) {
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(coupleId: coupleId),
      );
      try {
        ref.read(authRepositoryProvider).updateCoupleId(coupleId);
      } catch (_) {}
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Account deletion requires recent login. Please re-login and try again.',
      );
    }
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
