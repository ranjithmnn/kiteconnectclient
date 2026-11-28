import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:kiteconnectclient/services/instrument_sync_service.dart';
import 'package:kiteconnectclient/utils/haptics/mico_haptics.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_nav_bar/expressive_nav_bar.dart';
import 'package:kiteconnectclient/view/home/bloc/home_bloc.dart';
import 'package:kiteconnectclient/view/home/widgets/profile_sheet.dart';
import 'package:kiteconnectclient/view/ipo/ipo_view.dart';
import 'package:kiteconnectclient/view/mf/mf_view.dart';
import 'package:kiteconnectclient/view/orders/orders_view.dart';
import 'package:kiteconnectclient/view/search/search.dart';
import 'package:kiteconnectclient/view/watchlist/watchlist_view.dart';
import 'package:material_ui/material_ui.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Kick off non-blocking daily instrument CSV sync & 08:35 AM IST timer.
    unawaited(InstrumentSyncService.instance.initialize());
  }

  static const List<ExpressiveNavItem> _navItems = [
    ExpressiveNavItem(
      icon: Icons.bookmark_border_rounded,
      selectedIcon: Icons.bookmark_rounded,
      label: 'Watchlist',
    ),
    ExpressiveNavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      label: 'Orders',
    ),
    ExpressiveNavItem(
      icon: Icons.pie_chart_outline_rounded,
      selectedIcon: Icons.pie_chart_rounded,
      label: 'MF',
    ),
    ExpressiveNavItem(
      icon: Icons.trending_up_rounded,
      selectedIcon: Icons.auto_graph_rounded,
      label: 'IPO',
    ),
  ];

  static const List<Widget> _pages = [
    WatchlistView(),
    OrdersView(),
    MfView(),
    IpoView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              _customHomeAppBar(context),
              Expanded(
                child: IndexedStack(index: _selectedIndex, children: _pages),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ExpressiveNavBar(
        currentIndex: _selectedIndex,
        items: _navItems,
        onTap: (index) => setState(() => _selectedIndex = index),
        action: ExpressiveNavAction(
          icon: Icons.candlestick_chart,
          tooltip: 'Search instruments',
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _customHomeAppBar(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
      Row(
        children: [
          SvgPicture.asset('assets/logo/kite.svg', height: 20),
          const SizedBox(width: 8),
          Text(
            'Kite',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
      Spacer(),
      IconButton(
        onPressed: () {
          MicroHaptics.microTick();
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SearchView()));
        },
        tooltip: 'Search',
        icon: Icon(Icons.search),
      ),
      BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          final avatarUrl = state is HomeLoaded
              ? state.profile.avatarUrl
              : null;
          return IconButton(
            onPressed: () => _handleProfileClick(context),
            icon: _ProfileAvatar(avatarUrl: avatarUrl),
          );
        },
      ),
    ],
  );

  void _handleProfileClick(BuildContext context) {
    MicroHaptics.microTick();
    final height = MediaQuery.sizeOf(context).height * 0.5;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorScheme.of(context).surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(minHeight: height, maxHeight: height),
      builder: (_) => const ProfileSheet(),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;

  const _ProfileAvatar({required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final iconColor = ColorScheme.of(context).onSurfaceVariant;
    final url = avatarUrl;
    if (url == null || url.isEmpty) {
      return Icon(Icons.person, color: iconColor);
    }

    return ClipPath(
      clipper: ShapeBorderClipper(
        shape: MaterialShapeBorder(shape: MaterialShapes.cookie9Sided),
      ),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 30,
        height: 30,
        fit: BoxFit.cover,
        placeholder: (_, _) => Icon(Icons.person, color: iconColor),
        errorWidget: (_, _, _) => Icon(Icons.person, color: iconColor),
      ),
    );
  }
}
