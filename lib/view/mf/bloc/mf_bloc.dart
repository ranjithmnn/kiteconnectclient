import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

part 'mf_event.dart';
part 'mf_state.dart';

class MfBloc extends Bloc<MfEvent, MfState> {
  MfBloc() : super(const MfState()) {
    on<MfStarted>(_onStarted);
    on<MfTabChanged>(_onTabChanged);
    on<MfRefreshed>(_onRefreshed);
  }

  void _onStarted(MfStarted event, Emitter<MfState> emit) {
    emit(state.copyWith(isLoading: false));
  }

  void _onTabChanged(MfTabChanged event, Emitter<MfState> emit) {
    if (event.tab == state.activeTab) return;
    emit(state.copyWith(activeTab: event.tab));
  }

  Future<void> _onRefreshed(MfRefreshed event, Emitter<MfState> emit) async {
    emit(state.copyWith(isLoading: true));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    emit(state.copyWith(isLoading: false));
  }
}
