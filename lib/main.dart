import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:workmanager/workmanager.dart';

Color hexColor(dynamic hex, Color fallback) {
  if (hex is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return fallback;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

const _icons = <String, IconData>{
  'home': Icons.home_rounded, 'store': Icons.storefront_rounded, 'cart': Icons.shopping_cart_rounded, 'tag': Icons.local_offer_rounded,
  'info': Icons.info_rounded, 'phone': Icons.call_rounded, 'mail': Icons.mail_rounded, 'person': Icons.person_rounded,
  'search': Icons.search_rounded, 'heart': Icons.favorite_rounded, 'calendar': Icons.event_rounded, 'location': Icons.place_rounded,
  'menu': Icons.menu_rounded, 'star': Icons.star_rounded, 'chat': Icons.chat_rounded, 'gallery': Icons.photo_library_rounded,
  'news': Icons.article_rounded, 'settings': Icons.settings_rounded, 'share': Icons.share_rounded, 'video': Icons.play_circle_rounded,
  'music': Icons.music_note_rounded, 'school': Icons.school_rounded, 'work': Icons.work_rounded, 'help': Icons.help_rounded,
  'bell': Icons.notifications_rounded, 'globe': Icons.public_rounded, 'lock': Icons.lock_rounded, 'gift': Icons.card_giftcard_rounded,
  'reload': Icons.refresh_rounded,
};
IconData iconOf(dynamic n) => _icons[n] ?? Icons.circle_outlined;

class NavItem {
  NavItem(Map j)
      : label = '${j['label'] ?? j['title'] ?? ''}',
        icon = iconOf(j['icon']),
        url = '${j['url'] ?? ''}',
        children = ((j['children'] as List?) ?? []).map((e) => NavItem(e as Map)).toList();
  final String label;
  final IconData icon;
  final String url;
  final List<NavItem> children;
}

/// Bundled at build time, refreshed from The LaunchFly on every launch.
class Cfg {
  Cfg(this.raw);
  final Map<String, dynamic> raw;
  Map get d => (raw['design'] as Map?) ?? {};
  Map m(String k) => (d[k] as Map?) ?? {};
  dynamic v(String k, String f, [dynamic def]) => m(k)[f] ?? def;
  List<NavItem> items(String k, [String f = 'items']) => ((m(k)[f] as List?) ?? []).map((e) => NavItem(e as Map)).toList();

  String get name => '${raw['name'] ?? 'App'}';
  String get url => '${raw['url']}';
  Color get primary => hexColor(raw['primary_color'], const Color(0xFF2563EB));
  String get iconUrl => '${raw['icon'] ?? ''}';
  String get nav => '${v('nav', 'style', 'none')}';
  bool get hasDrawer => nav == 'drawer' || nav == 'drawer_bottom';
  bool get hasBottom => (nav == 'bottom' || nav == 'drawer_bottom') && items('bottom_nav').length >= 2;
  bool get hasTabs => nav == 'tabs' && items('tabs').length >= 2;
  List<NavItem> get pages => ((d['pages'] as List?) ?? []).map((e) => NavItem(e as Map)).toList();
  Color get pageBg => hexColor(v('style', 'page_bg'), Colors.white);

  SystemUiOverlayStyle get overlay {
    final st = m('style');
    final darkIcons = st['status_icons'] == 'dark';
    final nav = hexColor(st['navbar_bg'], Colors.white);
    return SystemUiOverlayStyle(
      statusBarColor: hexColor(st['status_bg'], primary),
      statusBarIconBrightness: darkIcons ? Brightness.dark : Brightness.light,
      statusBarBrightness: darkIcons ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: nav,
      systemNavigationBarIconBrightness: nav.computeLuminance() > .5 ? Brightness.dark : Brightness.light,
    );
  }
}

/// Orientation, full screen and status bar colours from the dashboard.
void applySystemUi(Cfg cfg) {
  final app = cfg.m('app');
  final o = '${app['orientation'] ?? 'auto'}';
  SystemChrome.setPreferredOrientations(o == 'portrait'
      ? [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
      : o == 'landscape'
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : []);
  SystemChrome.setEnabledSystemUIMode(app['fullscreen'] == true ? SystemUiMode.immersiveSticky : SystemUiMode.manual, overlays: SystemUiOverlay.values);
  SystemChrome.setSystemUIOverlayStyle(cfg.overlay);
}

/* ---------- Built-in notifications (LaunchFly inbox, checked in the background) ---------- */

final _notes = FlutterLocalNotificationsPlugin();
/// A tapped notification's link, opened by the Shell.
final pendingUrl = ValueNotifier<String?>(null);
const _inboxTask = 'lf-inbox';

Future<void> _initNotes() async {
  await _notes.initialize(
    const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    onDidReceiveNotificationResponse: (r) {
      if ((r.payload ?? '').isNotEmpty) pendingUrl.value = r.payload;
    },
  );
}

String _notifyUrl(Map bundled) => '${bundled['remote_config'] ?? ''}'.replaceFirst('/api/app-config/', '/api/app-notify/');

/// Downloads new notifications, shows them and keeps the last 30 for the inbox. Returns how many were new.
Future<int> checkInbox(Map bundled, {bool show = true}) async {
  final url = _notifyUrl(bundled);
  if (!url.contains('/api/app-notify/')) return 0;
  final prefs = await SharedPreferences.getInstance();
  final last = prefs.getInt('note_last');
  try {
    final res = await http.get(Uri.parse('$url?after=${last ?? 0}')).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return 0;
    final j = jsonDecode(res.body) as Map;
    final items = ((j['items'] as List?) ?? []).cast<Map>();
    final inbox = ((jsonDecode(prefs.getString('note_inbox') ?? '[]') as List).cast<Map>()).toList();
    final known = inbox.map((e) => e['id']).toSet();
    var fresh = 0;
    for (final it in items.reversed) {
      if (known.contains(it['id'])) continue;
      inbox.insert(0, it);
      fresh++;
      // The very first check only fills the inbox; it doesn't pop up old messages.
      if (show && last != null) {
        await _notes.show(
          (it['id'] as num).toInt(),
          '${it['title']}',
          '${it['body']}',
          const NotificationDetails(android: AndroidNotificationDetails('lf_news', 'News & offers', importance: Importance.high, priority: Priority.high, styleInformation: BigTextStyleInformation(''))),
          payload: '${it['url'] ?? ''}',
        );
      }
    }
    await prefs.setString('note_inbox', jsonEncode(inbox.take(30).toList()));
    await prefs.setInt('note_last', (j['latest'] as num?)?.toInt() ?? last ?? 0);
    if (fresh > 0) await prefs.setInt('note_unread', (prefs.getInt('note_unread') ?? 0) + (last == null ? 0 : fresh));
    return fresh;
  } catch (_) {
    return 0;
  }
}

@pragma('vm:entry-point')
void backgroundTask() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final bundled = jsonDecode(await rootBundle.loadString('assets/app_config.json')) as Map;
      await _initNotes();
      await checkInbox(bundled);
    } catch (_) {}
    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bundled = jsonDecode(await rootBundle.loadString('assets/app_config.json')) as Map<String, dynamic>;
  final prefs = await SharedPreferences.getInstance();
  final merged = Map<String, dynamic>.from(bundled);
  final cached = prefs.getString('remote_config');
  if (cached != null) {
    try {
      merged.addAll(jsonDecode(cached) as Map<String, dynamic>);
    } catch (_) {}
  }
  final cfg = Cfg(merged);
  applySystemUi(cfg);
  if (cfg.v('ads', 'enabled', false) == true) {
    unawaited(MobileAds.instance.initialize());
  }
  final osId = '${cfg.v('push', 'onesignal_app_id', '')}';
  if (cfg.v('push', 'enabled', false) == true && osId.isNotEmpty) {
    OneSignal.initialize(osId);
    unawaited(OneSignal.Notifications.requestPermission(true));
  }
  if (cfg.v('notify', 'enabled', true) != false) {
    await _initNotes();
    final launch = await _notes.getNotificationAppLaunchDetails();
    final p = launch?.notificationResponse?.payload ?? '';
    if ((launch?.didNotificationLaunchApp ?? false) && p.isNotEmpty) pendingUrl.value = p;
    try {
      await Workmanager().initialize(backgroundTask);
      await Workmanager().registerPeriodicTask(_inboxTask, _inboxTask,
          frequency: const Duration(minutes: 15), constraints: Constraints(networkType: NetworkType.connected), existingWorkPolicy: ExistingWorkPolicy.keep);
    } catch (_) {}
    unawaited(Permission.notification.request());
    unawaited(checkInbox(bundled));
  }
  runApp(LaunchFlyApp(initial: cfg, bundled: bundled, prefs: prefs));
}

class LaunchFlyApp extends StatefulWidget {
  const LaunchFlyApp({super.key, required this.initial, required this.bundled, required this.prefs});
  final Cfg initial;
  final Map<String, dynamic> bundled;
  final SharedPreferences prefs;
  @override
  State<LaunchFlyApp> createState() => _LaunchFlyAppState();
}

class _LaunchFlyAppState extends State<LaunchFlyApp> with WidgetsBindingObserver {
  late Cfg cfg = widget.initial;
  bool splash = true;
  late bool intro = cfg.v('walkthrough', 'enabled', false) == true && !(widget.prefs.getBool('intro_done') ?? false);
  final shellKey = GlobalKey<_ShellState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    final secs = (cfg.v('splash', 'seconds', 2) as num?)?.toInt() ?? 2;
    Timer(Duration(milliseconds: secs.clamp(1, 6) * 1000 - 200), () => mounted ? setState(() => splash = false) : null);
    if (cfg.v('push', 'enabled', false) == true && '${cfg.v('push', 'onesignal_app_id', '')}'.isNotEmpty) {
      OneSignal.Notifications.addClickListener((e) {
        final url = e.notification.additionalData?['url'];
        if (url is String && url.isNotEmpty) shellKey.currentState?.open(url);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Design changes from the dashboard also apply when the app returns from the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      if (cfg.v('notify', 'enabled', true) != false) checkInbox(widget.bundled).then((n) => n > 0 ? shellKey.currentState?.inboxChanged() : null);
    }
  }

  Future<void> _refresh() async {
    final url = widget.bundled['remote_config'] as String?;
    if (url == null || url.isEmpty) return;
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return;
      await widget.prefs.setString('remote_config', res.body);
      final merged = Map<String, dynamic>.from(widget.bundled)..addAll(jsonDecode(res.body) as Map<String, dynamic>);
      if (mounted) {
        setState(() => cfg = Cfg(merged));
        applySystemUi(cfg);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (cfg.raw['locked'] == true) {
      home = LockView(cfg: cfg);
    } else if (splash) {
      home = SplashView(cfg: cfg);
    } else if (intro) {
      home = Walkthrough(cfg: cfg, onDone: () {
        widget.prefs.setBool('intro_done', true);
        setState(() => intro = false);
      });
    } else {
      home = Shell(key: shellKey, cfg: cfg);
    }
    return MaterialApp(
      title: cfg.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: cfg.primary, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: cfg.primary, useMaterial3: true, brightness: Brightness.dark),
      themeMode: {'dark': ThemeMode.dark, 'system': ThemeMode.system}['${cfg.v('style', 'theme', 'light')}'] ?? ThemeMode.light,
      home: AnimatedSwitcher(duration: const Duration(milliseconds: 400), child: home),
    );
  }
}

class SplashView extends StatelessWidget {
  const SplashView({super.key, required this.cfg});
  final Cfg cfg;
  @override
  Widget build(BuildContext context) {
    final s = cfg.m('splash');
    final c1 = hexColor(s['bg'], Colors.white);
    final c2 = s['bg2'] is String && '${s['bg2']}'.isNotEmpty ? hexColor(s['bg2'], c1) : c1;
    final img = '${s['image'] ?? ''}';
    final tc = hexColor(s['title_color'], const Color(0xFF0F172A));
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          image: img.isNotEmpty ? DecorationImage(image: NetworkImage(img), fit: BoxFit.cover) : null,
        ),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (s['show_logo'] != false && cfg.iconUrl.isNotEmpty)
            ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.network(cfg.iconUrl, width: 96, height: 96, errorBuilder: (_, __, ___) => const SizedBox())),
          if (s['show_title'] != false) ...[
            const SizedBox(height: 18),
            Text('${s['title'] ?? cfg.name}', style: TextStyle(color: tc, fontSize: 24, fontWeight: FontWeight.w800)),
          ],
          if ('${s['tagline'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('${s['tagline']}', style: TextStyle(color: tc.withOpacity(.75))),
          ],
        ]),
      ),
    );
  }
}

