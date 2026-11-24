part of 'home_bloc.dart';

sealed class HomeState {
  const HomeState();
}

final class HomeInitial extends HomeState {
  const HomeInitial();
}

final class HomeLoading extends HomeState {
  const HomeLoading();
}

final class HomeLoaded extends HomeState {
  final UserProfile profile;

  const HomeLoaded(this.profile);
}

final class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);
}
