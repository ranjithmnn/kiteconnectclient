import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewBottomSheet extends StatefulWidget {
  final String url;
  final ValueChanged<String>? onUrlChange;
  final bool Function(String url)? shouldClose;

  const WebViewBottomSheet({
    super.key,
    required this.url,
    this.onUrlChange,
    this.shouldClose,
  });

  static Future<String?> show(
    BuildContext context, {
    required String url,
    ValueChanged<String>? onUrlChange,
    bool Function(String url)? shouldClose,
  }) {
    final colorScheme = ColorScheme.of(context);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => WebViewBottomSheet(
        url: url,
        onUrlChange: onUrlChange,
        shouldClose: shouldClose,
      ),
    );
  }

  @override
  State<WebViewBottomSheet> createState() => _WebViewBottomSheetState();
}

class _WebViewBottomSheetState extends State<WebViewBottomSheet> {
  late final WebViewController _controller;
  late String _currentUrl = widget.url;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (change) {
            final url = change.url;
            if (url != null && url != _currentUrl) {
              _currentUrl = url;
              widget.onUrlChange?.call(url);
            }
          },
          onNavigationRequest: (request) {
            if (widget.shouldClose?.call(request.url) ?? false) {
              Navigator.of(context).pop(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(
                Icons.close,
                color: ColorScheme.of(context).onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(context).pop(_currentUrl),
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
