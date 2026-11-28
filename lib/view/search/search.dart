import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiteconnectclient/model/instrument.dart';
import 'package:kiteconnectclient/model/watchlist.dart';
import 'package:kiteconnectclient/services/instrument_sync_service.dart';
import 'package:kiteconnectclient/utils/haptics/mico_haptics.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_snack/expressive_snack.dart';
import 'package:kiteconnectclient/view/search/bloc/search_bloc.dart';
import 'package:kiteconnectclient/view/watchlist/bloc/watchlist_bloc.dart';
import 'package:kiteconnectclient/view/watchlist/widgets/watchlist_sheets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

class SearchView extends StatelessWidget {
  const SearchView({super.key, this.initialWatchlistId});

  /// Optional target watchlist ID preselected when adding instruments.
  /// Defaults to the currently selected watchlist in [WatchlistBloc].
  final int? initialWatchlistId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchBloc()..add(const SearchStarted()),
      child: _SearchScaffold(initialWatchlistId: initialWatchlistId),
    );
  }
}

class _SearchScaffold extends StatefulWidget {
  const _SearchScaffold({this.initialWatchlistId});

  final int? initialWatchlistId;

  @override
  State<_SearchScaffold> createState() => _SearchScaffoldState();
}

class _SearchScaffoldState extends State<_SearchScaffold> {
  late final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode = FocusNode();
  int? _targetWatchlistId;

