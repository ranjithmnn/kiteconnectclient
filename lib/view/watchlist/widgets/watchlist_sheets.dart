import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiteconnectclient/model/instrument.dart';
import 'package:kiteconnectclient/model/watchlist.dart';
import 'package:kiteconnectclient/utils/haptics/mico_haptics.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_snack/expressive_snack.dart';
import 'package:kiteconnectclient/utils/widgets/primary_button.dart';
import 'package:kiteconnectclient/view/watchlist/bloc/watchlist_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// Opens a Material 3 Expressive bottom sheet to create a new watchlist or
/// rename an existing [existingWatchlist].
///
/// When [initialInstrument] is provided, the newly created watchlist
/// automatically includes that instrument.
Future<void> showWatchlistFormSheet(
  BuildContext context, {
  Watchlist? existingWatchlist,
  Instrument? initialInstrument,
  bool selectAfterCreate = true,
}) {
  MicroHaptics.microTick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ColorScheme.of(context).surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _WatchlistFormSheet(
      existingWatchlist: existingWatchlist,
      initialInstrument: initialInstrument,
      selectAfterCreate: selectAfterCreate,
    ),
  );
}

/// Opens a multi-watchlist picker bottom sheet allowing the user to add/remove
/// [instrument] across any of their watchlists or create a new watchlist on the spot.
Future<void> showWatchlistPickerSheet(
  BuildContext context, {
  required Instrument instrument,
}) {
  MicroHaptics.microTick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ColorScheme.of(context).surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _WatchlistPickerSheet(instrument: instrument),
  );
}

class _WatchlistFormSheet extends StatefulWidget {
  const _WatchlistFormSheet({
    this.existingWatchlist,
    this.initialInstrument,
    required this.selectAfterCreate,
  });

  final Watchlist? existingWatchlist;
  final Instrument? initialInstrument;
  final bool selectAfterCreate;

  @override
  State<_WatchlistFormSheet> createState() => _WatchlistFormSheetState();
}

class _WatchlistFormSheetState extends State<_WatchlistFormSheet> {
  static const List<String> _presetNames = [
    'Nifty F&O',
    'Long Term',
    'BankNifty',
    'IT & Tech',
    'Indices',
  ];

  late final TextEditingController _controller = TextEditingController(
    text: widget.existingWatchlist?.name ?? '',
  );

  bool get _isEditing => widget.existingWatchlist != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    final bloc = context.read<WatchlistBloc>();
    if (_isEditing) {
      bloc.add(
        WatchlistRenamed(
          watchlistId: widget.existingWatchlist!.id,
          newName: name,
        ),
      );
    } else {
      bloc.add(
        WatchlistCreated(
          name: name,
          initialInstrument: widget.initialInstrument,
          selectAfterCreate: widget.selectAfterCreate,
        ),
      );
    }

    Navigator.of(context).pop();
    showExpressiveSnack(
      context: context,
      message: _isEditing
          ? 'Renamed to "$name"'
          : widget.initialInstrument != null
          ? 'Created "$name" with ${widget.initialInstrument!.tradingsymbol}'
          : 'Created watchlist "$name"',
      type: ExpressiveSnackType.success,
      icon: Icons.check_circle_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 14, 24, 20 + bottomInset),
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
            Text(
              _isEditing ? 'Rename watchlist' : 'Create new watchlist',
              style: tt.titleLarge?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.initialInstrument != null) ...[
              const SizedBox(height: 4),
              Text(
                '${widget.initialInstrument!.tradingsymbol} will be added automatically.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            Material(
              color: cs.surfaceContainerHigh,
              shape: StadiumBorder(
                side: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 28,
                  onSubmitted: (_) => _submit(),
                  style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: 'e.g. Nifty Options, Core Portfolio',
                    hintStyle: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in _presetNames)
                    ActionChip(
                      label: Text(preset),
                      visualDensity: VisualDensity.compact,
                      shape: const StadiumBorder(),
                      onPressed: () {
                        MicroHaptics.microTick();
                        _controller
                          ..text = preset
                          ..selection = TextSelection.collapsed(
                            offset: preset.length,
                          );
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final valid = value.text.trim().isNotEmpty;
                return PrimaryButton(
                  label: _isEditing ? 'Save Name' : 'Create Watchlist',
                  onPressed: valid ? _submit : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchlistPickerSheet extends StatelessWidget {
  const _WatchlistPickerSheet({required this.instrument});

  final Instrument instrument;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = TextTheme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: BlocBuilder<WatchlistBloc, WatchlistState>(
          builder: (context, state) {
            return Column(
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add ${instrument.tradingsymbol}',
                            style: tt.titleMedium?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Choose one or more watchlists',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        showWatchlistFormSheet(
                          context,
                          initialInstrument: instrument,
                          selectAfterCreate: false,
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.watchlists.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.25),
                    ),
                    itemBuilder: (context, index) {
                      final wl = state.watchlists[index];
                      final isSaved = state.isInWatchlist(
                        wl.id,
                        instrument.instrumentToken,
                      );
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onTap: () {
                          MicroHaptics.microTick();
                          context.read<WatchlistBloc>().add(
                            WatchlistInstrumentToggled(
                              watchlistId: wl.id,
                              instrument: instrument,
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isSaved
                              ? cs.primaryContainer
                              : cs.surfaceContainerHighest,
                          child: Icon(
                            isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 18,
                            color: isSaved
                                ? cs.onPrimaryContainer
                                : cs.onSurfaceVariant,
                          ),
                        ),
                        title: Text(
                          wl.name,
                          style: tt.bodyLarge?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${wl.itemCount} ${wl.itemCount == 1 ? 'instrument' : 'instruments'}',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(
                          isSaved
                              ? Icons.check_circle_rounded
                              : Icons.add_circle_outline_rounded,
                          color: isSaved ? cs.primary : cs.onSurfaceVariant,
                        ),
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
