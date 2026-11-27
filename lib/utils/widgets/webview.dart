import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewLoadException implements Exception {
  final String message;

  const WebViewLoadException(this.message);

  @override
  String toString() => message;
}

sealed class _PreloadResult {
  const _PreloadResult();
}

final class _PreloadReady extends _PreloadResult {
  const _PreloadReady();
}

final class _PreloadRedirected extends _PreloadResult {
  final String url;

  const _PreloadRedirected(this.url);
}

final class _PreloadFailed extends _PreloadResult {
  final String message;

  const _PreloadFailed(this.message);
}

class WebViewBottomSheet extends StatefulWidget {
  final WebViewController controller;
  final String Function() currentUrlGetter;
  final ValueChanged<ValueChanged<String?>?> registerCloser;

  const WebViewBottomSheet._({
    required this.controller,
    required this.currentUrlGetter,
    required this.registerCloser,
  });

  /// Preloads [url] in a headless [WebViewController] first, throwing a
  /// [WebViewLoadException] if loading fails, and opens the modal bottom sheet
  /// only after the page is ready.
  static Future<String?> show(
    BuildContext context, {
    required String url,
    ValueChanged<String>? onUrlChange,
    bool Function(String url)? shouldClose,
    Duration preloadTimeout = const Duration(seconds: 20),
  }) async {
    final initialUri = Uri.tryParse(url);
    if (initialUri == null || !initialUri.hasScheme) {
      throw const WebViewLoadException('Invalid login URL.');
    }

    final backgroundColor = ColorScheme.of(context).surfaceContainerLow;
    final preloadCompleter = Completer<_PreloadResult>();
    var currentUrl = url;
    int? mainFrameHttpError;
    ValueChanged<String?>? closeSheet;

    late final WebViewController controller;
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(backgroundColor)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (change) {
            final changedUrl = change.url;
            if (changedUrl != null && changedUrl != currentUrl) {
              currentUrl = changedUrl;
              onUrlChange?.call(changedUrl);
              if (shouldClose?.call(changedUrl) ?? false) {
                if (!preloadCompleter.isCompleted) {
                  preloadCompleter.complete(_PreloadRedirected(changedUrl));
                } else {
                  closeSheet?.call(changedUrl);
                }
              }
            }
          },
          onNavigationRequest: (request) {
            if (shouldClose?.call(request.url) ?? false) {
              if (!preloadCompleter.isCompleted) {
                preloadCompleter.complete(_PreloadRedirected(request.url));
              } else {
                closeSheet?.call(request.url);
              }
              return NavigationDecision.prevent;
            }
            if (!preloadCompleter.isCompleted && request.isMainFrame) {
              mainFrameHttpError = null;
            }
            return NavigationDecision.navigate;
          },
          onHttpError: (error) {
            if (preloadCompleter.isCompleted) return;
            final statusCode = error.response?.statusCode;
            final path = error.request?.uri.path.toLowerCase() ?? '';
            if (statusCode != null && statusCode >= 400) {
              final isSubresourceAsset =
                  path.endsWith('.ico') ||
                  path.endsWith('.png') ||
                  path.endsWith('.svg') ||
                  path.endsWith('.jpg') ||
                  path.endsWith('.woff') ||
                  path.endsWith('.woff2');
              if (!isSubresourceAsset) {
                mainFrameHttpError = statusCode;
              }
            }
          },
          onWebResourceError: (error) {
            final isMainFrame = error.isForMainFrame ?? true;
            if (!isMainFrame) return;

            // Ignore cancelled navigations (-999 NSURLErrorCancelled on iOS /
            // -2 ERROR_CANCELLED on Android) triggered during redirects.
            if (error.errorCode == -999) return;

            final failingUrl = error.url;
            if (failingUrl != null && (shouldClose?.call(failingUrl) ?? false)) {
              if (!preloadCompleter.isCompleted) {
                preloadCompleter.complete(_PreloadRedirected(failingUrl));
              } else {
                closeSheet?.call(failingUrl);
              }
              return;
            }

            if (!preloadCompleter.isCompleted) {
              preloadCompleter.complete(
                _PreloadFailed(_formatWebResourceError(error)),
              );
            }
          },
          onPageFinished: (finishedUrl) async {
            currentUrl = finishedUrl;
            if (preloadCompleter.isCompleted) return;

            if (shouldClose?.call(finishedUrl) ?? false) {
              preloadCompleter.complete(_PreloadRedirected(finishedUrl));
              return;
            }

            final apiErrorMessage = await _extractJsonErrorMessage(controller);
            if (preloadCompleter.isCompleted) return;

            if (apiErrorMessage != null) {
              preloadCompleter.complete(_PreloadFailed(apiErrorMessage));
              return;
            }

            if (mainFrameHttpError != null) {
              preloadCompleter.complete(
                _PreloadFailed(
                  'Unable to load login page (HTTP $mainFrameHttpError).',
                ),
              );
              return;
            }

            preloadCompleter.complete(const _PreloadReady());
          },
        ),
      );

    await controller.loadRequest(initialUri);

    final preloadOutcome = await preloadCompleter.future.timeout(
      preloadTimeout,
      onTimeout: () => const _PreloadFailed(
        'Connection timed out while loading login page. Please try again.',
      ),
    );

    switch (preloadOutcome) {
      case _PreloadFailed(:final message):
        throw WebViewLoadException(message);
      case _PreloadRedirected(:final url):
        return url;
      case _PreloadReady():
        if (!context.mounted) return null;
        return showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          enableDrag: false,
          backgroundColor: backgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) => WebViewBottomSheet._(
            controller: controller,
            currentUrlGetter: () => currentUrl,
            registerCloser: (closer) => closeSheet = closer,
          ),
        );
    }
  }

  static Future<String?> _extractJsonErrorMessage(
    WebViewController controller,
  ) async {
    try {
      final raw = await controller.runJavaScriptReturningResult(
        'document.body ? document.body.innerText : ""',
      );
      var text = raw.toString().trim();
      if (text.startsWith('"') && text.endsWith('"')) {
        final unwrapped = jsonDecode(text);
        if (unwrapped is String) {
          text = unwrapped.trim();
        }
      }
      if (!text.startsWith('{') || !text.endsWith('}')) {
        return null;
      }
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic> && decoded['status'] == 'error') {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
        return 'Unable to load Zerodha login page.';
      }
    } catch (_) {
      // Ignore JS/JSON parsing errors on standard HTML pages.
    }
    return null;
  }

  static String _formatWebResourceError(WebResourceError error) {
    return switch (error.errorType) {
      WebResourceErrorType.hostLookup ||
      WebResourceErrorType.connect =>
        'No internet connection. Please check your network.',
      WebResourceErrorType.timeout =>
        'Connection timed out. Please try again.',
      WebResourceErrorType.failedSslHandshake =>
        'Secure connection failed. Please try again.',
      _ =>
        error.description.trim().isNotEmpty
            ? error.description.trim()
            : 'Unable to load Zerodha login page.',
    };
  }

  @override
  State<WebViewBottomSheet> createState() => _WebViewBottomSheetState();
}

class _WebViewBottomSheetState extends State<WebViewBottomSheet> {
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    widget.registerCloser(_closeSheet);
  }

  @override
  void dispose() {
    widget.registerCloser(null);
    super.dispose();
  }

  void _closeSheet(String? result) {
    if (!mounted || _isClosing) return;
    _isClosing = true;
    Navigator.of(context).pop(result);
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
              onPressed: () => _closeSheet(widget.currentUrlGetter()),
            ),
          ),
          Expanded(child: WebViewWidget(controller: widget.controller)),
        ],
      ),
    );
  }
}
