import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiteconnectclient/model/user_profile.dart';
import 'package:kiteconnectclient/utils/haptics/mico_haptics.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_dialog/expressive_dialog.dart';
import 'package:kiteconnectclient/utils/widgets/expressive_snack/expressive_snack.dart';
import 'package:kiteconnectclient/utils/widgets/primary_button.dart';
import 'package:kiteconnectclient/view/auth/bloc/auth_bloc.dart';
import 'package:kiteconnectclient/view/auth/login_view.dart';
import 'package:kiteconnectclient/view/home/bloc/home_bloc.dart';
import 'package:material_ui/material_ui.dart';

class ProfileSheet extends StatelessWidget {
  const ProfileSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);

    return BlocProvider(
      create: (_) => AuthBloc(),
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            showExpressiveSnack(
              context: context,
              message: state.message,
              type: ExpressiveSnackType.error,
              icon: Icons.error,
            );
          } else if (state is AuthLogoutSuccess) {
            context.read<HomeBloc>().add(const HomeReset());
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginView()),
              (route) => false,
            );
          }
        },
        builder: (context, state) {
          final isLoggingOut = state is AuthLoading;

          return PopScope(
            canPop: !isLoggingOut,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BlocBuilder<HomeBloc, HomeState>(
                        builder: (context, state) {
                          return switch (state) {
                            HomeInitial() || HomeLoading() => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            HomeError(:final message) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    message,
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: () => context
                                        .read<HomeBloc>()
                                        .add(const HomeProfileRequested()),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                            HomeLoaded(:final profile) => _ProfileSnapshot(
                              profile: profile,
                            ),
                          };
                        },
                      ),
                      const Spacer(),
                      PrimaryButton(
                        label: 'Logout',
                        isLoading: isLoggingOut,
                        onPressed: isLoggingOut
                            ? null
                            : () => _logoutTapHandler(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _logoutTapHandler(BuildContext context) {
    Navigator.of(context).pop();
    final authBloc = context.read<AuthBloc>();
    MicroHaptics.microTick();
    showExpressiveDialog(
      context: context,
      title: 'Logout ?',
      message: 'Are you sure you want to logout?',
      icon: Icons.warning,
      buttons: [
        ExpressiveDialogButton(label: 'Cancel', onPressed: () {}),
        ExpressiveDialogButton(
          label: 'Logout',
          role: .destructive,
          onPressed: () => authBloc.add(const AuthLogoutRequested()),
        ),
      ],
    );
  }
}

class _ProfileSnapshot extends StatelessWidget {
  final UserProfile profile;

  const _ProfileSnapshot({required this.profile});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);
    final muted = colorScheme.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LargeAvatar(avatarUrl: profile.avatarUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.userName.isNotEmpty
                        ? profile.userName
                        : profile.userShortname,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (profile.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      profile.email,
                      style: textTheme.bodySmall?.copyWith(color: muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        // PrimaryButton(label: "Logout", onPressed: (){})
      ],
    );
  }
}

class _LargeAvatar extends StatelessWidget {
  final String? avatarUrl;

  const _LargeAvatar({required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final url = avatarUrl;

    Widget fallback() => CircleAvatar(
      radius: 26,
      backgroundColor: colorScheme.primaryContainer,
      child: Icon(
        Icons.person,
        size: 26,
        color: colorScheme.onPrimaryContainer,
      ),
    );

    if (url == null || url.isEmpty) {
      return fallback();
    }

    return ClipPath(
      clipper: ShapeBorderClipper(
        shape: MaterialShapeBorder(shape: MaterialShapes.cookie9Sided),
      ),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback(),
        errorWidget: (_, _, _) => fallback(),
      ),
    );
  }
}
