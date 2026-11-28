import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

part 'ipo_event.dart';
part 'ipo_state.dart';

class IpoBloc extends Bloc<IpoEvent, IpoState> {
  IpoBloc() : super(const IpoState()) {
    on<IpoStarted>(_onStarted);
    on<IpoTabChanged>(_onTabChanged);
    on<IpoRefreshed>(_onRefreshed);
  }

  void _onStarted(IpoStarted event, Emitter<IpoState> emit) {
    emit(state.copyWith(isLoading: false));
  }

  void _onTabChanged(IpoTabChanged event, Emitter<IpoState> emit) {
    if (event.tab == state.activeTab) return;
    emit(state.copyWith(activeTab: event.tab));
  }

  Future<void> _onRefreshed(IpoRefreshed event, Emitter<IpoState> emit) async {
    emit(state.copyWith(isLoading: true));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    emit(state.copyWith(isLoading: false));
  }
}
