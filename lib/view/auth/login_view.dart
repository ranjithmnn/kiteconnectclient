import 'package:kiteconnectclient/utils/widgets/expressive_snack/expressive_snack.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiteconnectclient/utils/widgets/primary_button.dart';
import 'package:kiteconnectclient/view/auth/bloc/auth_bloc.dart';
import 'package:kiteconnectclient/view/home/bloc/home_bloc.dart';
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
            showExpressiveSnack(
              context: context,
              message: state.message,
              type: ExpressiveSnackType.error,
              icon: Icons.error,
            );
          } else if (state is AuthSuccess) {
            context.read<HomeBloc>().add(const HomeProfileRequested());
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeView()),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return PrimaryButton(
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
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset('assets/logo/kite.svg', height: 42),
        const SizedBox(height: 28),
        Text(
          "Sign in to Kite",
          style: textTheme.headlineMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Access your Zerodha portfolio, live market feeds, and instant order execution.",
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);
    final muted = colorScheme.outline;

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
              style: textTheme.labelSmall?.copyWith(color: muted),
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
