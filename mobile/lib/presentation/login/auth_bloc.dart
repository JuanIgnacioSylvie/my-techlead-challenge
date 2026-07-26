import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api_exception.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

// ----- Eventos -----

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthLoginSubmitted extends AuthEvent {
  final String username;
  final String password;

  const AuthLoginSubmitted({required this.username, required this.password});

  @override
  List<Object?> get props => [username, password];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

// ----- Estados -----

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final Sesion sesion;

  const AuthAuthenticated(this.sesion);

  @override
  List<Object?> get props => [sesion];
}

class AuthFailure extends AuthState {
  final String mensaje;

  const AuthFailure(this.mensaje);

  @override
  List<Object?> get props => [mensaje];
}

// ----- Bloc -----

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(const AuthInitial()) {
    on<AuthLoginSubmitted>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onLogin(
      AuthLoginSubmitted event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final sesion = await authRepository.login(event.username, event.password);
      emit(AuthAuthenticated(sesion));
    } on ApiException catch (e) {
      emit(AuthFailure(e.message));
    }
  }

  Future<void> _onLogout(
      AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await authRepository.logout();
    emit(const AuthInitial());
  }
}