class Walkthrough extends StatefulWidget {
  const Walkthrough({super.key, required this.cfg, required this.onDone});
  final Cfg cfg;
  final VoidCallback onDone;
  @override
  State<Walkthrough> createState() => _WalkthroughState();
}

class _WalkthroughState extends State<Walkthrough> {
  final _pc = PageController();
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final slides = ((widget.cfg.m('walkthrough')['slides'] as List?) ?? []).cast<Map>();
    final style = '${widget.cfg.v('walkthrough', 'style', '1')}';
    final last = _i >= slides.length - 1;
    final p = widget.cfg.primary;
    return Scaffold(
      body: Stack(children: [
        PageView.builder(
          controller: _pc,
          itemCount: slides.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (_, i) {
            final s = slides[i];
            final img = '${s['image'] ?? ''}';
            final text = Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${s['title'] ?? ''}', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: style == '2' ? Colors.white : null)),
              const SizedBox(height: 12),
              Text('${s['text'] ?? ''}', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: style == '2' ? Colors.white70 : Colors.grey.shade700)),
            ]);
            if (style == '2' && img.isNotEmpty) {
              return Container(
                decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(img), fit: BoxFit.cover, colorFilter: const ColorFilter.mode(Colors.black45, BlendMode.darken))),
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 160),
                alignment: Alignment.bottomCenter,
                child: text,
              );
            }
            final media = img.isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.network(img, height: 260, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 40)))
                : Icon(Icons.auto_awesome_rounded, size: 96, color: p);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 40, 28, 160),
                child: style == '3'
                    ? Center(child: Card(elevation: 6, child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [media, const SizedBox(height: 24), text]))))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [media, const SizedBox(height: 32), text]),
              ),
            );
          },
        ),
        Positioned(
          left: 24, right: 24, bottom: 32,
          child: SafeArea(
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var k = 0; k < slides.length; k++)
                  AnimatedContainer(duration: const Duration(milliseconds: 250), margin: const EdgeInsets.all(4), width: k == _i ? 22 : 8, height: 8,
                      decoration: BoxDecoration(color: k == _i ? p : Colors.grey.shade300, borderRadius: BorderRadius.circular(8))),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                TextButton(onPressed: widget.onDone, child: const Text('Skip')),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: p, minimumSize: const Size(140, 50)),
                  onPressed: () => last ? widget.onDone() : _pc.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut),
                  child: Text(last ? 'Get started' : 'Next'),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.cfg});
  final Cfg cfg;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with TickerProviderStateMixin {
  late final WebViewController _web;
  late final String _host;
  int _progress = 0, _tab = 0, _navCount = 0;
  bool _offline = false;
  BannerAd? _banner;
  InterstitialAd? _inter;
  TabController? _tabs;

  Cfg get c => widget.cfg;

  @override
  void initState() {
    super.initState();
    _host = Uri.parse(c.url).host;
    _makeTabs();
    pendingUrl.addListener(_openPending);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
    _loadUnread();
    _web = WebViewController()
      ..setBackgroundColor(c.pageBg)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageStarted: (_) => setState(() => _offline = false),
        onPageFinished: (_) => _inject(),
        onWebResourceError: (err) {
          if (err.isForMainFrame ?? true) setState(() => _offline = true);
        },
        onNavigationRequest: _onNavigate,
      ));
    _setup();
    _loadAds();
    WidgetsBinding.instance.addPostFrameCallback((_) => _engage());
  }

  int _unread = 0;

  Future<void> _loadUnread() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _unread = prefs.getInt('note_unread') ?? 0);
  }

  void inboxChanged() => _loadUnread();

  void _openPending() {
    final u = pendingUrl.value;
    if (u != null && u.isNotEmpty) {
      pendingUrl.value = null;
      open(u);
    }
  }

  void _makeTabs() {
    _tabs?.dispose();
    _tabs = null;
    if (c.hasTabs) {
      _tabs = TabController(length: c.items('tabs').length, vsync: this)..addListener(() {
          if (!_tabs!.indexIsChanging) open(c.items('tabs')[_tabs!.index].url);
        });
    }
  }

  @override
  void didUpdateWidget(covariant Shell old) {
    super.didUpdateWidget(old);
    if (old.cfg.hasTabs != c.hasTabs || old.cfg.items('tabs').length != c.items('tabs').length) _makeTabs();
    if (_tab >= c.items('bottom_nav').length) _tab = 0;
  }

  Future<void> _openInbox() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('note_unread', 0);
    setState(() => _unread = 0);
    if (!mounted) return;
    final url = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => InboxView(cfg: c)));
    if (url != null && url.isNotEmpty) open(url);
  }

  /// Launch-time popups from the dashboard: one-off announcement, then the rate-the-app prompt.
  Future<void> _engage() async {
    final e = c.m('engage');
    if (e['maintenance'] == true) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final id = '${e['announce_id'] ?? '1'}';
    if (e['announce'] == true && '${e['announce_title'] ?? ''}${e['announce_text'] ?? ''}'.isNotEmpty && prefs.getString('announce_seen') != id) {
      await prefs.setString('announce_seen', id);
      final img = '${e['announce_image'] ?? ''}';
      final link = '${e['announce_url'] ?? ''}';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: img.isNotEmpty ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(img, height: 140, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())) : null,
          title: Text('${e['announce_title'] ?? ''}'),
          content: Text('${e['announce_text'] ?? ''}'),
          actions: [
            if (link.isNotEmpty) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(onPressed: () { Navigator.pop(ctx); if (link.isNotEmpty) open(link); }, child: Text('${e['announce_button'] ?? 'OK'}')),
          ],
        ),
      );
      return;
    }
    if (e['rate'] != true || (prefs.getBool('rate_done') ?? false)) return;
    final opens = (prefs.getInt('opens') ?? 0) + 1;
    await prefs.setInt('opens', opens);
    if (opens < ((e['rate_after'] as num?)?.toInt() ?? 5) || !mounted) return;
    final pkg = '${c.raw['package_id'] ?? ''}';
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.star_rounded, size: 40, color: Colors.amber),
        title: Text('${e['rate_title'] ?? 'Enjoying the app?'}'),
        content: Text('${e['rate_text'] ?? ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'never'), child: const Text('No thanks')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'later'), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'rate'), child: const Text('Rate now')),
        ],
      ),
    );
    if (choice == 'later' || choice == null) {
      await prefs.setInt('opens', 0);
    } else {
      await prefs.setBool('rate_done', true);
      if (choice == 'rate' && pkg.isNotEmpty) {
        final ok = await launchUrl(Uri.parse('market://details?id=$pkg'), mode: LaunchMode.externalApplication).catchError((_) => false);
        if (!ok) await launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=$pkg'), mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _setup() async {
    final app = c.m('app');
    await _web.setJavaScriptMode(app['javascript'] == false ? JavaScriptMode.disabled : JavaScriptMode.unrestricted);
    final ua = await _web.getUserAgent();
    final custom = '${app['user_agent'] ?? ''}'.trim();
    await _web.setUserAgent(custom.isNotEmpty ? custom : '${ua ?? ''} LaunchFlyApp'.trim());
    await _web.enableZoom(app['zoom'] == true);
    if (app['clear_cookies'] == true) await WebViewCookieManager().clearCookies();
    if (app['clear_cache'] == true) await _web.clearCache();
    final platform = _web.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
      await platform.setTextZoom(((app['text_zoom'] as num?)?.toInt() ?? 100).clamp(70, 150));
      await platform.setOnShowFileSelector((params) async {
        final images = params.acceptTypes.any((t) => t.startsWith('image/'));
        final res = await FilePicker.platform.pickFiles(type: images ? FileType.image : FileType.any, allowMultiple: params.mode == FileSelectorMode.openMultiple);
        return res?.files.where((f) => f.path != null).map((f) => Uri.file(f.path!).toString()).toList() ?? <String>[];
      });
      await platform.setOnPlatformPermissionRequest((req) async {
        if (app['webrtc'] != true) return req.deny();
        await [Permission.camera, Permission.microphone].request();
        req.grant();
      });
    }
    final start = c.hasBottom ? c.items('bottom_nav').first.url : (c.hasTabs ? c.items('tabs').first.url : c.url);
    await _web.loadRequest(Uri.parse(start));
  }

  /// App-only CSS/JS: hidden website parts, no text selection, and the owner's custom code.
  Future<void> _inject() async {
    final h = c.m('hide_web');
    final app = c.m('app');
    final sel = [h['header'], h['footer']].where((s) => s is String && s.trim().isNotEmpty).join(',');
    var css = sel.isEmpty ? '' : '$sel{display:none!important}';
    if (app['disable_select'] == true) css += '*{-webkit-user-select:none;user-select:none;-webkit-touch-callout:none}input,textarea{-webkit-user-select:text;user-select:text}';
    css += '${app['custom_css'] ?? ''}';
    if (css.trim().isNotEmpty) {
      await _web.runJavaScript('(function(){var s=document.getElementById("lf-hide")||document.head.appendChild(Object.assign(document.createElement("style"),{id:"lf-hide"}));s.textContent=${jsonEncode(css)}})();');
    }
    final js = '${app['custom_js'] ?? ''}'.trim();
    if (js.isNotEmpty) {
      try {
        await _web.runJavaScript('try{$js}catch(e){console.error(e)}');
      } catch (_) {}
    }
  }

  bool _isInternal(String host) {
    if (host == _host || host.endsWith('.$_host')) return true;
    final extra = '${c.v('app', 'internal_domains', '')}'.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty);
    return extra.any((d) => host == d || host.endsWith('.$d'));
  }

  void _loadAds() {
    final ads = c.m('ads');
    if (ads['enabled'] != true) return;
    final bid = '${ads['banner_id'] ?? ''}';
    if (bid.isNotEmpty) {
      _banner = BannerAd(adUnitId: bid, size: AdSize.banner, request: const AdRequest(), listener: BannerAdListener(
        onAdLoaded: (_) => setState(() {}),
        onAdFailedToLoad: (ad, _) { ad.dispose(); setState(() => _banner = null); },
      ))..load();
    }
    _loadInter();
  }

  void _loadInter() {
    final iid = '${c.v('ads', 'interstitial_id', '')}';
    if (c.v('ads', 'enabled', false) != true || iid.isEmpty) return;
    InterstitialAd.load(adUnitId: iid, request: const AdRequest(), adLoadCallback: InterstitialAdLoadCallback(
      onAdLoaded: (ad) => _inter = ad,
      onAdFailedToLoad: (_) => _inter = null,
    ));
  }

  void _countNav() {
    final every = (c.v('ads', 'tap_count', 0) as num?)?.toInt() ?? 0;
    if (every <= 0 || _inter == null) return;
    if (++_navCount % every == 0) {
      _inter!.show();
      _inter = null;
      _loadInter();
    }
  }

  NavigationDecision _onNavigate(NavigationRequest req) {
    final uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    final isWeb = uri.scheme == 'http' || uri.scheme == 'https';
    final same = _isInternal(uri.host);
    const inApp = ['checkout.stripe.com', 'www.paypal.com', 'www.sandbox.paypal.com'];
    final external = c.m('app')['open_external'] != false;
    if (!isWeb || (external && !same && !inApp.contains(uri.host))) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
      return NavigationDecision.prevent;
    }
    if (req.isMainFrame) _countNav();
    return NavigationDecision.navigate;
  }

  Future<void> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || url.isEmpty) return;
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      await _web.loadRequest(uri);
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _share() => Share.share('${c.v('share', 'text', '') ?? ''}'.isNotEmpty ? '${c.v('share', 'text')}' : '${c.name} ${c.url}');

  void _action(Map ri) {
    switch ('${ri['action']}') {
      case 'reload':
        _web.reload();
      case 'share':
        _share();
      case 'home':
        open(c.url);
      case 'back':
        _web.goBack();
      case 'url':
        open('${ri['url']}');
    }
  }

  void _fab() {
    final f = c.m('fab');
    final v = '${f['value'] ?? ''}'.trim();
    switch ('${f['type']}') {
      case 'whatsapp':
        launchUrl(Uri.parse('https://wa.me/${v.replaceAll(RegExp(r'\D'), '')}'), mode: LaunchMode.externalApplication);
      case 'call':
        launchUrl(Uri.parse('tel:${v.replaceAll(RegExp(r'[^\d+]'), '')}'));
      case 'link':
        open(v);
      case 'share':
        _share();
    }
  }

  Future<void> _onBack(bool didPop, Object? _) async {
    if (didPop) return;
    if (await _web.canGoBack()) {
      await _web.goBack();
      return;
    }
    final e = c.m('exit');
    if (e['enabled'] == false || !mounted) {
      await SystemNavigator.pop();
      return;
    }
    final img = '${e['image'] ?? ''}';
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: img.isNotEmpty ? Image.network(img, height: 80, errorBuilder: (_, __, ___) => const SizedBox()) : null,
        title: Text('${e['title'] ?? 'Do you want to exit?'}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('${e['no'] ?? 'No'}')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('${e['yes'] ?? 'Yes'}')),
        ],
      ),
    );
    if (leave == true) await SystemNavigator.pop();
  }

  PreferredSizeWidget? _appBar() {
    final h = c.m('header');
    if (h['enabled'] == false) return null;
    final bg = hexColor(h['bg'], c.primary);
    final bg2 = '${h['bg2'] ?? ''}'.isNotEmpty ? hexColor(h['bg2'], bg) : bg;
    final fg = hexColor(h['fg'], Colors.white);
    final left = '${h['left_icon'] ?? 'auto'}';
    Widget? leading;
    if (left == 'back') {
      leading = IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => _web.goBack());
    } else if (left == 'home') {
      leading = IconButton(icon: const Icon(Icons.home_rounded), onPressed: () => open(c.url));
    }
    return AppBar(
      systemOverlayStyle: c.overlay,
      foregroundColor: fg,
      backgroundColor: bg,
      flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [bg, bg2]))),
      centerTitle: h['style'] == 'center',
      automaticallyImplyLeading: c.hasDrawer && (left == 'auto' || left == 'menu'),
      leading: leading,
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        if (h['show_logo'] == true && c.iconUrl.isNotEmpty)
          Padding(padding: const EdgeInsets.only(right: 10), child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(c.iconUrl, width: 26, height: 26, errorBuilder: (_, __, ___) => const SizedBox()))),
        Flexible(child: Text('${h['title'] ?? c.name}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
      actions: [
        if (c.v('notify', 'enabled', true) != false && c.v('notify', 'inbox', true) != false)
          IconButton(icon: Badge(isLabelVisible: _unread > 0, label: Text('$_unread'), child: const Icon(Icons.notifications_rounded)), onPressed: _openInbox),
        for (final ri in ((h['right_icons'] as List?) ?? []).cast<Map>()) IconButton(icon: Icon(iconOf(ri['icon'])), onPressed: () => _action(ri)),
      ],
      bottom: c.hasTabs && _tabs != null ? _tabBar(bg, fg) : null,
    );
  }

  /// Top tab designs: underline, pills, segmented, outline, light.
  PreferredSizeWidget _tabBar(Color bg, Color fg) {
    final design = '${c.v('tabs', 'design', 'underline')}';
    final items = c.items('tabs');
    final withIcon = c.v('tabs', 'style') == 'icon_title';
    final tabs = [for (final t in items) Tab(height: withIcon ? 56 : 40, text: t.label, icon: withIcon ? Icon(t.icon, size: 20) : null)];
    final scroll = items.length > 4;
    TabBar bar;
    switch (design) {
      case 'pills':
        bar = TabBar(controller: _tabs, isScrollable: scroll, tabAlignment: scroll ? TabAlignment.start : null, dividerColor: Colors.transparent, labelColor: bg, unselectedLabelColor: fg.withOpacity(.8),
            indicatorSize: TabBarIndicatorSize.tab, indicator: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(30)), padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), splashBorderRadius: BorderRadius.circular(30), tabs: tabs);
      case 'segmented':
        bar = TabBar(controller: _tabs, isScrollable: scroll, tabAlignment: scroll ? TabAlignment.start : null, dividerColor: Colors.transparent, labelColor: bg, unselectedLabelColor: fg,
            indicatorSize: TabBarIndicatorSize.tab, indicator: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(12)), indicatorPadding: const EdgeInsets.all(4), tabs: tabs);
        return PreferredSize(
          preferredSize: Size.fromHeight((withIcon ? 56 : 40) + 22),
          child: Container(margin: const EdgeInsets.fromLTRB(12, 0, 12, 10), decoration: BoxDecoration(color: fg.withOpacity(.16), borderRadius: BorderRadius.circular(14)), child: bar),
        );
      case 'outline':
        bar = TabBar(controller: _tabs, isScrollable: scroll, tabAlignment: scroll ? TabAlignment.start : null, dividerColor: Colors.transparent, labelColor: fg, unselectedLabelColor: fg.withOpacity(.75),
            indicatorSize: TabBarIndicatorSize.tab, indicator: BoxDecoration(border: Border.all(color: fg, width: 1.5), borderRadius: BorderRadius.circular(30)), padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), tabs: tabs);
      case 'light':
        bar = TabBar(controller: _tabs, isScrollable: scroll, tabAlignment: scroll ? TabAlignment.start : null, labelColor: bg, unselectedLabelColor: Colors.black54, indicatorColor: bg, tabs: tabs);
        return PreferredSize(preferredSize: Size.fromHeight(withIcon ? 56 : 40), child: Material(color: Colors.white, child: bar));
      default:
        bar = TabBar(controller: _tabs, isScrollable: scroll, tabAlignment: scroll ? TabAlignment.start : null, labelColor: fg, unselectedLabelColor: fg.withOpacity(.7), indicatorColor: fg, tabs: tabs);
    }
    return PreferredSize(preferredSize: Size.fromHeight((withIcon ? 56 : 40) + (design == 'pills' || design == 'outline' ? 8 : 0)), child: bar);
  }

  Widget _drawerItem(NavItem it, {Color? text, bool rounded = false, bool first = false}) {
    final ic = text ?? hexColor(c.v('drawer', 'icon_color'), c.primary);
    if (it.children.isNotEmpty) {
      return ExpansionTile(leading: Icon(it.icon, color: ic), title: Text(it.label, style: TextStyle(color: text)), iconColor: text, collapsedIconColor: text,
          children: [for (final ch in it.children) _drawerItem(ch, text: text, rounded: rounded)]);
    }
    final tile = ListTile(
      leading: Icon(it.icon, color: ic),
      title: Text(it.label, style: TextStyle(color: text, fontWeight: rounded && first ? FontWeight.w700 : null)),
      shape: rounded ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)) : null,
      tileColor: rounded && first ? ic.withOpacity(.12) : null,
      onTap: () {
        Navigator.pop(context);
        open(it.url);
      },
    );
    return rounded ? Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), child: tile) : tile;
  }

  /// Side menu designs: classic, modern, floating, dark, minimal, gradient.
  Widget? _drawer() {
    if (!c.hasDrawer) return null;
    final style = '${c.v('drawer', 'style', 'classic')}';
    if (style == 'classic') return _classicDrawer();
    final about = c.m('about');
    final head = hexColor(c.v('drawer', 'header_bg'), c.primary);
    final dark = style == 'dark' || style == 'gradient';
    final text = dark ? Colors.white : null;
    final sub = '${c.v('drawer', 'subtitle', '')}';
    final img = '${c.v('drawer', 'header_image', '')}';
    final header = Container(
      margin: style == 'modern' ? const EdgeInsets.fromLTRB(12, 12, 12, 8) : EdgeInsets.zero,
      padding: EdgeInsets.fromLTRB(18, style == 'modern' ? 20 : MediaQuery.of(context).padding.top + 22, 18, 20),
      decoration: BoxDecoration(
        color: style == 'minimal' || style == 'gradient' ? Colors.transparent : (style == 'dark' ? const Color(0xFF1E293B) : head),
        borderRadius: style == 'modern' ? BorderRadius.circular(22) : null,
        border: style == 'minimal' ? const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))) : null,
        image: img.isNotEmpty && style != 'minimal' ? DecorationImage(image: NetworkImage(img), fit: BoxFit.cover, colorFilter: const ColorFilter.mode(Colors.black38, BlendMode.darken)) : null,
      ),
      child: Row(children: [
        if (c.iconUrl.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(c.iconUrl, width: 52, height: 52, errorBuilder: (_, __, ___) => const SizedBox())),
        const SizedBox(width: 14),
        Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.name, style: TextStyle(color: style == 'minimal' ? Colors.black87 : Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
          if (sub.isNotEmpty) Text(sub, style: TextStyle(color: style == 'minimal' ? Colors.black54 : Colors.white70)),
        ])),
      ]),
    );
    final list = ListView(padding: EdgeInsets.only(top: style == 'modern' ? MediaQuery.of(context).padding.top : 0, bottom: 16), children: [
      header,
      const SizedBox(height: 6),
      for (var i = 0; i < c.items('drawer').length; i++) _drawerItem(c.items('drawer')[i], text: text, rounded: true, first: i == 0),
      if (c.pages.isNotEmpty) Divider(color: dark ? Colors.white24 : null),
      for (final pg in c.pages) _drawerItem(NavItem({'label': pg.label, 'icon': 'news', 'url': pg.url}), text: text, rounded: true),
      if (about['enabled'] == true)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), leading: Icon(Icons.info_outline_rounded, color: text), title: Text('About', style: TextStyle(color: text)), onTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => AboutView(cfg: c)));
        })),
      if (c.v('share', 'enabled', false) == true)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), leading: Icon(Icons.share_rounded, color: text), title: Text('Share app', style: TextStyle(color: text)), onTap: () { Navigator.pop(context); _share(); })),
    ]);
    final drawer = Drawer(
      backgroundColor: style == 'dark' ? const Color(0xFF0F172A) : (style == 'gradient' ? Colors.transparent : Colors.white),
      shape: style == 'modern' ? const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(28))) : (style == 'floating' ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)) : null),
      child: style == 'gradient'
          ? Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [head, Color.lerp(head, Colors.black, .45)!])), child: list)
          : list,
    );
    if (style == 'floating') {
      return SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: ClipRRect(borderRadius: BorderRadius.circular(26), child: drawer)));
    }
    return drawer;
  }

  Widget _classicDrawer() {
    final about = c.m('about');
    return Drawer(
      child: ListView(padding: EdgeInsets.zero, children: [
        DrawerHeader(
          decoration: BoxDecoration(
            color: hexColor(c.v('drawer', 'header_bg'), c.primary),
            image: '${c.v('drawer', 'header_image', '')}'.isNotEmpty
                ? DecorationImage(image: NetworkImage('${c.v('drawer', 'header_image')}'), fit: BoxFit.cover, colorFilter: const ColorFilter.mode(Colors.black38, BlendMode.darken))
                : null,
          ),
          child: Row(children: [
            if (c.iconUrl.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(c.iconUrl, width: 56, height: 56, errorBuilder: (_, __, ___) => const SizedBox())),
            const SizedBox(width: 14),
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                if ('${c.v('drawer', 'subtitle', '')}'.isNotEmpty) Text('${c.v('drawer', 'subtitle')}', style: const TextStyle(color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        for (final it in c.items('drawer')) _drawerItem(it),
        if (c.pages.isNotEmpty) const Divider(),
        for (final pg in c.pages) ListTile(leading: const Icon(Icons.description_outlined), title: Text(pg.label), onTap: () { Navigator.pop(context); open(pg.url); }),
        if (about['enabled'] == true)
          ListTile(leading: const Icon(Icons.info_outline_rounded), title: const Text('About'), onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => AboutView(cfg: c)));
          }),
        if (c.v('share', 'enabled', false) == true)
          ListTile(leading: const Icon(Icons.share_rounded), title: const Text('Share app'), onTap: () { Navigator.pop(context); _share(); }),
      ]),
    );
  }

  /// Bottom bar designs: material, floating, bubble, notch (centre button), minimal, glass.
  Widget? _bottomBar(Color active) {
    if (!c.hasBottom) return null;
    final items = c.items('bottom_nav');
    final bn = c.m('bottom_nav');
    final bg = hexColor(bn['bg'], Colors.white);
    final design = '${bn['design'] ?? 'material'}';
    final style = '${bn['style'] ?? 'labels'}';
    final sel = _tab.clamp(0, items.length - 1);
    final idle = bg.computeLuminance() > .5 ? Colors.black45 : Colors.white60;
    bool label(bool on) => style == 'icons' ? false : (style == 'selected' ? on : true);
    void tap(int i) {
      setState(() => _tab = i);
      open(items[i].url);
    }

    Widget btn(int i, {bool bubble = false, bool dot = false}) {
      final on = i == sel;
      final color = on ? active : idle;
      final showLabel = !dot && label(on) && !(bubble && !on);
      final child = bubble
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.symmetric(horizontal: on ? 14 : 10, vertical: 9),
              decoration: BoxDecoration(color: on ? active.withOpacity(.14) : Colors.transparent, borderRadius: BorderRadius.circular(30)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(items[i].icon, color: color, size: 22),
                if (showLabel) ...[const SizedBox(width: 6), Text(items[i].label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13))],
              ]),
            )
          : Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(items[i].icon, color: color, size: 24),
              if (showLabel) Padding(padding: const EdgeInsets.only(top: 3), child: Text(items[i].label, style: TextStyle(color: color, fontSize: 11, fontWeight: on ? FontWeight.w700 : FontWeight.w500))),
              if (dot) AnimatedContainer(duration: const Duration(milliseconds: 250), margin: const EdgeInsets.only(top: 4), width: on ? 6 : 0, height: 6, decoration: BoxDecoration(color: active, shape: BoxShape.circle)),
            ]);
      return Expanded(child: InkResponse(onTap: () => tap(i), radius: 32, child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Center(child: child))));
    }

    switch (design) {
      case 'floating':
      case 'glass':
        final glass = design == 'glass';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                height: 66,
                decoration: BoxDecoration(
                  color: glass ? bg.withOpacity(.72) : bg,
                  borderRadius: BorderRadius.circular(28),
                  border: glass ? Border.all(color: Colors.white.withOpacity(.6)) : null,
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))],
                ),
                child: Row(children: [for (var i = 0; i < items.length; i++) btn(i)]),
              ),
            ),
          ),
        );
      case 'bubble':
        return Container(
          color: bg,
          child: SafeArea(child: SizedBox(height: 64, child: Row(children: [for (var i = 0; i < items.length; i++) btn(i, bubble: true)]))),
        );
      case 'minimal':
        return Container(color: bg, child: SafeArea(child: SizedBox(height: 60, child: Row(children: [for (var i = 0; i < items.length; i++) btn(i, dot: true)]))));
      case 'notch':
        final mid = items.length ~/ 2;
        return BottomAppBar(
          color: bg,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          height: 64,
          padding: EdgeInsets.zero,
          child: Row(children: [for (var i = 0; i < items.length; i++) i == mid ? const Expanded(child: SizedBox()) : btn(i)]),
        );
      default:
        return NavigationBar(
          selectedIndex: sel,
          labelBehavior: style == 'icons'
              ? NavigationDestinationLabelBehavior.alwaysHide
              : (style == 'selected' ? NavigationDestinationLabelBehavior.onlyShowSelected : NavigationDestinationLabelBehavior.alwaysShow),
          backgroundColor: bg,
          indicatorColor: active.withOpacity(.15),
          onDestinationSelected: tap,
          destinations: [for (final it in items) NavigationDestination(icon: Icon(it.icon), selectedIcon: Icon(it.icon, color: active), label: it.label)],
        );
    }
  }

  @override
  void dispose() {
    pendingUrl.removeListener(_openPending);
    _banner?.dispose();
    _inter?.dispose();
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = _progress < 100;
    final loader = c.m('loader');
    final lc = hexColor(loader['color'], c.primary);
    final fab = c.m('fab');
    final off = c.m('offline');
    final eng = c.m('engage');
    final bn = c.m('bottom_nav');
    final active = hexColor(bn['active'], c.primary);
    if (eng['maintenance'] == true) {
      return Scaffold(
        backgroundColor: c.pageBg,
        appBar: _appBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.construction_rounded, size: 64, color: c.primary),
              const SizedBox(height: 16),
              Text('${eng['maintenance_title'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('${eng['maintenance_text'] ?? ''}', textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: Scaffold(
        backgroundColor: c.pageBg,
        appBar: _appBar(),
        drawer: _drawer(),
        body: SafeArea(
          top: c.m('header')['enabled'] == false,
          child: Column(children: [
            Expanded(
              child: Stack(children: [
                WebViewWidget(controller: _web),
                if (loading && loader['style'] == 'bar') LinearProgressIndicator(value: _progress / 100, color: lc, backgroundColor: Colors.transparent, minHeight: 3),
                if (loading && loader['style'] == 'spinner') Center(child: CircularProgressIndicator(color: lc)),
                if (loading && loader['style'] == 'dots') Center(child: _Dots(color: lc)),
                if (_offline) _OfflineView(color: c.primary, title: '${off['title'] ?? 'No internet connection'}', text: '${off['text'] ?? ''}', onRetry: () => _web.reload()),
              ]),
            ),
            if (_banner != null) SizedBox(height: _banner!.size.height.toDouble(), width: double.infinity, child: AdWidget(ad: _banner!)),
          ]),
        ),
        floatingActionButton: c.hasBottom && bn['design'] == 'notch'
            ? FloatingActionButton(
                shape: const CircleBorder(),
                backgroundColor: active,
                foregroundColor: Colors.white,
                onPressed: () {
                  final mid = c.items('bottom_nav').length ~/ 2;
                  setState(() => _tab = mid);
                  open(c.items('bottom_nav')[mid].url);
                },
                child: Icon(c.items('bottom_nav')[c.items('bottom_nav').length ~/ 2].icon))
            : fab['type'] == null || fab['type'] == 'none'
            ? null
            : (fab['style'] == 'extended'
                ? FloatingActionButton.extended(backgroundColor: hexColor(fab['color'], Colors.green), foregroundColor: Colors.white, onPressed: _fab,
                    icon: Icon(fab['type'] == 'call' ? Icons.call_rounded : Icons.chat_rounded), label: Text('${fab['label'] ?? ''}'))
                : FloatingActionButton(backgroundColor: hexColor(fab['color'], Colors.green), foregroundColor: Colors.white, onPressed: _fab,
                    child: Icon(fab['type'] == 'call' ? Icons.call_rounded : fab['type'] == 'share' ? Icons.share_rounded : Icons.chat_rounded))),
        extendBody: c.hasBottom && ['floating', 'glass'].contains('${bn['design'] ?? 'material'}'),
        floatingActionButtonLocation: c.hasBottom && bn['design'] == 'notch' ? FloatingActionButtonLocation.centerDocked : null,
        bottomNavigationBar: _bottomBar(active),
      ),
    );
  }
}

