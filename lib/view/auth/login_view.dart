import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiteconnectclient/utils/widgets/dialog.dart';
import 'package:kiteconnectclient/view/auth/bloc/auth_bloc.dart';
import 'package:kiteconnectclient/view/home/home_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              const _HeaderSection(),
              const SizedBox(height: 36),
              _loginBtn(),
              const SizedBox(height: 12),
              const Spacer(flex: 3),
              const _FooterSection(),
            ],
          ),
        ),
      ),
    );
  }

  BlocProvider<AuthBloc> _loginBtn() {
    return BlocProvider(
      create: (_) => AuthBloc(),
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            DialogUtil.showSimpleDialog(context, "Error", state.message);
          } else if (state is AuthSuccess) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeView()),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return _PrimaryButton(
            label: "Login with Zerodha",
            isLoading: isLoading,
            onPressed: isLoading
                ? null
                : () => context.read<AuthBloc>().add(
                    AuthLoginRequested(context: context),
                  ),
          );
        },
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset('assets/logo/kite.svg', height: 42),
        const SizedBox(height: 28),
        Text(
          "Sign in to Kite",
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Access your Zerodha portfolio, live market feeds, and instant order execution.",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 13, color: muted),
            const SizedBox(width: 5),
            Text(
              "Secured by Zerodha Kite Connect",
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Opacity(
          opacity: 0.7,
          child: SvgPicture.asset('assets/logo/zerodha.svg', height: 11),
        ),
      ],
    );
  }
}
