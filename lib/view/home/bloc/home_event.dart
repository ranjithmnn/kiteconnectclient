part of 'home_bloc.dart';

sealed class HomeEvent {
  const HomeEvent();
}

final class HomeProfileRequested extends HomeEvent {
  const HomeProfileRequested();
}

final class HomeReset extends HomeEvent {
  const HomeReset();
}