/// The notification inbox (bell icon in the header).
class InboxView extends StatefulWidget {
  const InboxView({super.key, required this.cfg});
  final Cfg cfg;
  @override
  State<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<InboxView> {
  List<Map> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => items = ((jsonDecode(prefs.getString('note_inbox') ?? '[]') as List).cast<Map>()));
  }

  String _ago(num? at) {
    if (at == null) return '';
    final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at.toInt() * 1000));
    if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cfg;
    final h = c.m('header');
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), backgroundColor: hexColor(h['bg'], c.primary), foregroundColor: hexColor(h['fg'], Colors.white)),
      body: items.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.notifications_none_rounded, size: 64, color: c.primary.withOpacity(.5)),
              const SizedBox(height: 12),
              const Text('No notifications yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ]))
          : RefreshIndicator(
              onRefresh: () async {
                await checkInbox(Map<String, dynamic>.from(c.raw), show: false);
                await _load();
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final it = items[i];
                  final img = '${it['image'] ?? ''}';
                  final url = '${it['url'] ?? ''}';
                  return Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.5),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: url.isEmpty ? null : () => Navigator.pop(context, url),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text('${it['title']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                            Text(_ago(it['at'] as num?), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ]),
                          const SizedBox(height: 4),
                          Text('${it['body']}'),
                          if (img.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()))),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/// Shown when the owner's plan is not active (or the app was removed): the website is not loaded.
class LockView extends StatelessWidget {
  const LockView({super.key, required this.cfg});
  final Cfg cfg;
  @override
  Widget build(BuildContext context) {
    final pay = '${cfg.raw['pay_url'] ?? ''}';
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0B1739), Color(0xFF1D4ED8)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 24),
            Text('${cfg.raw['lock_title'] ?? 'Subscription required'}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text('${cfg.raw['lock_text'] ?? 'This app is paused. Please renew the subscription.'}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
            const SizedBox(height: 28),
            if (pay.isNotEmpty)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), minimumSize: const Size(220, 52)),
                onPressed: () => launchUrl(Uri.parse(pay), mode: LaunchMode.externalApplication),
                child: const Text('Renew subscription', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
      ),
    );
  }
}

