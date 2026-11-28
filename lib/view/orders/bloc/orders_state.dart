part of 'orders_bloc.dart';

@immutable
final class OrdersState {
  const OrdersState({
    this.activeTab = OrdersFilterTab.open,
    this.isLoading = false,
  });

  final OrdersFilterTab activeTab;
  final bool isLoading;

  OrdersState copyWith({
    OrdersFilterTab? activeTab,
    bool? isLoading,
  }) {
    return OrdersState(
      activeTab: activeTab ?? this.activeTab,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
