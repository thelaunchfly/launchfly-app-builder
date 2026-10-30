import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

Color hexColor(String? hex, Color fallback) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return fallback;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

const _icons = <String, IconData>{
  'home': Icons.home_rounded, 'store': Icons.storefront_rounded, 'cart': Icons.shopping_cart_rounded,
  'tag': Icons.local_offer_rounded, 'info': Icons.info_rounded, 'phone': Icons.call_rounded, 'mail': Icons.mail_rounded,
  'person': Icons.person_rounded, 'search': Icons.search_rounded, 'heart': Icons.favorite_rounded,
  'calendar': Icons.event_rounded, 'location': Icons.place_rounded, 'menu': Icons.menu_rounded, 'star': Icons.star_rounded,
  'chat': Icons.chat_rounded, 'gallery': Icons.photo_library_rounded, 'news': Icons.article_rounded, 'settings': Icons.settings_rounded,
};

class NavItem {
  NavItem(Map<String, dynamic> j)
      : label = j['label'] as String? ?? '',
        icon = _icons[j['icon']] ?? Icons.circle,
        url = j['url'] as String? ?? '';
  final String label;
  final IconData icon;
  final String url;
}

/// Everything the app needs: bundled at build time, refreshed from the server on every launch.
class AppConfig {
  AppConfig(this.raw);
  final Map<String, dynamic> raw;