class AboutView extends StatelessWidget {
  const AboutView({super.key, required this.cfg});
  final Cfg cfg;
  @override
  Widget build(BuildContext context) {
    final a = cfg.m('about');
    final links = <(IconData, String, String)>[
      (Icons.chat_rounded, 'WhatsApp', '${a['whatsapp'] ?? ''}'.isNotEmpty ? 'https://wa.me/${'${a['whatsapp']}'.replaceAll(RegExp(r'\D'), '')}' : ''),
      (Icons.call_rounded, 'Call', '${a['phone'] ?? ''}'.isNotEmpty ? 'tel:${a['phone']}' : ''),
      (Icons.mail_rounded, 'Email', '${a['email'] ?? ''}'.isNotEmpty ? 'mailto:${a['email']}' : ''),
      (Icons.public_rounded, 'Website', '${a['website'] ?? ''}'),
      (Icons.facebook_rounded, 'Facebook', '${a['facebook'] ?? ''}'),
      (Icons.camera_alt_rounded, 'Instagram', '${a['instagram'] ?? ''}'),
      (Icons.alternate_email_rounded, 'X / Twitter', '${a['twitter'] ?? ''}'),
      (Icons.play_circle_rounded, 'YouTube', '${a['youtube'] ?? ''}'),
      (Icons.music_note_rounded, 'TikTok', '${a['tiktok'] ?? ''}'),
      (Icons.photo_camera_front_rounded, 'Snapchat', '${a['snapchat'] ?? ''}'),
      (Icons.forum_rounded, 'Messenger', '${a['messenger'] ?? ''}'),
      (Icons.video_call_rounded, 'Skype', '${a['skype'] ?? ''}'.isNotEmpty ? 'skype:${a['skype']}?chat' : ''),
    ].where((l) => l.$3.isNotEmpty).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('About'), backgroundColor: cfg.primary, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        if (cfg.iconUrl.isNotEmpty) Center(child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.network(cfg.iconUrl, width: 96, height: 96, errorBuilder: (_, __, ___) => const SizedBox()))),
        const SizedBox(height: 16),
        Center(child: Text(cfg.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
        const SizedBox(height: 16),
        if ('${a['text'] ?? ''}'.isNotEmpty) Text('${a['text']}', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
        const SizedBox(height: 24),
        for (final l in links)
          Card(child: ListTile(leading: Icon(l.$1, color: cfg.primary), title: Text(l.$2), trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => launchUrl(Uri.parse(l.$3), mode: LaunchMode.externalApplication))),
      ]),
    );
  }
}

class _Dots extends StatefulWidget {
  const _Dots({required this.color});
  final Color color;
  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.all(4), width: 12, height: 12,
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(((_a.value * 3 - i) % 3) < 1 ? 1 : .3)),
          ),
      ]),
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
