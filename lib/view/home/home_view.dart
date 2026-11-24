import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:kiteconnectclient/view/home/bloc/home_bloc.dart';
import 'package:kiteconnectclient/view/profile/profile_view.dart';
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
          child: Column(
            children: [_customHomeAppBar()],
          ),
        ),
      ),
    );
  }

  Widget _customHomeAppBar() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      SvgPicture.asset('assets/logo/kite.svg', height: 20),
      BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          final avatarUrl = state is HomeLoaded ? state.profile.avatarUrl : null;
          return IconButton(
            onPressed: () => _handleProfileClick(context),
            icon: _ProfileAvatar(avatarUrl: avatarUrl),
          );
        },
      ),
    ],
  );

  void _handleProfileClick(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.5;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(minHeight: height, maxHeight: height),
      builder: (_) => const ProfileView(),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;

  const _ProfileAvatar({required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    if (url == null || url.isEmpty) {
      return const Icon(Icons.person);
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: 30,
        height: 30,
        fit: BoxFit.cover,
        placeholder: (_, _) => const Icon(Icons.person),
        errorWidget: (_, _, _) => const Icon(Icons.person),
      ),
    );
  }
}
