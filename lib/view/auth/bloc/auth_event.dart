part of 'auth_bloc.dart';

sealed class AuthEvent {
  const AuthEvent();
}

final class AuthLoginRequested extends AuthEvent {
  final BuildContext context;
  const AuthLoginRequested({required this.context});
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
