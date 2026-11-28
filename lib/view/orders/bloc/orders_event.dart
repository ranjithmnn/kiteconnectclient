part of 'orders_bloc.dart';

enum OrdersFilterTab {
  open('Open'),
  executed('Executed'),
  gtt('GTT');

  const OrdersFilterTab(this.label);
  final String label;
}

sealed class OrdersEvent {
  const OrdersEvent();
}

final class OrdersStarted extends OrdersEvent {
  const OrdersStarted();
}

final class OrdersTabChanged extends OrdersEvent {
  const OrdersTabChanged(this.tab);
  final OrdersFilterTab tab;
}

final class OrdersRefreshed extends OrdersEvent {
  const OrdersRefreshed();
}
