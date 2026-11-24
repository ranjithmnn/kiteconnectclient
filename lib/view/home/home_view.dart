import 'package:flutter_svg/svg.dart';
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
            children: [
              _customHomeAppBar(context)
            ],
          ),
        ),
      ),
    );
  }

  Widget _customHomeAppBar(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      SvgPicture.asset('assets/logo/kite.svg', height: 20),
      IconButton(onPressed: () => _handleProfileClick(context), icon: Icon(Icons.person)),
    ],
  );

  void _handleProfileClick(BuildContext context) {
    showModalBottomSheet(context: context, builder: (context) => ProfileView());
  }
}
