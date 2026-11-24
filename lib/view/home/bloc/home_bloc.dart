import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiteconnectclient/model/user_profile.dart';
import 'package:kiteconnectclient/repository/user_repo.dart';
import 'package:kiteconnectclient/services/remote/dio.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({UserRepository? userRepository})
    : _userRepository = userRepository ?? UserRepository(),
      super(const HomeInitial()) {
    on<HomeProfileRequested>(_onProfileRequested);
  }

  final UserRepository _userRepository;

  Future<void> _onProfileRequested(
    HomeProfileRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(const HomeLoading());
    try {
      final profile = await _userRepository.getProfile();
      emit(HomeLoaded(profile));
    } on ApiException catch (e) {
      emit(HomeError(e.message));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }
}
