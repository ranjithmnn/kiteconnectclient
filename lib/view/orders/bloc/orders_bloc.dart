import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

part 'orders_event.dart';
part 'orders_state.dart';

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  OrdersBloc() : super(const OrdersState()) {
    on<OrdersStarted>(_onStarted);
    on<OrdersTabChanged>(_onTabChanged);
    on<OrdersRefreshed>(_onRefreshed);
  }

  void _onStarted(OrdersStarted event, Emitter<OrdersState> emit) {
    emit(state.copyWith(isLoading: false));
  }

  void _onTabChanged(OrdersTabChanged event, Emitter<OrdersState> emit) {
    if (event.tab == state.activeTab) return;
    emit(state.copyWith(activeTab: event.tab));
  }

  Future<void> _onRefreshed(
    OrdersRefreshed event,
    Emitter<OrdersState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    emit(state.copyWith(isLoading: false));
  }
}
