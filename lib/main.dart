import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
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

import 'ui_kit.dart';

Color hexColor(dynamic hex, Color fallback) {
  if (hex is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return fallback;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

const _filled = <String, IconData>{
  'home': Icons.home_rounded, 'store': Icons.storefront_rounded, 'cart': Icons.shopping_cart_rounded, 'tag': Icons.local_offer_rounded,
  'info': Icons.info_rounded, 'phone': Icons.call_rounded, 'mail': Icons.mail_rounded, 'person': Icons.person_rounded,
  'search': Icons.search_rounded, 'heart': Icons.favorite_rounded, 'calendar': Icons.event_rounded, 'location': Icons.place_rounded,
  'menu': Icons.menu_rounded, 'star': Icons.star_rounded, 'chat': Icons.chat_rounded, 'gallery': Icons.photo_library_rounded,
  'news': Icons.article_rounded, 'settings': Icons.settings_rounded, 'share': Icons.share_rounded, 'video': Icons.play_circle_rounded,
  'music': Icons.music_note_rounded, 'school': Icons.school_rounded, 'work': Icons.work_rounded, 'help': Icons.help_rounded,
  'bell': Icons.notifications_rounded, 'globe': Icons.public_rounded, 'lock': Icons.lock_rounded, 'gift': Icons.card_giftcard_rounded,
  'reload': Icons.refresh_rounded,
};
/// Modern outline icons (default), matching the dashboard preview.
const _outline = <String, IconData>{
  'home': LucideIcons.home, 'store': LucideIcons.store, 'cart': LucideIcons.shoppingCart, 'tag': LucideIcons.tag,
  'info': LucideIcons.info, 'phone': LucideIcons.phone, 'mail': LucideIcons.mail, 'person': LucideIcons.user,
  'search': LucideIcons.search, 'heart': LucideIcons.heart, 'calendar': LucideIcons.calendar, 'location': LucideIcons.mapPin,
  'menu': LucideIcons.menu, 'star': LucideIcons.star, 'chat': LucideIcons.messageCircle, 'gallery': LucideIcons.image,
  'news': LucideIcons.newspaper, 'settings': LucideIcons.settings, 'share': LucideIcons.share2, 'video': LucideIcons.playCircle,
  'music': LucideIcons.music, 'school': LucideIcons.graduationCap, 'work': LucideIcons.briefcase, 'help': LucideIcons.helpCircle,
  'bell': LucideIcons.bell, 'globe': LucideIcons.globe, 'lock': LucideIcons.lock, 'gift': LucideIcons.gift,
  'reload': LucideIcons.refreshCw,
};
/// The app's own words in the owner's chosen language (website text is not touched).
String appLang = 'en';
const _tr = <String, Map<String, String>>{
  'si': {'Notifications': 'දැනුම්දීම්', 'About': 'අප ගැන', 'Follow us': 'අපව අනුගමනය කරන්න', 'No notifications yet': 'තවම දැනුම්දීම් නැත', 'Try again': 'නැවත උත්සාහ කරන්න', 'Update now': 'දැන් යාවත්කාලීන කරන්න', 'Share app': 'යෙදුම බෙදාගන්න', 'Open': 'විවෘත කරන්න', 'Go home': 'මුල් පිටුවට', 'Rate us': 'අපට ඇගයීමක් දෙන්න', 'Find us': 'අපව සොයන්න', 'Call': 'අමතන්න', 'Email': 'ඊමේල්'},
  'ta': {'Notifications': 'அறிவிப்புகள்', 'About': 'எங்களைப் பற்றி', 'Follow us': 'எங்களைப் பின்தொடருங்கள்', 'No notifications yet': 'இன்னும் அறிவிப்புகள் இல்லை', 'Try again': 'மீண்டும் முயற்சிக்கவும்', 'Update now': 'இப்போது புதுப்பிக்கவும்', 'Share app': 'பகிரவும்', 'Open': 'திற', 'Go home': 'முகப்பு', 'Rate us': 'மதிப்பிடுங்கள்', 'Find us': 'எங்களைக் கண்டறியவும்', 'Call': 'அழைக்க', 'Email': 'மின்னஞ்சல்'},
  'hi': {'Notifications': 'सूचनाएँ', 'About': 'हमारे बारे में', 'Follow us': 'हमें फ़ॉलो करें', 'No notifications yet': 'अभी कोई सूचना नहीं', 'Try again': 'फिर से कोशिश करें', 'Update now': 'अभी अपडेट करें', 'Share app': 'ऐप शेयर करें', 'Open': 'खोलें', 'Go home': 'होम', 'Rate us': 'रेटिंग दें', 'Find us': 'हमें खोजें', 'Call': 'कॉल', 'Email': 'ईमेल'},
};
String tr(String s) => _tr[appLang]?[s] ?? s;

/// Set from the design ("Theme & display" → icon style).
bool outlineIcons = true;
IconData iconOf(dynamic n) => (outlineIcons ? _outline : _filled)[n] ?? (outlineIcons ? LucideIcons.circle : Icons.circle_outlined);

class NavItem {
  NavItem(Map j)
      : label = '${j['label'] ?? j['title'] ?? ''}',
        icon = '${j['icon'] ?? 'home'}',
        url = '${j['url'] ?? ''}',
        badge = '${j['badge'] ?? ''}',
        children = ((j['children'] as List?) ?? []).map((e) => NavItem(e as Map)).toList();
  final String label;
  final String icon;
  final String url;
  final String badge;
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

/// Anonymous usage counts for the owner's dashboard (app opens, bottom bar taps).
void trackEvent(Map bundled, String ev) {
  final u = '${bundled['remote_config'] ?? ''}'.replaceFirst('/api/app-config/', '/api/app-event/');
  if (!u.contains('/api/app-event/')) return;
  http.post(Uri.parse(u), body: {'e': ev}).catchError((_) => http.Response('', 0));
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
  try {
    iconLibrary = jsonDecode(await rootBundle.loadString('assets/icons.json')) as Map<String, dynamic>;
  } catch (_) {}
  builtinIcon = iconOf;
  final cfg = Cfg(merged);
  outlineIcons = cfg.v('style', 'icons', 'outline') != 'filled';
  appLang = '${cfg.v('app', 'language', 'en')}';
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
  trackEvent(bundled, 'open');
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

/// The owner's brand colour is used exactly (buttons, links), not a generated tone.
ThemeData _theme(Cfg cfg, Brightness b) {
  final p = cfg.v('header', 'bg') is String ? hexColor(cfg.v('header', 'bg'), cfg.primary) : cfg.primary;
  final on = p.computeLuminance() > .5 ? Colors.black : Colors.white;
  // A very dark brand colour would vanish on a dark background, so dark mode lightens it.
  final pd = b == Brightness.dark && p.computeLuminance() < .05 ? Colors.white : p;
  final scheme = ColorScheme.fromSeed(seedColor: p, brightness: b).copyWith(primary: pd, onPrimary: pd == Colors.white ? Colors.black : on);
  final font = '${cfg.v('style', 'font', '')}';
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  if (font.isEmpty) return base;
  try {
    return base.copyWith(textTheme: GoogleFonts.getTextTheme(font, base.textTheme));
  } catch (_) {
    return base;
  }
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
        outlineIcons = Cfg(merged).v('style', 'icons', 'outline') != 'filled';
        setState(() => cfg = Cfg(merged));
        applySystemUi(cfg);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    final fu = cfg.m('force_update');
    final myBuild = (cfg.raw['version_code'] as num?)?.toInt() ?? 0;
    if (cfg.raw['locked'] == true) {
      home = LockView(cfg: cfg);
    } else if (fu['enabled'] == true && myBuild > 0 && myBuild < ((fu['min_build'] as num?)?.toInt() ?? 0)) {
      home = Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AppLogo(url: cfg.iconUrl, size: 86, radius: 24),
              const SizedBox(height: 22),
              Text('${fu['title'] ?? 'Update required'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('${fu['text'] ?? 'Please update to the latest version to keep using the app.'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.5)),
              const SizedBox(height: 26),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: const StadiumBorder()),
                onPressed: () {
                  final u = '${fu['url'] ?? ''}';
                  launchUrl(Uri.parse(u.isNotEmpty ? u : 'https://play.google.com/store/apps/details?id=${cfg.raw['package_id'] ?? ''}'), mode: LaunchMode.externalApplication);
                },
                child: Text(tr('Update now'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      );
    } else if (splash) {
      final sp = cfg.m('splash');
      final c1 = hexColor(sp['bg'], Colors.white);
      home = Scaffold(body: LFSplash(
        design: '${sp['design'] ?? 'classic'}',
        c1: c1,
        c2: '${sp['bg2'] ?? ''}'.isNotEmpty ? hexColor(sp['bg2'], c1) : c1,
        titleColor: hexColor(sp['title_color'], const Color(0xFF0F172A)),
        title: '${sp['title'] ?? cfg.name}',
        tagline: '${sp['tagline'] ?? ''}',
        logoUrl: cfg.iconUrl,
        showLogo: sp['show_logo'] != false,
        showTitle: sp['show_title'] != false,
        image: '${sp['image'] ?? ''}',
      ));
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
      theme: _theme(cfg, Brightness.light),
      darkTheme: _theme(cfg, Brightness.dark),
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
  AppOpenAd? _appOpen;
  RewardedAd? _rewarded;
  DateTime _lastInter = DateTime.fromMillisecondsSinceEpoch(0);
  bool _interOnStartDone = false;
  AppLifecycleListener? _life;
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
      ..addJavaScriptChannel('LFScroll', onMessageReceived: _onScrollMsg)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageStarted: (u) => setState(() {
              _lastMain = u;
              _httpErr = 0;
              if (c.v('style', 'page_anim', 'none') != 'none') _pageShown = false;
              _offline = false;
              _barsHidden = false;
            }),
        onPageFinished: (_) async {
          _inject();
          final t = (await _web.getTitle() ?? '').split(RegExp(r' [|\-–] ')).first.trim();
          if (mounted) setState(() {
            _pageTitle = t;
            _pageShown = true;
          });
        },
        onHttpError: (e) {
          final code = e.response?.statusCode ?? 0;
          if (code >= 400 && c.v('errors', 'enabled', true) != false && (e.request?.uri.toString() ?? '') == _lastMain) setState(() => _httpErr = code);
        },
        onUrlChange: (ch) => _lastMain = ch.url ?? _lastMain,
        onWebResourceError: (err) {
          if (err.isForMainFrame ?? true) setState(() => _offline = true);
        },
        onNavigationRequest: _onNavigate,
      ));
    _setup();
    _loadAds();
    WidgetsBinding.instance.addPostFrameCallback((_) => _engage());
    final to = DateTime.tryParse('${c.v('engage', 'countdown_to', '')}');
    if (c.v('engage', 'countdown', false) == true && to != null) {
      void upd() {
        final l = to.difference(DateTime.now());
        if (mounted) setState(() => _left = l.isNegative ? Duration.zero : l);
      }
      upd();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => upd());
    }
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
    // What's new: once after each app update
    final build = (c.raw['version_code'] as num?)?.toInt() ?? 0;
    if (e['whatsnew'] == true && build > 0 && (prefs.getInt('whatsnew_seen') ?? 0) < build && '${e['whatsnew_text'] ?? ''}'.isNotEmpty) {
      await prefs.setInt('whatsnew_seen', build);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [AppLogo(url: c.iconUrl, size: 44, radius: 12), const SizedBox(width: 12), Text('${e['whatsnew_title'] ?? "What's new"}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))]),
            const SizedBox(height: 14),
            Text('${e['whatsnew_text']}', style: const TextStyle(fontSize: 15, height: 1.55)),
            const SizedBox(height: 20),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: const StadiumBorder()), onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ]),
        ),
      );
      return;
    }
    // Promotion: at most once a day
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (e['promo'] == true && '${e['promo_image'] ?? ''}'.isNotEmpty && prefs.getString('promo_day') != today) {
      await prefs.setString('promo_day', today);
      if (!mounted) return;
      final link = '${e['promo_url'] ?? ''}';
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                if (link.isNotEmpty) open(link);
              },
              child: ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.network('${e['promo_image']}', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
            ),
            const SizedBox(height: 14),
            GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.close_rounded))),
          ]),
        ),
      );
      return;
    }
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
    final parts = [h['header'], h['footer']].where((s) => s is String && s.trim().isNotEmpty).toList();
    if (h['hide_header'] == true) parts.add(h['auto_header'] ?? 'body>header,.site-header,#header,[role="banner"]');
    if (h['hide_footer'] == true) parts.add(h['auto_footer'] ?? 'body>footer,.site-footer,#footer,[role="contentinfo"]');
    final sel = parts.join(',');
    var css = sel.isEmpty ? '' : '$sel{display:none!important}';
    if (app['disable_select'] == true) css += '*{-webkit-user-select:none;user-select:none;-webkit-touch-callout:none}input,textarea{-webkit-user-select:text;user-select:text}';
    // Room at the end of every page so a floating bar never covers the last content.
    if (_floatingBar) css += 'body{padding-bottom:96px!important}';
    // "Make my website dark too" (when the app theme is dark or follows a dark phone).
    final darkNow = c.v('style', 'theme') == 'dark' || (c.v('style', 'theme') == 'system' && WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
    if (c.v('style', 'web_dark', false) == true && darkNow) {
      css += 'html{filter:invert(.92) hue-rotate(180deg)!important;background:#111!important}img,video,picture,iframe,svg,[style*="background-image"]{filter:invert(1) hue-rotate(180deg)!important}';
    }
    css += '${app['custom_css'] ?? ''}';
    if (css.trim().isNotEmpty) {
      await _web.runJavaScript('(function(){var s=document.getElementById("lf-hide")||document.head.appendChild(Object.assign(document.createElement("style"),{id:"lf-hide"}));s.textContent=${jsonEncode(css)}})();');
    }
    if (c.m('header')['hide_on_scroll'] == true || c.m('bottom_nav')['hide_on_scroll'] == true) {
      await _web.runJavaScript('(function(){if(window.__lfs)return;window.__lfs=1;var y=scrollY,s="up";addEventListener("scroll",function(){var n=scrollY,d=n>y+12&&n>80?"down":(n<y-12||n<40?"up":s);y=n;if(d!==s){s=d;LFScroll.postMessage(d)}},{passive:true})})();');
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

  Future<void> _loadAds() async {
    final ads = c.m('ads');
    if (ads['enabled'] != true) return;
    final bid = '${ads['banner_id'] ?? ''}';
    if (bid.isNotEmpty) {
      AdSize size;
      switch ('${ads['banner_size'] ?? 'adaptive'}') {
        case 'large':
          size = AdSize.largeBanner;
        case 'medium':
          size = AdSize.mediumRectangle;
        case 'banner':
          size = AdSize.banner;
        default:
          final w = WidgetsBinding.instance.platformDispatcher.views.first;
          final width = (w.physicalSize.width / w.devicePixelRatio).truncate();
          size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width) ?? AdSize.banner;
      }
      _banner = BannerAd(adUnitId: bid, size: size, request: const AdRequest(), listener: BannerAdListener(
        onAdLoaded: (_) => mounted ? setState(() {}) : null,
        onAdFailedToLoad: (ad, _) { ad.dispose(); if (mounted) setState(() => _banner = null); },
      ))..load();
    }
    _loadInter();
    _loadAppOpen();
    _loadRewarded();
    _life = AppLifecycleListener(onResume: _showAppOpen);
  }

  void _loadInter() {
    final iid = '${c.v('ads', 'interstitial_id', '')}';
    if (c.v('ads', 'enabled', false) != true || iid.isEmpty) return;
    InterstitialAd.load(adUnitId: iid, request: const AdRequest(), adLoadCallback: InterstitialAdLoadCallback(
      onAdLoaded: (ad) {
        _inter = ad;
        if (c.v('ads', 'inter_on_start', false) == true && !_interOnStartDone) {
          _interOnStartDone = true;
          _showInter();
        }
      },
      onAdFailedToLoad: (_) => _inter = null,
    ));
  }

  void _showInter() {
    final gap = (c.v('ads', 'inter_gap', 60) as num?)?.toInt() ?? 60;
    if (_inter == null || DateTime.now().difference(_lastInter).inSeconds < gap) return;
    _lastInter = DateTime.now();
    _inter!.show();
    _inter = null;
    _loadInter();
  }

  void _loadAppOpen() {
    final id = '${c.v('ads', 'app_open_id', '')}';
    if (c.v('ads', 'enabled', false) != true || id.isEmpty) return;
    AppOpenAd.load(adUnitId: id, request: const AdRequest(), adLoadCallback: AppOpenAdLoadCallback(
      onAdLoaded: (ad) => _appOpen = ad,
      onAdFailedToLoad: (_) => _appOpen = null,
    ));
  }

  void _showAppOpen() {
    final ad = _appOpen;
    if (ad == null) return;
    _appOpen = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(onAdDismissedFullScreenContent: (a) { a.dispose(); _loadAppOpen(); }, onAdFailedToShowFullScreenContent: (a, _) { a.dispose(); _loadAppOpen(); });
    ad.show();
  }

  void _loadRewarded() {
    final id = '${c.v('ads', 'rewarded_id', '')}';
    if (c.v('ads', 'enabled', false) != true || id.isEmpty) return;
    RewardedAd.load(adUnitId: id, request: const AdRequest(), rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) => _rewarded = ad,
      onAdFailedToLoad: (_) => _rewarded = null,
    ));
  }

  /// A website link to "#reward" shows a rewarded ad; the page gets a "launchfly:reward" event afterwards.
  void _showRewarded() {
    final ad = _rewarded;
    if (ad == null) return;
    _rewarded = null;
    ad.show(onUserEarnedReward: (_, __) => _web.runJavaScript('window.dispatchEvent(new Event("launchfly:reward"))'));
    _loadRewarded();
  }

  void _countNav() {
    final every = (c.v('ads', 'tap_count', 0) as num?)?.toInt() ?? 0;
    if (every <= 0 || _inter == null) return;
    if (++_navCount % every == 0) _showInter();
  }

  NavigationDecision _onNavigate(NavigationRequest req) {
    final uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    if (uri.fragment == 'reward' && _rewarded != null) {
      _showRewarded();
      return NavigationDecision.prevent;
    }
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
    if (url.startsWith('browser:')) {
      await launchUrl(Uri.parse(url.substring(8)), mode: LaunchMode.externalApplication);
      return;
    }
    if (url.startsWith('app://')) {
      switch (url.substring(6)) {
        case 'about':
          Navigator.push(context, MaterialPageRoute(builder: (_) => AboutView(cfg: c)));
        case 'share':
          _share();
        case 'inbox':
          _openInbox();
        default:
          await _web.loadRequest(Uri.parse(c.url));
      }
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || url.isEmpty) return;
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      await _web.loadRequest(uri);
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _share() async {
    var text = '${c.v('share', 'text', '') ?? ''}'.isNotEmpty ? '${c.v('share', 'text')}' : '${c.name} ${c.url}';
    if (c.v('share', 'referral', false) == true) {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString('ref_id');
      if (id == null) {
        id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
        await prefs.setString('ref_id', id);
      }
      text += '\n${c.url}${c.url.contains('?') ? '&' : '?'}ref=$id';
    }
    Share.share(text);
  }

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
          if (e['rate'] == true)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, false);
                launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=${c.raw['package_id'] ?? ''}'), mode: LaunchMode.externalApplication);
              },
              child: Text(tr('Rate us')),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('${e['no'] ?? 'No'}')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('${e['yes'] ?? 'Yes'}')),
        ],
      ),
    );
    if (leave == true) await SystemNavigator.pop();
  }

  final _sk = GlobalKey<ScaffoldState>();
  bool _barsHidden = false;

  /// The top header (designs: classic, minimal, floating, glass, curved, large).
  Widget? _header() {
    final h = c.m('header');
    if (h['enabled'] == false) return null;
    final bg = hexColor(h['bg'], c.primary);
    final bg2 = '${h['bg2'] ?? ''}'.isNotEmpty ? hexColor(h['bg2'], bg) : bg;
    final fg = hexColor(h['fg'], Colors.white);
    final left = '${h['left_icon'] ?? 'auto'}';
    Widget? leading;
    if (left == 'back') {
      leading = IconButton(icon: Icon(outlineIcons ? LucideIcons.arrowLeft : Icons.arrow_back_rounded), onPressed: () => _web.goBack());
    } else if (left == 'home') {
      leading = IconButton(icon: Icon(outlineIcons ? LucideIcons.home : Icons.home_rounded), onPressed: () => open(c.url));
    } else if (c.hasDrawer && (left == 'auto' || left == 'menu')) {
      leading = IconButton(icon: Icon(outlineIcons ? LucideIcons.menu : Icons.menu_rounded), onPressed: () => c.v('drawer', 'side') == 'right' ? _sk.currentState?.openEndDrawer() : _sk.currentState?.openDrawer());
    }
    return LFHeader(
      design: '${h['design'] ?? 'classic'}',
      bg: bg,
      bg2: bg2,
      fg: fg,
      statusBg: hexColor(c.v('style', 'status_bg'), bg),
      statusCustom: c.v('style', 'status_mode', 'header') == 'custom',
      searchHint: '${h['search_hint'] ?? 'Search'}',
      image: '${h['image'] ?? ''}',
      onSearch: (q) {
        final tpl = '${h['search_url'] ?? ''}';
        open(tpl.contains('{q}') ? tpl.replaceAll('{q}', Uri.encodeQueryComponent(q)) : '${c.url}${c.url.contains('?') ? '&' : '?'}s=${Uri.encodeQueryComponent(q)}');
      },
      pageBg: c.pageBg,
      title: h['page_title'] == true && _pageTitle.isNotEmpty ? _pageTitle : '${h['title'] ?? c.name}',
      subtitle: '${h['subtitle'] ?? ''}',
      center: h['style'] == 'center',
      hidden: _barsHidden && h['hide_on_scroll'] == true,
      leading: leading,
      logo: h['show_logo'] == true && c.iconUrl.isNotEmpty
          ? AppLogo(url: c.iconUrl, size: 30, radius: 9)
          : null,
      actions: [
        if (c.v('notify', 'enabled', true) != false && c.v('notify', 'inbox', true) != false)
          IconButton(icon: Badge(isLabelVisible: _unread > 0, label: Text('$_unread'), child: Icon(outlineIcons ? LucideIcons.bell : Icons.notifications_rounded)), onPressed: _openInbox),
        if (h['search_icon'] == true) IconButton(icon: Icon(outlineIcons ? LucideIcons.search : Icons.search_rounded), onPressed: _searchDialog),
        if ('${h['cart_url'] ?? ''}'.isNotEmpty) IconButton(icon: Icon(outlineIcons ? LucideIcons.shoppingCart : Icons.shopping_cart_rounded), onPressed: () => open('${h['cart_url']}')),
        for (final ri in ((h['right_icons'] as List?) ?? []).cast<Map>()) IconButton(icon: AppIco('${ri['icon']}'), onPressed: () => _action(ri)),
      ],
      bottom: c.hasTabs && _tabs != null ? _tabBar(h['design'] == 'minimal' ? c.pageBg : bg, h['design'] == 'minimal' ? bg : fg) : null,
    );
  }

  String _pageTitle = '';
  int _httpErr = 0;
  String _lastMain = '';
  Timer? _tick;
  Duration _left = Duration.zero;
  bool _pageShown = true;
  bool _dial = false;

  void _runSearch(String q) {
    final h = c.m('header');
    final tpl = '${h['search_url'] ?? ''}';
    open(tpl.contains('{q}') ? tpl.replaceAll('{q}', Uri.encodeQueryComponent(q)) : '${c.url}${c.url.contains('?') ? '&' : '?'}s=${Uri.encodeQueryComponent(q)}');
  }

  Future<void> _searchDialog() async {
    final ctl = TextEditingController();
    final q = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: TextField(
          controller: ctl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: '${c.v('header', 'search_hint', 'Search')}', prefixIcon: const Icon(Icons.search_rounded), filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
      ),
    );
    if (q != null && q.trim().isNotEmpty) _runSearch(q.trim());
  }

  Widget _countdownBar() {
    final e = c.m('engage');
    final col = hexColor(e['countdown_color'], const Color(0xFFEF4444));
    String two(int n) => n.toString().padLeft(2, '0');
    final d = _left.inDays, h = _left.inHours % 24, m = _left.inMinutes % 60, sec = _left.inSeconds % 60;
    Widget box(String v, String l) => Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.white.withOpacity(.2), borderRadius: BorderRadius.circular(6)), child: Text('$v$l', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)));
    return GestureDetector(
      onTap: () => '${e['countdown_url'] ?? ''}'.isNotEmpty ? open('${e['countdown_url']}') : null,
      child: Container(
        color: col,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text('${e['countdown_text'] ?? 'Sale ends in'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          if (d > 0) box('$d', 'd'),
          box(two(h), 'h'),
          box(two(m), 'm'),
          box(two(sec), 's'),
        ]),
      ),
    );
  }

  /// The website reports scrolling so the header/bottom bar can hide while reading.
  void _onScrollMsg(JavaScriptMessage m) {
    final down = m.message == 'down';
    if (down != _barsHidden && mounted) setState(() => _barsHidden = down);
  }

  /// Top tab designs: underline, pills, segmented, outline, light.
  PreferredSizeWidget _tabBar(Color bg, Color fg) {
    final design = '${c.v('tabs', 'design', 'underline')}';
    final items = c.items('tabs');
    final withIcon = c.v('tabs', 'style') == 'icon_title';
    final tabs = [for (final t in items) Tab(height: withIcon ? 56 : 40, text: t.label, icon: withIcon ? AppIco(t.icon, size: 20) : null)];
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
    final light = text == null || text.computeLuminance() < .5;
    final ic = light ? hexColor(c.v('drawer', 'icon_color'), c.primary) : text;
    text ??= const Color(0xFF0F172A);
    final ls = '${c.v('drawer', 'list_style', 'pill')}';
    // A section title, e.g. "Shop" or "Help" (link: app://heading)
    if (it.url == 'app://heading') {
      return Padding(padding: const EdgeInsets.fromLTRB(26, 18, 20, 6), child: Text(it.label.toUpperCase(), style: TextStyle(color: text.withOpacity(.5), fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)));
    }
    if (it.children.isEmpty && ls != 'pill') {
      void go() {
        Navigator.pop(context);
        open(it.url);
      }
      final lead = ls == 'iconbox'
          ? Container(width: 38, height: 38, decoration: BoxDecoration(color: first ? ic : ic.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: Center(child: AppIco(it.icon, color: first ? Colors.white : ic, size: 20)))
          : AppIco(it.icon, color: ic, size: 22);
      final label = Text(it.label, style: TextStyle(color: text, fontSize: ls == 'bold' ? 19 : 15.5, fontWeight: ls == 'bold' || first ? FontWeight.w700 : FontWeight.w500));
      final badge = it.badge.isEmpty ? null : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(20)), child: Text(it.badge, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)));
      final row = Row(children: [if (ls != 'bold') ...[lead, const SizedBox(width: 14)], Expanded(child: label), if (badge != null) badge]);
      switch (ls) {
        case 'card':
          return Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 4), child: Material(color: first ? ic.withOpacity(.1) : (light ? Colors.white : Colors.white.withOpacity(.06)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: first ? ic : text.withOpacity(.1))), child: InkWell(borderRadius: BorderRadius.circular(16), onTap: go, child: Padding(padding: const EdgeInsets.all(14), child: row))));
        case 'bar':
          return InkWell(onTap: go, child: Container(padding: const EdgeInsets.fromLTRB(20, 14, 20, 14), decoration: BoxDecoration(color: first ? ic.withOpacity(.08) : null, border: Border(left: BorderSide(color: first ? ic : Colors.transparent, width: 4))), child: row));
        case 'divider':
          return InkWell(onTap: go, child: Container(margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: text.withOpacity(.08)))), child: Row(children: [Expanded(child: row), Icon(Icons.chevron_right_rounded, color: text.withOpacity(.35))])));
        default: // iconbox, bold, plain
          return InkWell(onTap: go, child: Padding(padding: EdgeInsets.symmetric(horizontal: 22, vertical: ls == 'bold' ? 12 : 10), child: row));
      }
    }
    if (it.children.isNotEmpty) {
      return ExpansionTile(leading: AppIco(it.icon, color: ic), title: Text(it.label, style: TextStyle(color: text)), iconColor: text, collapsedIconColor: text,
          textColor: text, collapsedTextColor: text, shape: const Border(), collapsedShape: const Border(),
          children: [for (final ch in it.children) Padding(padding: const EdgeInsets.only(left: 14), child: _drawerItem(ch, text: text, rounded: rounded))]);
    }
    final tile = ListTile(
      leading: AppIco(it.icon, color: ic, size: 22),
      title: Text(it.label, style: TextStyle(color: first && light ? ic : text, fontWeight: first ? FontWeight.w700 : FontWeight.w500)),
      shape: rounded ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)) : null,
      tileColor: first ? (light ? ic.withOpacity(.12) : Colors.white.withOpacity(.12)) : null,
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
    final about = c.m('about');
    final head = hexColor(c.v('drawer', 'header_bg'), c.primary);
    final dark = style == 'dark' || style == 'gradient';
    final Color text = dark ? Colors.white : const Color(0xFF0F172A);
    final sub = '${c.v('drawer', 'subtitle', '')}';
    final img = '${c.v('drawer', 'header_image', '')}';
    final header = LFDrawerHeader(
      design: '${c.v('drawer', 'header_style', 'card')}',
      color: style == 'dark' ? const Color(0xFF1E293B) : head,
      title: c.name,
      subtitle: sub,
      logoUrl: c.iconUrl,
      dark: dark,
      image: img,
    );
    final list = ListView(padding: EdgeInsets.only(top: style == 'floating' ? 0 : 0, bottom: 16), children: [
      header,
      const SizedBox(height: 6),
      for (var i = 0; i < c.items('drawer').length; i++) SlideIn(index: i, child: _drawerItem(c.items('drawer')[i], text: text, rounded: true, first: i == 0)),
      if (c.pages.isNotEmpty) Divider(color: dark ? Colors.white24 : null),
      for (final pg in c.pages) _drawerItem(NavItem({'label': pg.label, 'icon': 'news', 'url': pg.url}), text: text, rounded: true),
      if ('${c.v('drawer', 'footer_label', '')}'.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: dark ? Colors.white : const Color(0xFF0F172A), foregroundColor: dark ? const Color(0xFF0F172A) : Colors.white, minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
            onPressed: () {
              Navigator.pop(context);
              open('${c.v('drawer', 'footer_url', '')}');
            },
            child: Text('${c.v('drawer', 'footer_label')}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      if (about['enabled'] == true)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), leading: Icon(Icons.info_outline_rounded, color: dark ? text : hexColor(c.v('drawer', 'icon_color'), c.primary)), title: Text(tr('About'), style: TextStyle(color: text, fontWeight: FontWeight.w500)), onTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => AboutView(cfg: c)));
        })),
      if (c.v('share', 'enabled', false) == true)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), leading: Icon(Icons.share_rounded, color: dark ? text : hexColor(c.v('drawer', 'icon_color'), c.primary)), title: Text(tr('Share app'), style: TextStyle(color: text, fontWeight: FontWeight.w500)), onTap: () { Navigator.pop(context); _share(); })),
    ]);
    final drawer = Drawer(
      backgroundColor: style == 'dark' ? const Color(0xFF0F172A) : (style == 'gradient' ? Colors.transparent : Colors.white),
      surfaceTintColor: Colors.transparent,
      shape: style == 'modern' || style == 'minimal' || style == 'dark' || style == 'gradient'
          ? const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(24)))
          : (style == 'floating' ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)) : const RoundedRectangleBorder()),
      child: c.v('drawer', 'bg_style') == 'dots' && style != 'gradient'
          ? dotsBackground((dark ? Colors.white : head).withOpacity(.08), list)
          : c.v('drawer', 'bg_style') == 'tint' && !dark
          ? ColoredBox(color: Color.lerp(Colors.white, head, .07)!, child: list)
          : style == 'gradient'
          ? Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [head, Color.lerp(head, Colors.black, .45)!])), child: list)
          : list,
    );
    if (style == 'floating') {
      return SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: ClipRRect(borderRadius: BorderRadius.circular(26), child: drawer)));
    }
    return drawer;
  }

  bool get _floatingBar => c.hasBottom && LFBottomBar.floating.contains('${c.v('bottom_nav', 'design', 'material')}');

  /// Bottom bar: notch (centre button) is built here, every other design comes from LFBottomBar.
  Widget? _bottomBar(Color active) {
    if (!c.hasBottom) return null;
    final items = c.items('bottom_nav');
    final bn = c.m('bottom_nav');
    final bg = hexColor(bn['bg'], Colors.white);
    final design = '${bn['design'] ?? 'material'}';
    final style = '${bn['style'] ?? 'labels'}';
    final sel = _tab.clamp(0, items.length - 1);
    void tap(int i) {
      setState(() => _tab = i);
      trackEvent(c.raw, 'tab:${items[i].label}');
      open(items[i].url);
    }

    Widget bar;
    if (design == 'notch') {
      final idle = bg.computeLuminance() > .5 ? const Color(0xFF94A3B8) : Colors.white60;
      final mid = items.length ~/ 2;
      Widget btn(int i) {
        final on = i == sel;
        final col = on ? active : idle;
        return Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => tap(i), child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedScale(scale: on ? 1.12 : 1, duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack, child: AppIco(items[i].icon, color: col)),
          if (style != 'icons' && (style != 'selected' || on)) Padding(padding: const EdgeInsets.only(top: 3), child: Text(items[i].label, style: TextStyle(color: col, fontSize: 11, fontWeight: on ? FontWeight.w700 : FontWeight.w500))),
        ])));
      }

      bar = BottomAppBar(
        color: bg,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 66,
        padding: EdgeInsets.zero,
        elevation: 12,
        child: Row(children: [
          Expanded(child: Row(children: [for (var i = 0; i < mid; i++) btn(i)])),
          const SizedBox(width: 76),
          Expanded(child: Row(children: [for (var i = mid + 1; i < items.length; i++) btn(i)])),
        ]),
      );
    } else {
      bar = LFBottomBar(
        items: [for (final it in items) BarItem(it.icon, it.label, it.badge)],
        selected: sel,
        onTap: tap,
        design: design,
        bg: bg,
        active: active,
        labels: style,
      );
    }
    // Hide while scrolling down (optional).
    final hide = _barsHidden && bn['hide_on_scroll'] == true;
    return AnimatedSlide(offset: hide ? const Offset(0, 1.4) : Offset.zero, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic, child: bar);
  }

  @override
  void dispose() {
    pendingUrl.removeListener(_openPending);
    _tick?.cancel();
    _life?.dispose();
    _appOpen?.dispose();
    _rewarded?.dispose();
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
    final mf = DateTime.tryParse('${eng['maint_from'] ?? ''}'), mt = DateTime.tryParse('${eng['maint_to'] ?? ''}');
    final now = DateTime.now();
    final scheduled = mf != null && now.isAfter(mf) && (mt == null || now.isBefore(mt));
    if (eng['maintenance'] == true || scheduled) {
      final ink = c.pageBg.computeLuminance() > .5 ? const Color(0xFF0F172A) : Colors.white;
      return Scaffold(
        backgroundColor: c.pageBg,
        body: Column(children: [if (_header() != null) _header()!, Expanded(child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.construction_rounded, size: 64, color: c.primary.computeLuminance() < .05 && c.pageBg.computeLuminance() < .5 ? Colors.white : c.primary),
              const SizedBox(height: 16),
              Text('${eng['maintenance_title'] ?? ''}', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 8),
              Text('${eng['maintenance_text'] ?? ''}', textAlign: TextAlign.center, style: TextStyle(color: ink.withOpacity(.7))),
            ]),
          ),
        ))]),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: Scaffold(
        key: _sk,
        backgroundColor: c.pageBg,
        drawer: c.v('drawer', 'side') == 'right' ? null : _drawer(),
        endDrawer: c.v('drawer', 'side') == 'right' ? _drawer() : null,
        body: SafeArea(
          top: c.m('header')['enabled'] == false,
          bottom: !_floatingBar,
          child: Column(children: [
            if (_header() != null) MediaQuery.removePadding(context: context, removeTop: false, child: _header()!),
            if (_left > Duration.zero) _countdownBar(),
            if (_banner != null && c.v('ads', 'banner_position') == 'top') SizedBox(height: _banner!.size.height.toDouble(), width: double.infinity, child: AdWidget(ad: _banner!)),
            Expanded(
              child: Stack(children: [
                AnimatedSlide(
                  offset: _pageShown || c.v('style', 'page_anim') != 'slide' ? Offset.zero : const Offset(.06, 0),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _pageShown ? 1 : .25,
                    duration: const Duration(milliseconds: 280),
                    child: c.v('app', 'swipe_back', false) == true
                        ? GestureDetector(
                            onHorizontalDragEnd: (d) async {
                              if ((d.primaryVelocity ?? 0) > 900 && await _web.canGoBack()) _web.goBack();
                            },
                            child: WebViewWidget(controller: _web),
                          )
                        : WebViewWidget(controller: _web),
                  ),
                ),
                if (loading && loader['style'] == 'bar') LinearProgressIndicator(value: _progress / 100, color: lc, backgroundColor: Colors.transparent, minHeight: 3),
                if (loading && loader['style'] == 'dots') Center(child: _Dots(color: lc)),
                if (loading && lfLoader('${loader['style']}', lc) != null) Center(child: lfLoader('${loader['style']}', lc)),
                if (loading && loader['style'] == 'skeleton') const Positioned.fill(child: _Skeleton()),
                if (_offline) _OfflineView(color: c.primary, title: '${off['title'] ?? 'No internet connection'}', text: '${off['text'] ?? ''}', image: '${off['image'] ?? ''}', onRetry: () => _web.reload()),
                if (_httpErr > 0 && !_offline)
                  _OfflineView(
                    color: c.primary,
                    icon: Icons.search_off_rounded,
                    title: '${c.v('errors', 'title', 'Page not found')}',
                    text: '${c.v('errors', 'text', "The page you're looking for isn't here.")}',
                    image: '${c.v('errors', 'image', '')}',
                    button: tr('Go home'),
                    onRetry: () {
                      setState(() => _httpErr = 0);
                      open(c.url);
                    },
                  ),
              ]),
            ),
            if (_banner != null && c.v('ads', 'banner_position') != 'top') SizedBox(height: _banner!.size.height.toDouble(), width: double.infinity, child: AdWidget(ad: _banner!)),
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
                child: AppIco(c.items('bottom_nav')[c.items('bottom_nav').length ~/ 2].icon, color: Colors.white))
            : fab['type'] == 'speeddial'
            ? Padding(
                padding: EdgeInsets.only(bottom: _floatingBar ? 6 : 0),
                child: LFSpeedDial(
                  open: _dial,
                  color: hexColor(fab['color'], Colors.green),
                  items: [for (final it in ((fab['items'] as List?) ?? []).cast<Map>()) ('${it['icon'] ?? 'chat'}', '${it['label'] ?? ''}', '${it['url'] ?? ''}')],
                  onToggle: () => setState(() => _dial = !_dial),
                  onPick: (u) {
                    setState(() => _dial = false);
                    open(u);
                  },
                ),
              )
            : fab['type'] == null || fab['type'] == 'none'
            ? null
            : Padding(
                padding: EdgeInsets.only(bottom: _floatingBar ? 6 : 0),
                child: LFFab(
                  design: '${fab['design'] ?? (fab['style'] == 'extended' ? 'pill' : 'circle')}',
                  color: hexColor(fab['color'], Colors.green),
                  icon: fab['type'] == 'call' ? LucideIcons.phone : fab['type'] == 'share' ? LucideIcons.share2 : fab['type'] == 'link' ? LucideIcons.externalLink : LucideIcons.messageCircle,
                  label: '${fab['label'] ?? 'Chat'}',
                  onTap: _fab,
                ),
              ),
        extendBody: _floatingBar,
        floatingActionButtonLocation: c.hasBottom && bn['design'] == 'notch'
            ? FloatingActionButtonLocation.centerDocked
            : {'left': FloatingActionButtonLocation.startFloat, 'center': FloatingActionButtonLocation.centerFloat}['${fab['position'] ?? 'right'}'],
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
    final bg = hexColor(h['bg'], c.primary);
    final bg2 = '${h['bg2'] ?? ''}'.isNotEmpty ? hexColor(h['bg2'], bg) : Color.lerp(bg, Colors.black, .35)!;
    final fg = hexColor(h['fg'], Colors.white);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF1E293B) : Colors.white;
    final ink = dark ? Colors.white : const Color(0xFF0F172A);
    final accent = bg.computeLuminance() < .05 && dark ? Colors.white : bg;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA),
      body: Column(children: [
        Container(
          padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 6, 16, 22),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [bg, bg2], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconButton(icon: Icon(outlineIcons ? LucideIcons.arrowLeft : Icons.arrow_back_rounded, color: fg), onPressed: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Row(children: [
                Expanded(child: Text(tr('Notifications'), style: TextStyle(color: fg, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.6))),
                if (items.isNotEmpty)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: Colors.white.withOpacity(.2), borderRadius: BorderRadius.circular(20)), child: Text('${items.length}', style: TextStyle(color: fg, fontWeight: FontWeight.w700))),
              ]),
            ),
            Padding(padding: const EdgeInsets.only(left: 10, top: 2), child: Text('News and offers from ${c.name}', style: TextStyle(color: fg.withOpacity(.75)))),
          ]),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 96, height: 96, decoration: BoxDecoration(color: accent.withOpacity(.1), shape: BoxShape.circle), child: Icon(LucideIcons.bellOff, size: 40, color: accent)),
                    const SizedBox(height: 16),
                    Text(tr('No notifications yet'), style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('We\'ll let you know when something new arrives.', style: TextStyle(color: ink.withOpacity(.55))),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await checkInbox(Map<String, dynamic>.from(c.raw), show: false);
                    await _load();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final it = items[i];
                      final img = '${it['image'] ?? ''}';
                      final url = '${it['url'] ?? ''}';
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 300 + i * 60),
                        curve: Curves.easeOutCubic,
                        builder: (_, t, ch) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: ch)),
                        child: Material(
                          color: card,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: url.isEmpty ? null : () => Navigator.pop(context, url),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Container(width: 44, height: 44, decoration: BoxDecoration(gradient: LinearGradient(colors: [bg, bg2]), borderRadius: BorderRadius.circular(14)), child: Icon(LucideIcons.bell, color: fg, size: 20)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Expanded(child: Text('${it['title']}', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 15.5))),
                                        Text(_ago(it['at'] as num?), style: TextStyle(fontSize: 12, color: ink.withOpacity(.45))),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text('${it['body']}', style: TextStyle(color: ink.withOpacity(.7), height: 1.4)),
                                    ]),
                                  ),
                                ]),
                                if (img.isNotEmpty)
                                  Padding(padding: const EdgeInsets.only(top: 12), child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()))),
                                if (url.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10, left: 56),
                                    child: Row(children: [Text(tr('Open'), style: TextStyle(color: accent, fontWeight: FontWeight.w700)), const SizedBox(width: 4), Icon(LucideIcons.arrowRight, size: 16, color: accent)]),
                                  ),
                              ]),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]),
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
              decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(24)),
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
    String v(String k) => '${a[k] ?? ''}'.trim();
    // (icon, label, link, brand colour)
    final qrLink = '${cfg.v('share', 'qr', false) == true ? 'https://play.google.com/store/apps/details?id=${cfg.raw['package_id'] ?? ''}' : ''}';
    final quick = <(IconData, String, String, Color)>[
      if (v('map_url').isNotEmpty) (LucideIcons.mapPin, tr('Find us'), v('map_url'), const Color(0xFFDC2626)),
      if (v('phone').isNotEmpty) (LucideIcons.phone, tr('Call'), 'tel:${v('phone')}', const Color(0xFF2563EB)),
      if (v('whatsapp').isNotEmpty) (LucideIcons.messageCircle, 'WhatsApp', 'https://wa.me/${v('whatsapp').replaceAll(RegExp(r'\D'), '')}', const Color(0xFF16A34A)),
      if (v('email').isNotEmpty) (LucideIcons.mail, tr('Email'), 'mailto:${v('email')}', const Color(0xFFEA580C)),
      if (v('website').isNotEmpty) (LucideIcons.globe, 'Website', v('website'), const Color(0xFF7C3AED)),
    ];
    final social = <(IconData, String, String, Color)>[
      (LucideIcons.facebook, 'Facebook', v('facebook'), const Color(0xFF1877F2)),
      (LucideIcons.instagram, 'Instagram', v('instagram'), const Color(0xFFE1306C)),
      (LucideIcons.twitter, 'X / Twitter', v('twitter'), const Color(0xFF0F172A)),
      (LucideIcons.youtube, 'YouTube', v('youtube'), const Color(0xFFFF0000)),
      (LucideIcons.music2, 'TikTok', v('tiktok'), const Color(0xFF111111)),
      (LucideIcons.ghost, 'Snapchat', v('snapchat'), const Color(0xFFF7C600)),
      (LucideIcons.messagesSquare, 'Messenger', v('messenger'), const Color(0xFF0084FF)),
      (LucideIcons.video, 'Skype', v('skype').isNotEmpty ? 'skype:${v('skype')}?chat' : '', const Color(0xFF00AFF0)),
    ].where((l) => l.$3.isNotEmpty).toList();
    final h = cfg.m('header');
    final bg = hexColor(h['bg'], cfg.primary);
    final bg2 = '${h['bg2'] ?? ''}'.isNotEmpty ? hexColor(h['bg2'], bg) : Color.lerp(bg, Colors.black, .35)!;
    final fg = hexColor(h['fg'], Colors.white);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF1E293B) : Colors.white;
    final ink = dark ? Colors.white : const Color(0xFF0F172A);
    void go(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              height: MediaQuery.of(context).padding.top + 190,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [bg, bg2], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Stack(children: [
                Positioned(right: -60, top: -40, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.08)))),
                Positioned(left: -30, bottom: -70, child: Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.06)))),
                Positioned(
                  left: 8,
                  top: MediaQuery.of(context).padding.top + 6,
                  child: IconButton(icon: Icon(outlineIcons ? LucideIcons.arrowLeft : Icons.arrow_back_rounded, color: fg), onPressed: () => Navigator.pop(context)),
                ),
                Positioned(left: 0, right: 0, top: MediaQuery.of(context).padding.top + 16, child: Text(tr('About'), textAlign: TextAlign.center, style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w700))),
              ]),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 110, 16, 0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 30, offset: Offset(0, 12))]),
                child: Column(children: [
                  Transform.translate(
                    offset: const Offset(0, -42),
                    child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(30)), child: AppLogo(url: cfg.iconUrl, size: 88, radius: 24)),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: Column(children: [
                      Text(cfg.name, textAlign: TextAlign.center, style: TextStyle(color: ink, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.4)),
                      if (v('text').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(v('text'), textAlign: TextAlign.center, style: TextStyle(color: ink.withOpacity(.65), fontSize: 15, height: 1.5))),
                    ]),
                  ),
                  if (quick.isNotEmpty)
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      for (final q in quick)
                        GestureDetector(
                          onTap: () => go(q.$3),
                          child: Column(children: [
                            Container(width: 54, height: 54, decoration: BoxDecoration(color: q.$4.withOpacity(.12), borderRadius: BorderRadius.circular(18)), child: Icon(q.$1, color: q.$4, size: 23)),
                            const SizedBox(height: 6),
                            Text(q.$2, style: TextStyle(color: ink.withOpacity(.75), fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                    ]),
                ]),
              ),
            ),
          ]),
        ),
        if (qrLink.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(22)),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network('https://api.qrserver.com/v1/create-qr-code/?size=240x240&margin=8&data=${Uri.encodeComponent(qrLink)}', width: 110, height: 110, errorBuilder: (_, __, ___) => const SizedBox(width: 110))),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Share app'), style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Scan to download ${cfg.name}', style: TextStyle(color: ink.withOpacity(.6))),
                  ])),
                ]),
              ),
            ),
          ),
        if (social.isNotEmpty) ...[
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(22, 26, 22, 10), child: Text(tr('Follow us'), style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)))),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.6,
              children: [
                for (final l in social)
                  Material(
                    color: card,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => go(l.$3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(children: [
                          Container(width: 38, height: 38, decoration: BoxDecoration(color: l.$4, borderRadius: BorderRadius.circular(12)), child: Icon(l.$1, color: Colors.white, size: 19)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(l.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ] else
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
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
  const _OfflineView({required this.color, required this.title, required this.text, required this.onRetry, this.image = '', this.icon = Icons.wifi_off_rounded, this.button});
  final Color color;
  final String title, text, image;
  final IconData icon;
  final String? button;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final accent = color.computeLuminance() < .05 ? const Color(0xFF0F172A) : color;
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (image.isNotEmpty)
          ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(image, height: 180, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(icon, size: 64, color: accent)))
        else
          Container(width: 110, height: 110, decoration: BoxDecoration(color: accent.withOpacity(.1), shape: BoxShape.circle), child: Icon(icon, size: 50, color: accent)),
        const SizedBox(height: 22),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), height: 1.5)),
        const SizedBox(height: 26),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: accent, minimumSize: const Size(180, 50), shape: const StadiumBorder()), onPressed: onRetry, child: Text(button ?? tr('Try again'))),
      ]),
    );
  }
}

/// Grey placeholder blocks that shimmer while a page loads.
class _Skeleton extends StatefulWidget {
  const _Skeleton();
  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.all(18),
        child: AnimatedBuilder(
          animation: _a,
          builder: (_, __) {
            final g = LinearGradient(begin: Alignment(-1 + 2 * _a.value - .5, 0), end: Alignment(-1 + 2 * _a.value + .5, 0), colors: const [Color(0xFFEDF0F5), Color(0xFFF8FAFC), Color(0xFFEDF0F5)]);
            Widget b(double h, [double w = double.infinity]) => Container(height: h, width: w, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(14)));
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [b(170), b(18, 220), b(14), b(14, 260), Row(children: [Expanded(child: b(120)), const SizedBox(width: 14), Expanded(child: b(120))]), b(14), b(14, 200)]);
          },
        ),
      );
}
