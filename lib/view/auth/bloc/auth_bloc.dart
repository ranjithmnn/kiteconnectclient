import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiteconnectclient/repository/auth_repo.dart';
import 'package:kiteconnectclient/services/remote/dio.dart';
import 'package:kiteconnectclient/utils/haptics/mico_haptics.dart';
import 'package:material_ui/material_ui.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository(),
      super(const AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  final AuthRepository _authRepository;

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    MicroHaptics.microTick();
    // await Future.delayed(const Duration(seconds: 2));
    // emit(const AuthError("Error"));
    // return;
    try {
      final completed = await _authRepository.login(event.context);
      if (!completed) {
        emit(const AuthFail());
        return;
      }
      emit(const AuthSuccess());
    } on ApiException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    MicroHaptics.microTick();
    try {
      final completed = await _authRepository.logout();
      if (!completed) {
        emit(const AuthFail());
        return;
      }
      emit(const AuthLogoutSuccess());
    } on ApiException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
