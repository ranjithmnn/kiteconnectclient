import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiteconnectclient/utils/haptics/mico_haptics.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_refresh_indicator/expressive_refresh_indicator.dart';
import 'package:kiteconnectclient/view/orders/bloc/orders_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

class OrdersView extends StatelessWidget {
  const OrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OrdersBloc()..add(const OrdersStarted()),
      child: const _OrdersContent(),
    );
  }
}

class _OrdersContent extends StatelessWidget {
  const _OrdersContent();

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    return BlocBuilder<OrdersBloc, OrdersState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: OrdersFilterTab.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tab = OrdersFilterTab.values[index];
                  final isSelected = tab == state.activeTab;
                  return SingleMotionBuilder(
                    motion: const MaterialSpringMotion.expressiveSpatialFast(),
                    value: isSelected ? 1.0 : 0.0,
                    builder: (context, t, _) {
                      final clamped = t.clamp(0.0, 1.0);
                      final bg = Color.lerp(
                        cs.surfaceContainerHigh,
                        cs.secondaryContainer,
                        clamped,
                      )!;
                      final fg = Color.lerp(
                        cs.onSurfaceVariant,
                        cs.onSecondaryContainer,
                        clamped,
                      )!;

                      return Material(
                        color: bg,
                        shape: const StadiumBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            MicroHaptics.microTick();
                            context.read<OrdersBloc>().add(
                              OrdersTabChanged(tab),
                            );
                          },
                          customBorder: const StadiumBorder(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Center(
                              child: Text(
                                tab.label,
                                style: tt.labelLarge?.copyWith(
                                  color: fg,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: ExpressiveRefreshIndicator(
                onRefresh: () async {
                  context.read<OrdersBloc>().add(const OrdersRefreshed());
                  await Future<void>.delayed(const Duration(milliseconds: 300));
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 110),
                  children: [
                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: ShapeDecoration(
                          color: cs.secondaryContainer,
                          shape: MaterialShapeBorder(
                            shape: MaterialShapes.cookie9Sided,
                          ),
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          size: 26,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No ${state.activeTab.label.toLowerCase()} orders',
                      textAlign: TextAlign.center,
                      style: tt.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Text(
                        'Place an order from your watchlist or search to track it here.',
                        textAlign: TextAlign.center,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