  @override
  void initState() {
    super.initState();
    _targetWatchlistId = widget.initialWatchlistId;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearQuery(BuildContext context) {
    _controller.clear();
    MicroHaptics.microTick();
    context.read<SearchBloc>().add(const SearchQueryChanged(''));
    _focusNode.requestFocus();
  }

  Watchlist? _resolveTargetWatchlist(WatchlistState wlState) {
    final targetId = _targetWatchlistId ?? wlState.selectedWatchlistId;
    if (targetId != null) {
      for (final w in wlState.watchlists) {
        if (w.id == targetId) return w;
      }
    }
    return wlState.selectedWatchlist;
  }

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<WatchlistBloc, WatchlistState>(
          builder: (context, wlState) {
            final targetWatchlist = _resolveTargetWatchlist(wlState);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 6),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _ExpressiveSearchField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: (value) => context.read<SearchBloc>().add(
                            SearchQueryChanged(value),
                          ),
                          onClear: () => _clearQuery(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (wlState.watchlists.isNotEmpty)
                  _TargetWatchlistBar(
                    watchlists: wlState.watchlists,
                    targetWatchlist: targetWatchlist,
                    onSelectWatchlist: (id) {
                      MicroHaptics.microTick();
                      setState(() => _targetWatchlistId = id);
                      context.read<WatchlistBloc>().add(WatchlistSelected(id));
                    },
                    onCreateWatchlist: () => showWatchlistFormSheet(context),
                  ),
                const _SegmentFilterStrip(),
                const _SyncBannerStrip(),
                const SizedBox(height: 4),
                Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
                Expanded(
                  child: BlocBuilder<SearchBloc, SearchState>(
                    builder: (context, state) {
                      final sync = state.syncStatus;

                      if (!sync.hasInstruments && sync.isSyncing) {
                        return _InitialSyncProgressView(status: sync);
                      }

                      if (!sync.hasInstruments &&
                          sync.phase == InstrumentSyncPhase.error) {
                        return _InitialSyncErrorView(
                          message:
                              sync.errorMessage ??
                              'Unable to load instrument directory.',
                          onRetry: () => context.read<SearchBloc>().add(
                            const SearchRetrySyncRequested(force: true),
                          ),
                        );
                      }

                      if (state.results.isEmpty && !state.isSearching) {
                        return _EmptySearchResultsView(query: state.query);
                      }

                      return _InstrumentResultsList(
                        query: state.query,
                        results: state.results,
                        targetWatchlist: targetWatchlist,
                        watchlistState: wlState,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TargetWatchlistBar extends StatelessWidget {
  const _TargetWatchlistBar({
    required this.watchlists,
    required this.targetWatchlist,
    required this.onSelectWatchlist,
    required this.onCreateWatchlist,
  });

  final List<Watchlist> watchlists;
  final Watchlist? targetWatchlist;
  final ValueChanged<int> onSelectWatchlist;
  final VoidCallback onCreateWatchlist;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Row(
        children: [
          Icon(
            Icons.bookmark_added_outlined,
            size: 15,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            'Adding to:',
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: watchlists.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  if (index == watchlists.length) {
                    return InkWell(
                      onTap: onCreateWatchlist,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: ShapeDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.6),
                          shape: const StadiumBorder(),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 14,
                              color: cs.onPrimaryContainer,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'New list',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final wl = watchlists[index];
                  final selected = wl.id == targetWatchlist?.id;
                  return InkWell(
                    onTap: () => onSelectWatchlist(wl.id),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: ShapeDecoration(
                        color: selected
                            ? cs.primaryContainer
                            : cs.surfaceContainerLow,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: selected
                                ? Colors.transparent
                                : cs.outlineVariant.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        wl.name,
                        style: tt.labelSmall?.copyWith(
                          color: selected
                              ? cs.onPrimaryContainer
                              : cs.onSurfaceVariant,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpressiveSearchField extends StatelessWidget {
  const _ExpressiveSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    return Material(
      color: cs.surfaceContainerHigh,
      shape: StadiumBorder(
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: onChanged,
                  style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Search eg: infy, nifty 24500 ce, gold',
                    hintStyle: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  if (value.text.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: onClear,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentFilterStrip extends StatelessWidget {
  const _SegmentFilterStrip();

  @override
  Widget build(BuildContext context) {
    final activeFilter = context.select((SearchBloc b) => b.state.filter);

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: InstrumentSegmentFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = InstrumentSegmentFilter.values[index];
          final isSelected = filter == activeFilter;
          return _FilterPill(
            label: filter.label,
            isSelected: isSelected,
            onTap: () {
              MicroHaptics.microTick();
              context.read<SearchBloc>().add(SearchFilterChanged(filter));
            },
          );
        },
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    return SingleMotionBuilder(
      motion: const MaterialSpringMotion.expressiveSpatialFast(),
      value: isSelected ? 1.0 : 0.0,
      builder: (context, t, _) {
        final clamped = t.clamp(0.0, 1.0);
        final bg = Color.lerp(
          cs.surfaceContainerLow,
          cs.secondaryContainer,
          clamped,
        )!;
        final fg = Color.lerp(
          cs.onSurfaceVariant,
          cs.onSecondaryContainer,
          clamped,
        )!;
        final border = Color.lerp(
          cs.outlineVariant.withValues(alpha: 0.5),
          Colors.transparent,
          clamped,
        )!;

        return Transform.scale(
          scale: (1.0 + 0.03 * t).clamp(0.92, 1.1),
          child: Material(
            color: bg,
            shape: StadiumBorder(side: BorderSide(color: border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const StadiumBorder(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: Text(
                    label,
                    style: tt.labelMedium?.copyWith(
                      color: fg,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SyncBannerStrip extends StatelessWidget {
  const _SyncBannerStrip();

  @override
  Widget build(BuildContext context) {
    final sync = context.select((SearchBloc b) => b.state.syncStatus);
    if (!sync.hasInstruments) {
      return const SizedBox.shrink();
    }

    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    if (sync.isSyncing) {
      final label = sync.phase == InstrumentSyncPhase.downloading
          ? "Updating today's instrument master…"
          : 'Indexing updated contracts…';
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: ShapeDecoration(
            color: cs.secondaryContainer.withValues(alpha: 0.6),
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (sync.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: ShapeDecoration(
            color: cs.errorContainer.withValues(alpha: 0.65),
            shape: const StadiumBorder(),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 15,
                color: cs.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Using cached instruments (${sync.indexedCount} symbols)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(color: cs.onErrorContainer),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                ),
                onPressed: () => context.read<SearchBloc>().add(
                  const SearchRetrySyncRequested(force: true),
                ),
                child: Text(
                  'Retry',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _InitialSyncProgressView extends StatelessWidget {
  const _InitialSyncProgressView({required this.status});

  final InstrumentSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);
    final progress = status.downloadProgress;
    final bool isDownloading = status.phase == InstrumentSyncPhase.downloading;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDownloading && progress != null)
              LoadingIndicator.containedDeterminate(progress: progress)
            else
              LoadingIndicator.contained(),
            const SizedBox(height: 20),
            Text(
              isDownloading
                  ? 'Downloading instruments…'
                  : 'Indexing instruments…',
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Happens once per trading day. Any symbol you type above will search automatically once ready.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialSyncErrorView extends StatelessWidget {
  const _InitialSyncErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 42, color: cs.error),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Download'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchResultsView extends StatelessWidget {
  const _EmptySearchResultsView({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 44,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              query.trim().isEmpty
                  ? 'Search equities, indices, futures & options'
                  : 'No matching instruments for "$query"',
              textAlign: TextAlign.center,
              style: tt.titleSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching by symbol, company name, or strike (e.g. "nifty 24500 ce").',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstrumentResultsList extends StatelessWidget {
  const _InstrumentResultsList({
    required this.query,
    required this.results,
    required this.targetWatchlist,
    required this.watchlistState,
  });

  final String query;
  final List<Instrument> results;
  final Watchlist? targetWatchlist;
  final WatchlistState watchlistState;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (query.trim().isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'Popular Indices & Equities (long-press + for multiple lists)',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: results.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: cs.outlineVariant.withValues(alpha: 0.25),
            ),
            itemBuilder: (context, index) {
              final instrument = results[index];
              final inTarget = targetWatchlist != null
                  ? watchlistState.isInWatchlist(
                      targetWatchlist!.id,
                      instrument.instrumentToken,
                    )
                  : false;

              return _InstrumentTile(
                instrument: instrument,
                isAddedToTarget: inTarget,
                onTap: () => _showInstrumentSheet(context, instrument),
                onToggleWatchlist: () =>
                    _toggleTargetWatchlist(context, instrument, inTarget),
                onLongPressWatchlist: () {
                  FocusScope.of(context).unfocus();
                  showWatchlistPickerSheet(context, instrument: instrument);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _toggleTargetWatchlist(
    BuildContext context,
    Instrument instrument,
    bool currentlyInTarget,
  ) {
    final wl = targetWatchlist;
    if (wl == null) {
      showWatchlistFormSheet(context, initialInstrument: instrument);
      return;
    }

    MicroHaptics.microTick();
    context.read<WatchlistBloc>().add(
      WatchlistInstrumentToggled(watchlistId: wl.id, instrument: instrument),
    );
    showExpressiveSnack(
      context: context,
      message: currentlyInTarget
          ? 'Removed ${instrument.tradingsymbol} from ${wl.name}'
          : 'Added ${instrument.tradingsymbol} to ${wl.name}',
      type: currentlyInTarget
          ? ExpressiveSnackType.info
          : ExpressiveSnackType.success,
      icon: currentlyInTarget
          ? Icons.bookmark_remove_outlined
          : Icons.bookmark_added_rounded,
      duration: const Duration(seconds: 2),
    );
  }

  void _showInstrumentSheet(BuildContext context, Instrument instrument) {
    MicroHaptics.microTick();
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorScheme.of(context).surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _InstrumentDetailSheet(instrument: instrument),
    );
  }
}

class _InstrumentTile extends StatelessWidget {
  const _InstrumentTile({
    required this.instrument,
    required this.isAddedToTarget,
    required this.onTap,
    required this.onToggleWatchlist,
    required this.onLongPressWatchlist,
  });

  final Instrument instrument;
  final bool isAddedToTarget;
  final VoidCallback onTap;
  final VoidCallback onToggleWatchlist;
  final VoidCallback onLongPressWatchlist;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _ExchangeBadge(
              exchange: instrument.segment == 'INDICES'
                  ? 'INDEX'
                  : instrument.exchange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instrument.tradingsymbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    instrument.displaySubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (instrument.lastPrice > 0) ...[
              const SizedBox(width: 10),
              Text(
                '₹${instrument.lastPrice.toStringAsFixed(2)}',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(width: 10),
            _WatchlistToggleButton(
              isAdded: isAddedToTarget,
              onTap: onToggleWatchlist,
              onLongPress: onLongPressWatchlist,
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchlistToggleButton extends StatelessWidget {
  const _WatchlistToggleButton({
    required this.isAdded,
    required this.onTap,
    required this.onLongPress,
  });

  final bool isAdded;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);

    return SingleMotionBuilder(
      motion: const MaterialSpringMotion.expressiveSpatialFast(),
      value: isAdded ? 1.0 : 0.0,
      builder: (context, t, _) {
        final clamped = t.clamp(0.0, 1.0);
        final bg = Color.lerp(
          cs.surfaceContainerHigh,
          cs.primaryContainer,
          clamped,
        )!;
        final fg = Color.lerp(
          cs.primary,
          cs.onPrimaryContainer,
          clamped,
        )!;

        return Transform.scale(
          scale: (1.0 + 0.06 * t).clamp(0.85, 1.2),
          child: Material(
            color: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isAdded
                    ? Colors.transparent
                    : cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  isAdded ? Icons.check_rounded : Icons.add_rounded,
                  size: 19,
                  color: fg,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExchangeBadge extends StatelessWidget {
  const _ExchangeBadge({required this.exchange});

  final String exchange;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    final (Color bg, Color fg) = switch (exchange) {
      'NSE' => (cs.primaryContainer, cs.onPrimaryContainer),
      'BSE' => (cs.tertiaryContainer, cs.onTertiaryContainer),
      'NFO' || 'BFO' => (cs.secondaryContainer, cs.onSecondaryContainer),
      'INDEX' => (cs.primary.withValues(alpha: 0.16), cs.primary),
      _ => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };

    return Container(
      constraints: const BoxConstraints(minWidth: 46),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        exchange,
        style: tt.labelSmall?.copyWith(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _InstrumentDetailSheet extends StatelessWidget {
  const _InstrumentDetailSheet({required this.instrument});

  final Instrument instrument;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _ExchangeBadge(
                  exchange: instrument.segment == 'INDICES'
                      ? 'INDEX'
                      : instrument.exchange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    instrument.tradingsymbol,
                    style: tt.titleLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (instrument.lastPrice > 0)
                  Text(
                    '₹${instrument.lastPrice.toStringAsFixed(2)}',
                    style: tt.titleMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            if (instrument.name.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                instrument.name,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SpecChip(
                  label: 'Token',
                  value: '${instrument.instrumentToken}',
                ),
                _SpecChip(label: 'Segment', value: instrument.segment),
                _SpecChip(label: 'Type', value: instrument.instrumentType),
                _SpecChip(label: 'Lot Size', value: '${instrument.lotSize}'),
                _SpecChip(label: 'Tick', value: '${instrument.tickSize}'),
                if (instrument.expiry.isNotEmpty)
                  _SpecChip(label: 'Expiry', value: instrument.expiry),
                if (instrument.strike > 0)
                  _SpecChip(label: 'Strike', value: '${instrument.strike}'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pop();
                  showWatchlistPickerSheet(context, instrument: instrument);
                },
                icon: const Icon(Icons.bookmarks_outlined, size: 18),
                label: const Text('Save to Watchlists'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: tt.labelLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
