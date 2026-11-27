import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiteconnectclient/model/user_profile.dart';
import 'package:kiteconnectclient/utils/widgets/primary_button.dart';
import 'package:kiteconnectclient/view/home/bloc/home_bloc.dart';
import 'package:material_ui/material_ui.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                            onPressed: () => context.read<HomeBloc>().add(
                              const HomeProfileRequested(),
                            ),
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
            ],
          ),
        ),
      ),
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

    return ClipOval(
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

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;

  const _InfoColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.isEmpty ? '-' : value,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  final String label;
  final List<String> items;

  const _TagSection({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items
              .map(
                (item) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Text(
                    item,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}