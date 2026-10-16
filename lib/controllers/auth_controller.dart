import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/result.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({this.user, this.isLoading = false, this.errorMessage});

  bool get isAuthenticated => user != null;

  AuthState copyWith({User? user, bool? isLoading, String? errorMessage}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final GoTrueClient _auth;

  AuthController([GoTrueClient? auth])
      : _auth = auth ?? Supabase.instance.client.auth,
        super(AuthState(user: (auth ?? Supabase.instance.client.auth).currentUser)) {
    _auth.onAuthStateChange.listen((data) {
      state = state.copyWith(user: data.session?.user, isLoading: false);
    });
  }

  Future<Result<void>> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _auth.signInWithPassword(email: email, password: password);
      state = state.copyWith(user: response.user, isLoading: false);
      return const Success(null);
    } catch (e) {
      final msg = e is AuthException ? e.message : e.toString();
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return Failure(msg);
    }
  }

  Future<Result<void>> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _auth.signUp(email: email, password: password);
      state = state.copyWith(user: response.user, isLoading: false);
      return const Success(null);
    } catch (e) {
      final msg = e is AuthException ? e.message : e.toString();
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return Failure(msg);
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    await _auth.signOut();
    state = const AuthState();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController();
});