  Map<String, dynamic> get d => (raw['design'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> _m(String k) => (d[k] as Map?)?.cast<String, dynamic>() ?? {};
  List<NavItem> _items(String k) => ((_m(k)['items'] as List?) ?? []).map((e) => NavItem((e as Map).cast<String, dynamic>())).toList();

  String get name => raw['name'] as String? ?? 'App';
  String get url => raw['url'] as String;
  Color get primary => hexColor(raw['primary_color'] as String?, const Color(0xFF2563EB));
  bool get openExternal => raw['open_external_in_browser'] as bool? ?? true;
  String get uaSuffix => raw['user_agent_suffix'] as String? ?? 'LaunchFlyApp';
  String? get remote => raw['remote_config'] as String?;
  String get iconUrl => raw['icon'] as String? ?? '';

  bool get header => _m('header')['enabled'] as bool? ?? false;
  String get headerTitle => _m('header')['title'] as String? ?? name;
  Color get headerBg => hexColor(_m('header')['bg'] as String?, primary);
  Color get headerFg => hexColor(_m('header')['fg'] as String?, Colors.white);
  bool get headerCenter => _m('header')['center'] as bool? ?? false;
  bool get headerLogo => _m('header')['show_logo'] as bool? ?? false;
  bool get bottomNav => (_m('bottom_nav')['enabled'] as bool? ?? false) && bottomItems.length >= 2;
  bool get bottomIconsOnly => _m('bottom_nav')['style'] == 'icons';
  List<NavItem> get bottomItems => _items('bottom_nav');
  bool get drawer => (_m('drawer')['enabled'] as bool? ?? false) && drawerItems.isNotEmpty;
  List<NavItem> get drawerItems => _items('drawer');
  String get fabType => _m('fab')['type'] as String? ?? 'none';
  String get fabValue => _m('fab')['value'] as String? ?? '';
  Color get fabColor => hexColor(_m('fab')['color'] as String?, const Color(0xFF25D366));
  String get loader => d['loader'] as String? ?? 'bar';
  bool get refreshButton => d['pull_refresh'] as bool? ?? false;
  bool get exitConfirm => d['exit_confirm'] as bool? ?? false;
  bool get zoom => d['zoom'] as bool? ?? false;
  bool get walkthrough => (_m('walkthrough')['enabled'] as bool? ?? false) && slides.isNotEmpty;
  List<Map<String, dynamic>> get slides => ((_m('walkthrough')['slides'] as List?) ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
  String get offlineTitle => _m('offline')['title'] as String? ?? 'No internet connection';
  String get offlineText => _m('offline')['text'] as String? ?? 'Check your connection and try again.';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bundled = jsonDecode(await rootBundle.loadString('assets/app_config.json')) as Map<String, dynamic>;
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString('remote_config');
  final merged = Map<String, dynamic>.from(bundled);
  if (cached != null) {
    try {
      merged.addAll(jsonDecode(cached) as Map<String, dynamic>);
      merged['remote_config'] = bundled['remote_config'];
    } catch (_) {}
  }
  runApp(LaunchFlyApp(initial: AppConfig(merged), bundled: bundled, prefs: prefs));
}

class LaunchFlyApp extends StatefulWidget {
  const LaunchFlyApp({super.key, required this.initial, required this.bundled, required this.prefs});
  final AppConfig initial;
  final Map<String, dynamic> bundled;
  final SharedPreferences prefs;

  @override
  State<LaunchFlyApp> createState() => _LaunchFlyAppState();
}

class _LaunchFlyAppState extends State<LaunchFlyApp> {
  late AppConfig cfg = widget.initial;
  late bool showIntro = cfg.walkthrough && !(widget.prefs.getBool('intro_done') ?? false);

  @override
  void initState() {
    super.initState();
    _refreshRemote();
  }

  /// Download the latest design; apply it immediately and remember it for the next launch.
  Future<void> _refreshRemote() async {
    final url = widget.bundled['remote_config'] as String?;
    if (url == null || url.isEmpty) return;
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return;
      final remote = jsonDecode(res.body) as Map<String, dynamic>;
      await widget.prefs.setString('remote_config', res.body);
      final merged = Map<String, dynamic>.from(widget.bundled)..addAll(remote);
      if (mounted) setState(() => cfg = AppConfig(merged));
    } catch (_) {
      // Offline or server unavailable: keep the cached/bundled design.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: cfg.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: cfg.primary, useMaterial3: true),
      home: showIntro
          ? Walkthrough(cfg: cfg, onDone: () {
              widget.prefs.setBool('intro_done', true);
              setState(() => showIntro = false);
            })
          : WebShell(cfg: cfg),
    );
  }
}

class Walkthrough extends StatefulWidget {
  const Walkthrough({super.key, required this.cfg, required this.onDone});
  final AppConfig cfg;
  final VoidCallback onDone;

  @override
  State<Walkthrough> createState() => _WalkthroughState();
}

class _WalkthroughState extends State<Walkthrough> {
  final _pc = PageController();
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final slides = widget.cfg.slides;
    final last = _i == slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(alignment: Alignment.topRight, child: TextButton(onPressed: widget.onDone, child: const Text('Skip'))),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) {
                final s = slides[i];
                final img = s['image'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (img.isNotEmpty)
                      ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.network(img, height: 260, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 40)))
                    else
                      Icon(Icons.auto_awesome_rounded, size: 96, color: widget.cfg.primary),
                    const SizedBox(height: 32),
                    Text(s['title'] as String? ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Text(s['text'] as String? ?? '', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var k = 0; k < slides.length; k++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.all(4),
                width: k == _i ? 22 : 8, height: 8,
                decoration: BoxDecoration(color: k == _i ? widget.cfg.primary : Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity, height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: widget.cfg.primary),
                onPressed: () => last ? widget.onDone() : _pc.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut),
                child: Text(last ? 'Get started' : 'Next'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class WebShell extends StatefulWidget {
  const WebShell({super.key, required this.cfg});
  final AppConfig cfg;

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  late final WebViewController _web;
  late final String _homeHost;
  int _progress = 0;
  bool _offline = false;
  int _tab = 0;

  AppConfig get c => widget.cfg;

  @override
  void initState() {
    super.initState();
    _homeHost = Uri.parse(c.url).host;
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
    await _web.setUserAgent('${ua ?? ''} ${c.uaSuffix}'.trim());
    final platform = _web.platform;
    if (platform is AndroidWebViewController) {
      await platform.setOnShowFileSelector((params) async {
        final images = params.acceptTypes.any((t) => t.startsWith('image/'));
        final res = await FilePicker.platform.pickFiles(
          type: images ? FileType.image : FileType.any,
          allowMultiple: params.mode == FileSelectorMode.openMultiple,
        );
        return res?.files.where((f) => f.path != null).map((f) => Uri.file(f.path!).toString()).toList() ?? <String>[];
      });
    }
    await _web.enableZoom(c.zoom);
    final start = c.bottomNav ? c.bottomItems.first.url : c.url;
    await _web.loadRequest(Uri.parse(start));
  }

  NavigationDecision _onNavigate(NavigationRequest req) {
    final uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    final isWeb = uri.scheme == 'http' || uri.scheme == 'https';
    final sameSite = uri.host == _homeHost || uri.host.endsWith('.$_homeHost');
    const inApp = ['checkout.stripe.com', 'www.paypal.com', 'www.sandbox.paypal.com'];
    if (!isWeb || (c.openExternal && !sameSite && !inApp.contains(uri.host))) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      await _web.loadRequest(uri);
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _fab() {
    final v = c.fabValue.trim();
    switch (c.fabType) {
      case 'whatsapp':
        launchUrl(Uri.parse('https://wa.me/${v.replaceAll(RegExp(r'\D'), '')}'), mode: LaunchMode.externalApplication);
      case 'call':
        launchUrl(Uri.parse('tel:${v.replaceAll(RegExp(r'[^\d+]'), '')}'));
      case 'link':
        _open(v);
    }
  }

  Future<void> _onBack(bool didPop, Object? _) async {
    if (didPop) return;
    if (await _web.canGoBack()) {
      await _web.goBack();
      return;
    }
    if (!c.exitConfirm || !mounted) {
      await SystemNavigator.pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Close ${c.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Close')),
        ],
      ),
    );
    if (leave == true) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final loading = _progress < 100;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: c.header
            ? AppBar(
                backgroundColor: c.headerBg,
                foregroundColor: c.headerFg,
                centerTitle: c.headerCenter,
                automaticallyImplyLeading: c.drawer,
                title: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (c.headerLogo && c.iconUrl.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(right: 10), child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(c.iconUrl, width: 26, height: 26, errorBuilder: (_, __, ___) => const SizedBox()))),
                  Flexible(child: Text(c.headerTitle, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                ]),
                actions: [
                  if (c.refreshButton) IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => _web.reload()),
                ],
              )
            : null,
        drawer: c.drawer
            ? Drawer(
                child: SafeArea(
                  child: ListView(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Text(c.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.primary)),
                    ),
                    for (final it in c.drawerItems)
                      ListTile(leading: Icon(it.icon, color: c.primary), title: Text(it.label), onTap: () {
                        Navigator.pop(context);
                        _open(it.url);
                      }),
                  ]),
                ),
              )
            : null,
        body: SafeArea(
          top: !c.header,
          child: Stack(children: [
            WebViewWidget(controller: _web),
            if (loading && c.loader == 'bar')
              LinearProgressIndicator(value: _progress / 100, color: c.primary, backgroundColor: Colors.transparent, minHeight: 3),
            if (loading && c.loader == 'spinner')
              Center(child: CircularProgressIndicator(color: c.primary)),
            if (_offline) _OfflineView(color: c.primary, title: c.offlineTitle, text: c.offlineText, onRetry: () => _web.reload()),
          ]),
        ),
        floatingActionButton: c.fabType == 'none'
            ? null
            : FloatingActionButton(
                backgroundColor: c.fabColor,
                foregroundColor: Colors.white,
                onPressed: _fab,
                child: Icon(c.fabType == 'call' ? Icons.call_rounded : c.fabType == 'whatsapp' ? Icons.chat_rounded : Icons.open_in_new_rounded),
              ),
        bottomNavigationBar: c.bottomNav
            ? NavigationBar(
                selectedIndex: _tab.clamp(0, c.bottomItems.length - 1),
                labelBehavior: c.bottomIconsOnly ? NavigationDestinationLabelBehavior.alwaysHide : NavigationDestinationLabelBehavior.alwaysShow,
                indicatorColor: c.primary.withOpacity(.15),
                onDestinationSelected: (i) {
                  setState(() => _tab = i);
                  _open(c.bottomItems[i].url);
                },
                destinations: [
                  for (final it in c.bottomItems)
                    NavigationDestination(icon: Icon(it.icon), selectedIcon: Icon(it.icon, color: c.primary), label: it.label),
                ],
              )
            : null,
      ),
    );
  }
}

class _OfflineView extends StatelessWidget {
  const _OfflineView({required this.color, required this.title, required this.text, required this.onRetry});
  final Color color;
  final String title;
  final String text;
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
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: color), onPressed: onRetry, child: const Text('Try again')),
      ]),
    );
  }
}
