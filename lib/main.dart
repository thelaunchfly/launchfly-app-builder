import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Settings baked into the app at build time (assets/app_config.json).
class AppConfig {
  AppConfig(Map<String, dynamic> j)
      : name = j['name'] as String? ?? 'App',
        url = j['url'] as String,
        primary = _color(j['primary_color'] as String? ?? '#6d28d9'),
        showProgress = j['show_progress'] as bool? ?? true,
        openExternal = j['open_external_in_browser'] as bool? ?? true,
        userAgentSuffix = j['user_agent_suffix'] as String? ?? 'LaunchFlyApp';

  final String name;
  final String url;
  final Color primary;
  final bool showProgress;
  final bool openExternal;
  final String userAgentSuffix;

  static Color _color(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final raw = await rootBundle.loadString('assets/app_config.json');
  runApp(LaunchFlyApp(config: AppConfig(jsonDecode(raw) as Map<String, dynamic>)));
}

class LaunchFlyApp extends StatelessWidget {
  const LaunchFlyApp({super.key, required this.config});
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: config.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: config.primary, useMaterial3: true),
      home: WebShell(config: config),
    );
  }
}

class WebShell extends StatefulWidget {
  const WebShell({super.key, required this.config});
  final AppConfig config;

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  late final WebViewController _web;
  late final String _homeHost;
  int _progress = 0;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _homeHost = Uri.parse(widget.config.url).host;
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageStarted: (_) => setState(() => _offline = false),
        onWebResourceError: (err) {
          if (err.isForMainFrame ?? true) setState(() => _offline = true);
        },
        onNavigationRequest: _onNavigate,
      ));
    _setup();
  }

  Future<void> _setup() async {
    final ua = await _web.getUserAgent();
    await _web.setUserAgent('${ua ?? ''} ${widget.config.userAgentSuffix}'.trim());
    final platform = _web.platform;
    if (platform is AndroidWebViewController) {
      // Let websites use <input type="file"> for photo uploads.
      await platform.setOnShowFileSelector((params) async {
        final images = params.acceptTypes.any((t) => t.startsWith('image/'));
        final res = await FilePicker.platform.pickFiles(
          type: images ? FileType.image : FileType.any,
          allowMultiple: params.mode == FileSelectorMode.openMultiple,
        );
        return res?.files.where((f) => f.path != null).map((f) => Uri.file(f.path!).toString()).toList() ?? <String>[];
      });
    }
    await _web.loadRequest(Uri.parse(widget.config.url));
  }

  /// Keep the customer's own site inside the app; open everything else outside.
  NavigationDecision _onNavigate(NavigationRequest req) {
    final uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    final isWeb = uri.scheme == 'http' || uri.scheme == 'https';
    final sameSite = uri.host == _homeHost || uri.host.endsWith('.$_homeHost');
    // Payment pages (Stripe/PayPal) must stay in-app so the return URL comes back here.
    const inApp = ['checkout.stripe.com', 'www.paypal.com', 'www.sandbox.paypal.com'];
    if (!isWeb || (widget.config.openExternal && !sameSite && !inApp.contains(uri.host))) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _onBack(bool didPop, Object? _) async {
    if (didPop) return;
    if (await _web.canGoBack()) {
      await _web.goBack();
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(children: [
            WebViewWidget(controller: _web),
            if (c.showProgress && _progress < 100)
              LinearProgressIndicator(value: _progress / 100, color: c.primary, backgroundColor: Colors.transparent, minHeight: 3),
            if (_offline) _OfflineView(color: c.primary, onRetry: () => _web.reload()),
          ]),
        ),
      ),
    );
  }
}

class _OfflineView extends StatelessWidget {
  const _OfflineView({required this.color, required this.onRetry});
  final Color color;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, size: 64, color: color),
        const SizedBox(height: 16),
        const Text('No internet connection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Check your connection and try again.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: color), onPressed: onRetry, child: const Text('Try again')),
      ]),
    );
  }
}
