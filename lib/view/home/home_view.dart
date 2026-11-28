import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_nav_bar/expressive_nav_bar.dart';
import 'package:kiteconnectclient/view/home/bloc/home_bloc.dart';
import 'package:kiteconnectclient/view/home/widgets/profile_sheet.dart';
import 'package:kiteconnectclient/view/search/search.dart';
import 'package:material_ui/material_ui.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;

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
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    for (final item in _navItems)
                      Center(
                        child: Text(
                          item.label,
                          style: TextTheme.of(context).titleMedium?.copyWith(
                            color: ColorScheme.of(context).onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
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
          icon: Icons.search_rounded,
          tooltip: 'Search instruments',
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => SearchView()));
          },
        ),
      ),
    );
  }

  Widget _customHomeAppBar(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
