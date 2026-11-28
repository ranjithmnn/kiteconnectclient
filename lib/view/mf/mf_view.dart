import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiteconnectclient/utils/haptics/mico_haptics.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_refresh_indicator/expressive_refresh_indicator.dart';
import 'package:kiteconnectclient/view/mf/bloc/mf_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

class MfView extends StatelessWidget {
  const MfView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MfBloc()..add(const MfStarted()),
      child: const _MfContent(),
    );
  }
}

class _MfContent extends StatelessWidget {
  const _MfContent();

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    return BlocBuilder<MfBloc, MfState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: MfSectionTab.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tab = MfSectionTab.values[index];
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
                            context.read<MfBloc>().add(MfTabChanged(tab));
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
                  context.read<MfBloc>().add(const MfRefreshed());
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
                          Icons.pie_chart_rounded,
                          size: 26,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No mutual fund ${state.activeTab.label.toLowerCase()}',
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
                        'Your direct mutual fund investments and active SIPs will appear here.',
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
