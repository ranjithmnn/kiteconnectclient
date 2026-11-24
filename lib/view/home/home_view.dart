import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:kiteconnectclient/view/home/bloc/home_bloc.dart';
import 'package:kiteconnectclient/view/profile/profile_view.dart';
import 'package:material_ui/material_ui.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeBloc()..add(const HomeProfileRequested()),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _customHomeAppBar(context),
                Expanded(
                  child: BlocBuilder<HomeBloc, HomeState>(
                    builder: (context, state) {
                      return switch (state) {
                        HomeInitial() || HomeLoading() => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        HomeLoaded(:final profile) => Center(
                          child: Text('Welcome, ${profile.userName}'),
                        ),
                        HomeError(:final message) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(message, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () => context.read<HomeBloc>().add(
                                  const HomeProfileRequested(),
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      };
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _customHomeAppBar(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      SvgPicture.asset('assets/logo/kite.svg', height: 20),
      IconButton(
        onPressed: () => _handleProfileClick(context),
        icon: const Icon(Icons.person),
      ),
    ],
  );

  void _handleProfileClick(BuildContext context) {
    showModalBottomSheet(context: context, builder: (context) => ProfileView());
  }
}
