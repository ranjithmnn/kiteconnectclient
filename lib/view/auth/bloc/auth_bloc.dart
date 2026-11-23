import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiteconnectclient/repository/auth_repo.dart';
import 'package:kiteconnectclient/services/remote/dio.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository(),
      super(const AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
  }

  final AuthRepository _authRepository;

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
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
}
