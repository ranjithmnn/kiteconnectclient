import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiteconnectclient/model/instrument.dart';
import 'package:kiteconnectclient/model/watchlist.dart';
import 'package:kiteconnectclient/utils/haptics/mico_haptics.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_dialog/expressive_dialog.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_refresh_indicator/expressive_refresh_indicator.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_snack/expressive_snack.dart';
import 'package:kiteconnectclient/view/search/search.dart';
import 'package:kiteconnectclient/view/watchlist/bloc/watchlist_bloc.dart';
import 'package:kiteconnectclient/view/watchlist/widgets/watchlist_sheets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

class WatchlistView extends StatelessWidget {
  const WatchlistView({super.key});

  void _openAddInstruments(BuildContext context, int? watchlistId) {
    MicroHaptics.microTick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchView(initialWatchlistId: watchlistId),
      ),
    );
  }

  void _confirmDeleteWatchlist(BuildContext context, Watchlist watchlist) {
    MicroHaptics.microTick();
    showExpressiveDialog(
      context: context,
      title: 'Delete "${watchlist.name}"?',
      message:
          'All saved instruments inside this watchlist will be removed. You can add them again anytime.',
      icon: Icons.delete_outline_rounded,
      buttons: [
        ExpressiveDialogButton(label: 'Cancel', onPressed: () {}),
        ExpressiveDialogButton(
          label: 'Delete',
          role: .destructive,
          onPressed: () {
            context.read<WatchlistBloc>().add(WatchlistDeleted(watchlist.id));
            showExpressiveSnack(
              context: context,
              message: 'Deleted "${watchlist.name}"',
              type: ExpressiveSnackType.info,
              icon: Icons.delete_outline_rounded,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchlistBloc, WatchlistState>(
      builder: (context, state) {
        if (state.isLoading && state.watchlists.isEmpty) {
          return Center(child: LoadingIndicator.contained());
        }

        final selected = state.selectedWatchlist;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            _WatchlistSelectorStrip(
              watchlists: state.watchlists,
              selectedId: selected?.id,
              onSelect: (id) {
                MicroHaptics.microTick();
                context.read<WatchlistBloc>().add(WatchlistSelected(id));
              },
              onCreateTap: () => showWatchlistFormSheet(context),
            ),
            if (selected != null)
              _ActiveWatchlistToolbar(
                watchlist: selected,
                itemCount: state.activeItems.length,
                canDelete: state.watchlists.length > 1,
                onAddInstruments: () =>
                    _openAddInstruments(context, selected.id),
                onRename: () =>
                    showWatchlistFormSheet(context, existingWatchlist: selected),
                onDelete: () => _confirmDeleteWatchlist(context, selected),
              ),
            Expanded(
              child: state.activeItems.isEmpty
                  ? _EmptyWatchlistState(
                      watchlistName: selected?.name ?? 'Watchlist',
                      onAddTap: () =>
                          _openAddInstruments(context, selected?.id),
                    )
                  : ExpressiveRefreshIndicator(
                      onRefresh: () async {
                        context.read<WatchlistBloc>().add(
                          const WatchlistRefreshed(),
                        );
                        await Future<void>.delayed(
                          const Duration(milliseconds: 250),
                        );
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.only(top: 4, bottom: 110),
                        itemCount: state.activeItems.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          indent: 4,
                          endIndent: 4,
                          color: ColorScheme.of(
                            context,
                          ).outlineVariant.withValues(alpha: 0.25),
                        ),
                        itemBuilder: (context, index) {
                          final item = state.activeItems[index];
                          return _WatchlistInstrumentTile(
                            key: ValueKey(
                              '${selected?.id}_${item.instrumentToken}',
                            ),
                            instrument: item,
                            watchlist: selected!,
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _WatchlistSelectorStrip extends StatelessWidget {
  const _WatchlistSelectorStrip({
    required this.watchlists,
    required this.selectedId,
    required this.onSelect,
    required this.onCreateTap,
  });

  final List<Watchlist> watchlists;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: watchlists.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == watchlists.length) {
            return Material(
              color: cs.primaryContainer.withValues(alpha: 0.65),
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onCreateTap,
                customBorder: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: cs.onPrimaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'New',
                        style: tt.labelMedium?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final wl = watchlists[index];
          final isSelected = wl.id == selectedId;

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

              return Transform.scale(
                scale: (1.0 + 0.03 * t).clamp(0.92, 1.1),
                child: Material(
                  color: bg,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelect(wl.id),
                    customBorder: const StadiumBorder(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            wl.name,
                            style: tt.labelLarge?.copyWith(
                              color: fg,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          if (wl.itemCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: ShapeDecoration(
                                color: fg.withValues(alpha: 0.14),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                '${wl.itemCount}',
                                style: tt.labelSmall?.copyWith(
                                  color: fg,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ActiveWatchlistToolbar extends StatelessWidget {
  const _ActiveWatchlistToolbar({
    required this.watchlist,
    required this.itemCount,
    required this.canDelete,
    required this.onAddInstruments,
    required this.onRename,
    required this.onDelete,
  });

  final Watchlist watchlist;
  final int itemCount;
  final bool canDelete;
  final VoidCallback onAddInstruments;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 4),
      child: Row(
        children: [
          Text(
            '$itemCount ${itemCount == 1 ? 'instrument' : 'instruments'}',
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: onAddInstruments,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Instruments'),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              if (value == 'rename') {
                onRename();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Rename watchlist'),
                  ],
                ),
              ),
              if (canDelete)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: cs.error,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Delete watchlist',
                        style: TextStyle(color: cs.error),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyWatchlistState extends StatelessWidget {
  const _EmptyWatchlistState({
    required this.watchlistName,
    required this.onAddTap,
  });

  final String watchlistName;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: ShapeDecoration(
                color: cs.primaryContainer,
                shape: MaterialShapeBorder(shape: MaterialShapes.cookie9Sided),
              ),
              child: Icon(
                Icons.bookmark_add_outlined,
                size: 28,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Nothing in "$watchlistName" yet',
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Search from 100,000+ indexed equities, indices, futures & options to build your watchlist.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Search & Add Instruments'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchlistInstrumentTile extends StatelessWidget {
  const _WatchlistInstrumentTile({
    super.key,
    required this.instrument,
    required this.watchlist,
  });

  final Instrument instrument;
  final Watchlist watchlist;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);
    final badgeLabel = instrument.segment == 'INDICES'
        ? 'INDEX'
        : instrument.exchange;

    final (Color badgeBg, Color badgeFg) = switch (badgeLabel) {
      'NSE' => (cs.primaryContainer, cs.onPrimaryContainer),
      'BSE' => (cs.tertiaryContainer, cs.onTertiaryContainer),
      'NFO' || 'BFO' => (cs.secondaryContainer, cs.onSecondaryContainer),
      'INDEX' => (cs.primary.withValues(alpha: 0.16), cs.primary),
      _ => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };

    return Dismissible(
      key: ValueKey('dismiss_${watchlist.id}_${instrument.instrumentToken}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline_rounded, color: cs.onErrorContainer),
      ),
      onDismissed: (_) {
        context.read<WatchlistBloc>().add(
          WatchlistInstrumentRemoved(
            watchlistId: watchlist.id,
            instrumentToken: instrument.instrumentToken,
          ),
        );
        showExpressiveSnack(
          context: context,
          message: 'Removed ${instrument.tradingsymbol} from ${watchlist.name}',
          type: ExpressiveSnackType.info,
          icon: Icons.bookmark_remove_outlined,
        );
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showWatchlistPickerSheet(context, instrument: instrument),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            instrument.tradingsymbol,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyLarge?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            badgeLabel,
                            style: tt.labelSmall?.copyWith(
                              color: badgeFg,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      instrument.displaySubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    instrument.lastPrice > 0
                        ? '₹${instrument.lastPrice.toStringAsFixed(2)}'
                        : '—',
                    style: tt.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Prev. Close',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
