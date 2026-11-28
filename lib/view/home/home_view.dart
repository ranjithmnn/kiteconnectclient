import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:kiteconnectclient/view/home/bloc/home_bloc.dart';
import 'package:kiteconnectclient/view/home/profile_sheet.dart';
import 'package:material_ui/material_ui.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: [_customHomeAppBar(context)]),
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
          SizedBox(width: 8),
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
