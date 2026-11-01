// Modern, animated app chrome: top header, bottom navigation and loaders, chosen live from the dashboard.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icon library bundled with the app: {"io": {name: svg}, "md": {name: svg}} (Ionicons + Modern).
Map<String, dynamic> iconLibrary = {};
/// Built-in icon names (home, cart…) resolved by the app.
IconData Function(String name) builtinIcon = (_) => Icons.circle_outlined;

/// Any icon from the dashboard: "io:home-outline", "md:ad" or a built-in name like "home".
class AppIco extends StatelessWidget {
  const AppIco(this.name, {super.key, this.color, this.size});
  final String name;
  final Color? color;
  final double? size;
  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.black;
    final s = size ?? IconTheme.of(context).size ?? 24;
    final i = name.indexOf(':');
    if (i > 0) {
      final svg = (iconLibrary[name.substring(0, i)] as Map?)?[name.substring(i + 1)];
      // Center keeps the icon at its own size even inside a fixed-size box.
      if (svg is String) return Center(widthFactor: 1, heightFactor: 1, child: SvgPicture.string(svg, width: s, height: s, theme: SvgTheme(currentColor: c)));
    }
    return Icon(builtinIcon(name), color: c, size: s);
  }
}

const _ease = Curves.easeOutCubic;
const _dur = Duration(milliseconds: 320);

/// One bottom bar entry.
class BarItem {
  const BarItem(this.icon, this.label);
  final String icon;
  final String label;
}

/// Bottom navigation in many designs. Every design animates the selection.
class LFBottomBar extends StatelessWidget {
  const LFBottomBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onTap,
    required this.design,
    required this.bg,
    required this.active,
    required this.labels,
  });

  final List<BarItem> items;
  final int selected;
  final ValueChanged<int> onTap;
  final String design;
  final Color bg;
  final Color active;
  /// labels | selected | icons
  final String labels;

  /// Designs that float above the page (the page scrolls behind them).
  static const floating = {'floating', 'glass', 'expand', 'island', 'dock'};

  Color get _idle => bg.computeLuminance() > .5 ? const Color(0xFF94A3B8) : Colors.white.withOpacity(.55);
  Color get _onActive => active.computeLuminance() > .55 ? const Color(0xFF0F172A) : Colors.white;
  bool _showLabel(bool on) => labels == 'icons' ? false : (labels == 'selected' ? on : true);

  Widget _label(String t, Color c, bool on, {double size = 11}) => AnimatedDefaultTextStyle(
        duration: _dur,
        curve: _ease,
        style: TextStyle(color: c, fontSize: size, fontWeight: on ? FontWeight.w700 : FontWeight.w500, height: 1.2),
        child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis),
      );

  Widget _tap(int i, Widget child) => Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(i),
          child: Center(child: child),
        ),
      );

  /// Icon that pops slightly when it becomes selected.
  Widget _icon(String ic, Color c, bool on, {double size = 24}) => AnimatedScale(
        scale: on ? 1.12 : 1,
        duration: _dur,
        curve: Curves.easeOutBack,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: c),
          duration: _dur,
          builder: (_, col, __) => AppIco(ic, color: col, size: size),
        ),
      );

  /// Items keep their natural width (for designs whose selected item grows).
  Widget _spread(Widget Function(int i, bool on) build) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          for (var i = 0; i < items.length; i++) GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onTap(i), child: build(i, i == selected)),
        ]),
      );

  Widget _row(Widget Function(int i, bool on) build) => Row(children: [for (var i = 0; i < items.length; i++) _tap(i, build(i, i == selected))]);

  @override
  Widget build(BuildContext context) {
    final idle = _idle;
    switch (design) {
      // ---- Pill highlight: the selected item becomes a solid coloured tile (icon + label inside)
      case 'pill':
        return _flat(_row((i, on) => AnimatedContainer(
              duration: _dur,
              curve: _ease,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: on ? active : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                boxShadow: on ? [BoxShadow(color: active.withOpacity(.4), blurRadius: 12, offset: const Offset(0, 5))] : const [],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _icon(items[i].icon, on ? _onActive : idle, false),
                if (_showLabel(on)) Padding(padding: const EdgeInsets.only(top: 3), child: _label(items[i].label, on ? _onActive : idle, on)),
              ]),
            )), height: 70);

      // ---- Expanding label: selected item becomes a filled pill with its name
      case 'expand':
        return _float(_spread((i, on) => AnimatedContainer(
              duration: _dur,
              curve: _ease,
              padding: EdgeInsets.symmetric(horizontal: on ? 16 : 8, vertical: 10),
              decoration: BoxDecoration(color: on ? active : Colors.transparent, borderRadius: BorderRadius.circular(30)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _icon(items[i].icon, on ? _onActive : idle, false, size: 22),
                AnimatedSize(
                  duration: _dur,
                  curve: _ease,
                  child: on && labels != 'icons'
                      ? Padding(padding: const EdgeInsets.only(left: 8), child: _label(items[i].label, _onActive, true, size: 13))
                      : const SizedBox.shrink(),
                ),
              ]),
            )), radius: 34, height: 68);

      // ---- Bubble: light tinted pill that grows to show the label
      case 'bubble':
        return _flat(_spread((i, on) => AnimatedContainer(
              duration: _dur,
              curve: _ease,
              padding: EdgeInsets.symmetric(horizontal: on ? 14 : 8, vertical: 9),
              decoration: BoxDecoration(color: on ? active.withOpacity(.14) : Colors.transparent, borderRadius: BorderRadius.circular(30)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _icon(items[i].icon, on ? active : idle, false, size: 22),
                AnimatedSize(
                  duration: _dur,
                  curve: _ease,
                  child: on && labels != 'icons' ? Padding(padding: const EdgeInsets.only(left: 6), child: _label(items[i].label, active, true, size: 13)) : const SizedBox.shrink(),
                ),
              ]),
            )));

      // ---- Dot + label: icons only; the selected one shows its name and a dot above
      case 'dot':
        return _flat(_row((i, on) => Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(duration: _dur, curve: _ease, width: on ? 7 : 0, height: 7, margin: const EdgeInsets.only(bottom: 5), decoration: BoxDecoration(color: active, shape: BoxShape.circle)),
              _icon(items[i].icon, on ? active : idle, on, size: 25),
              AnimatedSize(duration: _dur, curve: _ease, child: on && labels != 'icons' ? Padding(padding: const EdgeInsets.only(top: 3), child: _label(items[i].label, active, true)) : const SizedBox(height: 0)),
            ])));

      // ---- Underline: icons + labels, a thick bar slides under the selected label
      case 'underline':
        return _flat(Stack(children: [
          Positioned.fill(child: _row((i, on) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _icon(items[i].icon, on ? active : idle, on),
                  if (_showLabel(on)) Padding(padding: const EdgeInsets.only(top: 3), child: _label(items[i].label, on ? active : idle, on)),
                ]),
              ))),
          Positioned.fill(child: LayoutBuilder(builder: (_, box) {
            final w = box.maxWidth / items.length;
            return Stack(children: [
              AnimatedPositioned(duration: _dur, curve: _ease, left: w * selected + w * .2, bottom: 4, width: w * .6, height: 4, child: DecoratedBox(decoration: BoxDecoration(color: active, borderRadius: BorderRadius.circular(4)))),
            ]);
          })),
        ]));

      // ---- Top glow: a line on the top edge with a soft coloured glow under it
      case 'topline':
        return _flat(Stack(children: [
          Positioned.fill(child: LayoutBuilder(builder: (_, box) {
            final w = box.maxWidth / items.length;
            return Stack(children: [
              AnimatedPositioned(duration: _dur, curve: _ease, left: w * selected, top: 0, width: w, bottom: 0,
                  child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [active.withOpacity(.22), active.withOpacity(0)])))),
            ]);
          })),
          Positioned.fill(child: _row((i, on) => Column(mainAxisSize: MainAxisSize.min, children: [
                _icon(items[i].icon, on ? active : idle, on),
                if (_showLabel(on)) Padding(padding: const EdgeInsets.only(top: 3), child: _label(items[i].label, on ? active : idle, on)),
              ]))),
          Positioned.fill(child: LayoutBuilder(builder: (_, box) {
            final w = box.maxWidth / items.length;
            return Stack(children: [
              AnimatedPositioned(duration: _dur, curve: _ease, left: w * selected + 10, top: 0, width: w - 20, height: 3, child: DecoratedBox(decoration: BoxDecoration(color: active, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3))))),
            ]);
          })),
        ]));

      // ---- Float up: the selected icon rises into a coloured rounded square
      case 'floatup':
        return _flat(_row((i, on) => Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: _dur,
                curve: Curves.easeOutBack,
                transform: Matrix4.translationValues(0, on ? -14 : 0, 0),
                width: on ? 48 : 40,
                height: on ? 48 : 40,
                decoration: BoxDecoration(
                  color: on ? active : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: on ? [BoxShadow(color: active.withOpacity(.45), blurRadius: 16, offset: const Offset(0, 8))] : const [],
                ),
                child: AppIco(items[i].icon, color: on ? _onActive : idle, size: 24),
              ),
              if (labels != 'icons') Transform.translate(offset: Offset(0, on ? -8 : 0), child: _label(items[i].label, on ? active : idle, on)),
            ])), height: 74);

      // ---- Island: dark floating bar, selected icon in a white circle
      case 'island':
        return _float(_row((i, on) => AnimatedContainer(
              duration: _dur,
              curve: Curves.easeOutBack,
              width: on ? 50 : 44,
              height: on ? 50 : 44,
              decoration: BoxDecoration(color: on ? Colors.white : Colors.transparent, shape: BoxShape.circle),
              child: AppIco(items[i].icon, color: on ? const Color(0xFF0F172A) : Colors.white.withOpacity(.75), size: 23),
            )), color: const Color(0xFF111418), radius: 36, height: 70);

      // ---- Dock: floating bar with a raised bubble that slides to the selected item
      case 'dock':
        return _float(LayoutBuilder(builder: (_, box) {
          final w = box.maxWidth / items.length;
          return Stack(clipBehavior: Clip.none, children: [
            AnimatedPositioned(
              duration: _dur,
              curve: _ease,
              left: w * selected + (w - 52) / 2,
              top: 7,
              width: 52,
              height: 52,
              child: DecoratedBox(decoration: BoxDecoration(color: active, shape: BoxShape.circle, boxShadow: [BoxShadow(color: active.withOpacity(.45), blurRadius: 14, offset: const Offset(0, 6))])),
            ),
            Positioned.fill(child: _row((i, on) => AppIco(items[i].icon, color: on ? _onActive : idle, size: 24))),
          ]);
        }), radius: 34, height: 66);

      // ---- Floating / glass: rounded bar that floats above the page
      case 'floating':
      case 'glass':
        return _float(_row((i, on) => Column(mainAxisSize: MainAxisSize.min, children: [
              _icon(items[i].icon, on ? active : idle, on),
              if (_showLabel(on)) Padding(padding: const EdgeInsets.only(top: 3), child: _label(items[i].label, on ? active : idle, on)),
            ])), glass: design == 'glass');

      // ---- Minimal: icons only, a dot under the selected one
      case 'minimal':
        return _flat(_row((i, on) => Column(mainAxisSize: MainAxisSize.min, children: [
              _icon(items[i].icon, on ? active : idle, on),
              AnimatedContainer(duration: _dur, curve: _ease, margin: const EdgeInsets.only(top: 5), width: on ? 18 : 0, height: 4, decoration: BoxDecoration(color: active, borderRadius: BorderRadius.circular(4))),
            ])), border: false);

      // ---- Classic (Material 3)
      default:
        return _flat(_row((i, on) => Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: _dur,
                curve: _ease,
                padding: EdgeInsets.symmetric(horizontal: on ? 18 : 12, vertical: 4),
                decoration: BoxDecoration(color: on ? active.withOpacity(.15) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                child: AppIco(items[i].icon, color: on ? active : idle, size: 24),
              ),
              if (_showLabel(on)) Padding(padding: const EdgeInsets.only(top: 4), child: _label(items[i].label, on ? active : idle, on, size: 12)),
            ])));
    }
  }

  /// Full-width bar attached to the bottom edge.
  Widget _flat(Widget child, {double height = 66, bool border = true}) => Container(
        decoration: BoxDecoration(
          color: bg,
          border: border ? Border(top: BorderSide(color: (bg.computeLuminance() > .5 ? Colors.black : Colors.white).withOpacity(.06))) : null,
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, -4))],
        ),
        child: SafeArea(top: false, child: SizedBox(height: height, child: child)),
      );

  /// Rounded bar floating above the page.
  Widget _float(Widget child, {bool glass = false, Color? color, double radius = 28, double height = 66}) {
    final fill = color ?? bg;
    final inner = Container(
      height: height,
      decoration: BoxDecoration(
        color: glass ? fill.withOpacity(.6) : fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: glass ? Colors.white.withOpacity(.7) : Colors.black.withOpacity(.05)),
      ),
      child: child,
    );
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 28, offset: Offset(0, 12))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: glass ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: inner) : inner,
        ),
      ),
    );
  }
}

/// The app's top header in several designs, with an optional hide-on-scroll animation.
class LFHeader extends StatelessWidget {
  const LFHeader({
    super.key,
    required this.design,
    required this.bg,
    required this.bg2,
    required this.fg,
    required this.statusBg,
    required this.pageBg,
    required this.title,
    this.subtitle = '',
    this.center = false,
    this.leading,
    this.logo,
    this.actions = const [],
    this.bottom,
    this.hidden = false,
    this.statusCustom = false,
    this.onSearch,
    this.searchHint = 'Search',
  });

  /// Called with the text from the search bar (Search header design).
  final ValueChanged<String>? onSearch;
  final String searchHint;

  final String design;
  final Color bg, bg2, fg, statusBg, pageBg;
  final String title, subtitle;
  final bool center, hidden, statusCustom;
  final Widget? leading, logo, bottom;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final minimal = design == 'minimal';
    final ink = minimal ? (pageBg.computeLuminance() > .5 ? const Color(0xFF0F172A) : Colors.white) : fg;
    final grad = LinearGradient(colors: [bg, bg2], begin: Alignment.topLeft, end: Alignment.bottomRight);

    Widget bar({double height = 58, bool large = false}) => IconTheme(
          data: IconThemeData(color: minimal ? bg : ink),
          child: DefaultTextStyle(
            style: TextStyle(color: ink, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.2),
            child: SizedBox(
              height: height,
              child: Row(children: [
                if (leading != null) leading! else const SizedBox(width: 16),
                if (!center && !large && logo != null) Padding(padding: const EdgeInsets.only(right: 10), child: logo),
                Expanded(
                  child: large
                      ? const SizedBox()
                      : Row(mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                          if (center && logo != null) Padding(padding: const EdgeInsets.only(right: 8), child: logo),
                          Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                ),
                ...actions,
                const SizedBox(width: 4),
              ]),
            ),
          ),
        );

    Widget body;
    switch (design) {
      case 'floating':
        body = Container(
          color: statusBg,
          padding: EdgeInsets.only(top: top),
          child: Container(
            color: pageBg,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Container(
              decoration: BoxDecoration(gradient: grad, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: bg.withOpacity(.35), blurRadius: 20, offset: const Offset(0, 8))]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [bar(), if (bottom != null) bottom!]),
            ),
          ),
        );
      case 'glass':
        body = ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [bg.withOpacity(.82), bg2.withOpacity(.72)]),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(.25))),
              ),
              padding: EdgeInsets.only(top: top),
              child: Column(mainAxisSize: MainAxisSize.min, children: [bar(), if (bottom != null) bottom!]),
            ),
          ),
        );
      case 'curved':
        body = Container(
          decoration: BoxDecoration(
            gradient: grad,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
            boxShadow: [BoxShadow(color: bg.withOpacity(.35), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          padding: EdgeInsets.only(top: top, bottom: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [bar(), if (bottom != null) bottom!]),
        );
      case 'large':
        body = Container(
          decoration: BoxDecoration(gradient: grad, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))),
          padding: EdgeInsets.only(top: top, bottom: 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            bar(height: 52, large: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Row(children: [
                if (logo != null) Padding(padding: const EdgeInsets.only(right: 12), child: SizedBox(width: 40, height: 40, child: FittedBox(child: logo))),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(color: fg.withOpacity(.8), fontSize: 13, fontWeight: FontWeight.w500)),
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.6)),
                  ]),
                ),
              ]),
            ),
            if (bottom != null) Padding(padding: const EdgeInsets.only(top: 10), child: bottom!),
          ]),
        );
      case 'search':
      case 'greeting':
        // Title row with round buttons, then (search) a rounded search field.
        final light = pageBg.computeLuminance() > .5;
        final txt = light ? const Color(0xFF0F172A) : Colors.white;
        Widget roundBtn(Widget w) => Container(
              margin: const EdgeInsets.only(left: 8),
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: light ? Colors.white : Colors.white.withOpacity(.1), shape: BoxShape.circle, boxShadow: light ? const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))] : null),
              child: IconTheme(data: IconThemeData(color: txt, size: 21), child: Center(child: w)),
            );
        body = Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(pageBg, bg, .14)!, pageBg]),
          ),
          padding: EdgeInsets.fromLTRB(18, top + 10, 14, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (leading != null && design == 'search') roundBtn(leading!),
              if (design == 'greeting' && logo != null) Padding(padding: const EdgeInsets.only(right: 12), child: ClipOval(child: SizedBox(width: 46, height: 46, child: FittedBox(fit: BoxFit.cover, child: logo)))),
              if (design == 'search') const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(color: txt.withOpacity(.55), fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: txt, fontSize: design == 'greeting' ? 24 : 20, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                ]),
              ),
              for (final a in actions) roundBtn(a),
              if (leading != null && design == 'greeting') roundBtn(leading!),
            ]),
            if (design == 'search') ...[
              const SizedBox(height: 12),
              _SearchField(hint: searchHint, ink: txt, light: light, onSubmit: onSearch),
            ],
            if (bottom != null) bottom!,
          ]),
        );
      case 'rings':
        // Outline ring buttons on both sides, centred title.
        Widget ring(Widget w) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: fg.withOpacity(.35), width: 1.5)),
              child: IconTheme(data: IconThemeData(color: fg, size: 20), child: Center(child: w)),
            );
        body = Container(
          decoration: BoxDecoration(gradient: grad, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26))),
          padding: EdgeInsets.fromLTRB(10, top + 10, 10, 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              if (leading != null) ring(leading!) else const SizedBox(width: 52),
              Expanded(child: Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.4))),
              if (actions.isNotEmpty) ring(actions.first) else const SizedBox(width: 52),
            ]),
            if (bottom != null) bottom!,
          ]),
        );
      case 'pill':
        // Compact white pill floating on the page.
        body = Container(
          color: statusBg,
          padding: EdgeInsets.only(top: top),
          child: Container(
            color: pageBg,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Container(
              height: 56,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))]),
              child: IconTheme(
                data: IconThemeData(color: bg, size: 22),
                child: Row(children: [
                  if (leading != null) leading! else const SizedBox(width: 14),
                  if (logo != null) Padding(padding: const EdgeInsets.only(right: 8), child: logo),
                  Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.w700))),
                  ...actions,
                  const SizedBox(width: 4),
                ]),
              ),
            ),
          ),
        );
      case 'island':
        body = Container(
          color: statusBg,
          padding: EdgeInsets.only(top: top),
          child: Container(
            color: pageBg,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(40), boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 22, offset: Offset(0, 10))]),
              child: IconTheme(data: const IconThemeData(color: Colors.white), child: DefaultTextStyle(style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800), child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(height: 54, child: Row(children: [
                  if (leading != null) leading! else const SizedBox(width: 18),
                  if (logo != null) Padding(padding: const EdgeInsets.only(right: 10), child: logo),
                  Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ...actions,
                  const SizedBox(width: 6),
                ])),
                if (bottom != null) bottom!,
              ]))),
            ),
          ),
        );
      case 'transparent':
        // No bar: round frosted buttons float over the page.
        Widget round(Widget w) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(color: Colors.white.withOpacity(.9), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x30000000), blurRadius: 12, offset: Offset(0, 4))]),
              child: IconTheme(data: IconThemeData(color: bg), child: w),
            );
        body = Container(
          color: statusBg,
          padding: EdgeInsets.only(top: top),
          child: Container(
            color: pageBg,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(children: [
              if (leading != null) round(leading!),
              const Spacer(),
              for (final a in actions) round(a),
            ]),
          ),
        );
      case 'bold':
        body = Container(
          decoration: BoxDecoration(color: pageBg, border: Border(bottom: BorderSide(color: ink.withOpacity(.06)))),
          padding: EdgeInsets.only(top: top),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: 64,
              child: Row(children: [
                const SizedBox(width: 16),
                if (logo != null) Padding(padding: const EdgeInsets.only(right: 12), child: logo),
                Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: pageBg.computeLuminance() > .5 ? const Color(0xFF0F172A) : Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.8))),
                for (final a in [if (leading != null) leading!, ...actions])
                  Container(margin: const EdgeInsets.only(left: 6), decoration: BoxDecoration(color: bg.withOpacity(.12), borderRadius: BorderRadius.circular(14)), child: IconTheme(data: IconThemeData(color: bg), child: a)),
                const SizedBox(width: 12),
              ]),
            ),
            if (bottom != null) bottom!,
          ]),
        );
      case 'minimal':
        body = Container(
          decoration: BoxDecoration(color: pageBg, border: Border(bottom: BorderSide(color: ink.withOpacity(.08)))),
          padding: EdgeInsets.only(top: top),
          child: Column(mainAxisSize: MainAxisSize.min, children: [bar(), if (bottom != null) bottom!]),
        );
      default:
        body = Container(
          decoration: BoxDecoration(gradient: grad, boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 2))]),
          padding: EdgeInsets.only(top: top),
          child: Column(mainAxisSize: MainAxisSize.min, children: [bar(), if (bottom != null) bottom!]),
        );
    }
    // Status bar icons follow the header colour (dark icons on light headers).
    final topColor = statusCustom ? statusBg : ({'minimal': pageBg, 'bold': pageBg, 'search': pageBg, 'greeting': pageBg, 'floating': statusBg, 'island': statusBg, 'transparent': statusBg, 'pill': statusBg}[design] ?? bg);
    final darkIcons = topColor.computeLuminance() > .6;
    // Hide on scroll: the header slides up and collapses; the status bar area stays coloured.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: darkIcons ? Brightness.dark : Brightness.light, statusBarBrightness: darkIcons ? Brightness.light : Brightness.dark),
      child: Stack(children: [
      TweenAnimationBuilder<double>(
        tween: Tween(end: hidden ? 0 : 1),
        duration: const Duration(milliseconds: 260),
        curve: _ease,
        builder: (_, v, child) => ClipRect(child: Align(alignment: Alignment.bottomCenter, heightFactor: v, child: Opacity(opacity: v.clamp(0, 1), child: child))),
        child: body,
      ),
      if (hidden) Container(height: top, color: design == 'minimal' ? pageBg : statusBg),
      // A custom status bar colour (Theme & display) always paints the status area.
      if (statusCustom) Container(height: top, color: statusBg),
    ]));
  }
}

/// Animated page loaders (from the dashboard's "Loading indicator" list).
Widget? lfLoader(String style, Color c) {
  switch (style) {
    case 'spinner':
      return CircularProgressIndicator(color: c);
    case 'wave':
      return SpinKitWave(color: c, size: 42);
    case 'pulse':
      return SpinKitPulse(color: c, size: 56);
    case 'ring':
      return SpinKitRing(color: c, size: 44, lineWidth: 4);
    case 'three_bounce':
      return SpinKitThreeBounce(color: c, size: 26);
    case 'double_bounce':
      return SpinKitDoubleBounce(color: c, size: 48);
    case 'rotating_plane':
      return SpinKitRotatingPlain(color: c, size: 40);
    case 'wandering_cubes':
      return SpinKitWanderingCubes(color: c, size: 42);
    case 'chasing_dots':
      return SpinKitChasingDots(color: c, size: 44);
    case 'fading_four':
      return SpinKitFadingFour(color: c, size: 44);
    case 'circle':
      return SpinKitCircle(color: c, size: 48);
    case 'fading_circle':
      return SpinKitFadingCircle(color: c, size: 48);
    case 'folding_cube':
      return SpinKitFoldingCube(color: c, size: 38);
    case 'rotating_circle':
      return SpinKitRotatingCircle(color: c, size: 40);
    case 'cube_grid':
      return SpinKitCubeGrid(color: c, size: 40);
    case 'ripple':
      return SpinKitRipple(color: c, size: 64);
  }
  return null;
}

/// Staggered slide-in for side menu items.
class SlideIn extends StatelessWidget {
  const SlideIn({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 300 + index * 45),
        curve: _ease,
        builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(-24 * (1 - v), 0), child: c)),
        child: child,
      );
}

/* ===================== v24: splash, floating button, drawer headers, logo ===================== */

/// The app icon: bundled with the build (instant), falling back to the network copy.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, required this.url, this.size = 40, this.radius = 12});
  final String url;
  final double size, radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset('assets/icon.png', width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => url.isEmpty ? SizedBox(width: size, height: size) : Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => SizedBox(width: size, height: size))),
      );
}

/// Splash screen designs: classic, card, glow, minimal, bold, split. All animate in.
class LFSplash extends StatelessWidget {
  const LFSplash({super.key, required this.design, required this.c1, required this.c2, required this.titleColor, required this.title, required this.tagline,
      required this.logoUrl, required this.showLogo, required this.showTitle, this.image = ''});
  final String design, title, tagline, logoUrl, image;
  final Color c1, c2, titleColor;
  final bool showLogo, showTitle;

  Widget _pop(Widget child, {int delay = 0}) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 650 + delay),
        curve: Curves.easeOutBack,
        builder: (_, v, ch) => Opacity(opacity: v.clamp(0, 1), child: Transform.scale(scale: .7 + .3 * v, child: ch)),
        child: child,
      );

  Widget _rise(Widget child, {int delay = 0}) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 700 + delay),
        curve: Curves.easeOutCubic,
        builder: (_, v, ch) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: ch)),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final grad = BoxDecoration(
      gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
      image: image.isNotEmpty ? DecorationImage(image: NetworkImage(image), fit: BoxFit.cover) : null,
    );
    final titleW = Text(title, textAlign: TextAlign.center, style: TextStyle(color: titleColor, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.4));
    final tagW = Text(tagline, textAlign: TextAlign.center, style: TextStyle(color: titleColor.withOpacity(.75), fontSize: 15));
    switch (design) {
      case 'card':
        return Container(
          decoration: grad,
          alignment: Alignment.center,
          child: _pop(Container(
            width: 250,
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 20))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (showLogo) AppLogo(url: logoUrl, size: 84, radius: 22),
              if (showTitle) ...[const SizedBox(height: 16), Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.w800))],
              if (tagline.isNotEmpty) ...[const SizedBox(height: 4), Text(tagline, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B)))],
            ]),
          )),
        );
      case 'glow':
        return Container(
          decoration: grad,
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (showLogo)
              _Glow(color: titleColor.computeLuminance() > .5 ? Colors.white : c1, child: _pop(AppLogo(url: logoUrl, size: 104, radius: 30))),
            if (showTitle) ...[const SizedBox(height: 26), _rise(titleW, delay: 150)],
            if (tagline.isNotEmpty) ...[const SizedBox(height: 6), _rise(tagW, delay: 250)],
          ]),
        );
      case 'minimal':
        return Container(
          width: double.infinity,
          color: c1,
          child: SafeArea(
            child: Column(children: [
              const Spacer(),
              if (showLogo) _pop(AppLogo(url: logoUrl, size: 72, radius: 20)),
              const Spacer(),
              if (showTitle) _rise(Text(title, style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: .3))),
              if (tagline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(tagline, style: TextStyle(color: titleColor.withOpacity(.6), fontSize: 12))),
              const SizedBox(height: 18),
              SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 3, borderRadius: BorderRadius.circular(3), color: titleColor, backgroundColor: titleColor.withOpacity(.15))),
              const SizedBox(height: 40),
            ]),
          ),
        );
      case 'bold':
        return Container(
          width: double.infinity,
          decoration: grad,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 30),
                if (showLogo) _pop(AppLogo(url: logoUrl, size: 76, radius: 22)),
                const Spacer(),
                if (showTitle) _rise(Text(title, style: TextStyle(color: titleColor, fontSize: 44, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -1.2))),
                if (tagline.isNotEmpty) ...[const SizedBox(height: 10), _rise(Text(tagline, style: TextStyle(color: titleColor.withOpacity(.8), fontSize: 17)), delay: 150)],
                const SizedBox(height: 30),
              ]),
            ),
          ),
        );
      case 'split':
        return Column(children: [
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: grad.copyWith(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(48))),
              alignment: Alignment.center,
              child: showLogo ? _pop(AppLogo(url: logoUrl, size: 110, radius: 32)) : null,
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              alignment: Alignment.center,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (showTitle) _rise(Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 26, fontWeight: FontWeight.w800))),
                if (tagline.isNotEmpty) ...[const SizedBox(height: 6), _rise(Text(tagline, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))), delay: 120)],
              ]),
            ),
          ),
        ]);
      default:
        return Container(
          decoration: grad,
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (showLogo) _pop(AppLogo(url: logoUrl, size: 96, radius: 26)),
            if (showTitle) ...[const SizedBox(height: 18), _rise(titleW, delay: 120)],
            if (tagline.isNotEmpty) ...[const SizedBox(height: 6), _rise(tagW, delay: 200)],
          ]),
        );
    }
  }
}

/// Soft pulsing glow behind a widget.
class _Glow extends StatefulWidget {
  const _Glow({required this.child, required this.color});
  final Widget child;
  final Color color;
  @override
  State<_Glow> createState() => _GlowState();
}

class _GlowState extends State<_Glow> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (_, child) => Stack(alignment: Alignment.center, children: [
          for (final d in [0.0, .5])
            Builder(builder: (_) {
              final t = (_a.value + d) % 1;
              return Container(width: 110 + 90 * t, height: 110 + 90 * t, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(.28 * (1 - t))));
            }),
          child!,
        ]),
        child: widget.child,
      );
}

/// Floating action button designs: circle, square, pill, glow, outline, mini.
class LFFab extends StatelessWidget {
  const LFFab({super.key, required this.design, required this.color, required this.icon, required this.label, required this.onTap});
  final String design, label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = color.computeLuminance() > .6 ? const Color(0xFF0F172A) : Colors.white;
    final shadow = [BoxShadow(color: color.withOpacity(.45), blurRadius: 18, offset: const Offset(0, 8))];
    Widget body;
    switch (design) {
      case 'square':
        body = Container(width: 58, height: 58, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), boxShadow: shadow), child: Icon(icon, color: on, size: 26));
      case 'pill':
        body = Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30), boxShadow: shadow),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: on, size: 22), const SizedBox(width: 8), Text(label, style: TextStyle(color: on, fontWeight: FontWeight.w700, fontSize: 15))]),
        );
      case 'glow':
        body = SizedBox(width: 84, height: 84, child: _Glow(color: color, child: Container(width: 58, height: 58, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: on, size: 26))));
      case 'outline':
        body = Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: color, width: 2.5), boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 16, offset: Offset(0, 6))]),
          child: Icon(icon, color: color, size: 26),
        );
      case 'mini':
        body = Container(width: 44, height: 44, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: shadow), child: Icon(icon, color: on, size: 20));
      default:
        body = Container(width: 58, height: 58, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: shadow), child: Icon(icon, color: on, size: 26));
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutBack,
      builder: (_, v, ch) => Transform.scale(scale: v, child: ch),
      child: GestureDetector(onTap: onTap, child: body),
    );
  }
}

/// Side menu header designs: card, cover, profile, compact, banner.
class LFDrawerHeader extends StatelessWidget {
  const LFDrawerHeader({super.key, required this.design, required this.color, required this.title, required this.subtitle, required this.logoUrl, required this.dark, this.image = ''});
  final String design, title, subtitle, logoUrl, image;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final c2 = Color.lerp(color, Colors.black, .35)!;
    final img = image.isNotEmpty ? DecorationImage(image: NetworkImage(image), fit: BoxFit.cover, colorFilter: const ColorFilter.mode(Colors.black38, BlendMode.darken)) : null;
    final ink = dark ? Colors.white : const Color(0xFF0F172A);
    switch (design) {
      case 'cover':
        return SizedBox(
          height: top + 180,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(height: top + 130, decoration: BoxDecoration(gradient: LinearGradient(colors: [color, c2], begin: Alignment.topLeft, end: Alignment.bottomRight), image: img)),
            Positioned(
              left: 20,
              top: top + 92,
              child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: dark ? const Color(0xFF0F172A) : Colors.white, borderRadius: BorderRadius.circular(22)), child: AppLogo(url: logoUrl, size: 68, radius: 18)),
            ),
            Positioned(
              left: 104,
              right: 16,
              top: top + 138,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w800)),
                if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink.withOpacity(.6), fontSize: 13)),
              ]),
            ),
          ]),
        );
      case 'profile':
        return Container(
          padding: EdgeInsets.fromLTRB(20, top + 28, 20, 22),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: ink.withOpacity(.08)))),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [color, c2, color.withOpacity(.4), color])),
              child: Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, color: dark ? const Color(0xFF0F172A) : Colors.white), child: ClipOval(child: AppLogo(url: logoUrl, size: 74, radius: 0))),
            ),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: TextStyle(color: ink, fontSize: 19, fontWeight: FontWeight.w800)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(20)), child: Text(subtitle, style: TextStyle(color: dark ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.w600))),
            ],
          ]),
        );
      case 'circles':
        // Soft concentric circles behind the logo (light or dark).
        return SizedBox(
          height: top + 150,
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            for (final r in [260.0, 190.0, 125.0])
              Positioned(left: -r / 2 + 40, top: top - r / 2 + 50, child: Container(width: r, height: r, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(dark ? .16 : .10)))),
            Positioned(
              left: 18,
              right: 12,
              top: top + 34,
              child: Row(children: [
                ClipOval(child: AppLogo(url: logoUrl, size: 70, radius: 0)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? Colors.white : color, fontSize: 21, fontWeight: FontWeight.w800)),
                  if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(color: ink.withOpacity(.6), fontSize: 13)),
                ])),
              ]),
            ),
          ]),
        );
      case 'close':
        // Clean row with a close button and a divider under it.
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 18),
          padding: EdgeInsets.only(top: top + 18, bottom: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: ink.withOpacity(.1)))),
          child: Row(children: [
            ClipOval(child: AppLogo(url: logoUrl, size: 48, radius: 0)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w700)),
              if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink.withOpacity(.5), fontSize: 13)),
            ])),
            Builder(builder: (ctx) => InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(ctx).maybePop(),
                  child: Container(width: 38, height: 38, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ink.withOpacity(.12))), child: Icon(Icons.close_rounded, size: 18, color: ink)),
                )),
          ]),
        );
      case 'center':
        // Small brand mark on top, logo + name centred, divider.
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 18),
          padding: EdgeInsets.only(top: top + 16, bottom: 18),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: ink.withOpacity(.1)))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(gradient: LinearGradient(colors: [color, c2]), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20)),
            const SizedBox(height: 18),
            Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)), child: ClipOval(child: AppLogo(url: logoUrl, size: 58, radius: 0))),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)),
            if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(color: ink.withOpacity(.55), fontSize: 13)),
          ]),
        );
      case 'compact':
        return Padding(
          padding: EdgeInsets.fromLTRB(20, top + 22, 16, 14),
          child: Row(children: [
            AppLogo(url: logoUrl, size: 40, radius: 12),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)),
              if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink.withOpacity(.55), fontSize: 12.5)),
            ])),
          ]),
        );
      case 'banner':
        return ClipPath(
          clipper: _WaveClip(),
          child: Container(
            padding: EdgeInsets.fromLTRB(22, top + 26, 22, 46),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [color, c2], begin: Alignment.topLeft, end: Alignment.bottomRight), image: img),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(right: -40, top: -50, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.10)))),
              Positioned(right: 40, top: 40, child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.08)))),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: Colors.white.withOpacity(.25), borderRadius: BorderRadius.circular(20)), child: AppLogo(url: logoUrl, size: 60, radius: 17)),
                const SizedBox(height: 14),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(.8))),
              ]),
            ]),
          ),
        );
      default: // card
        return Container(
          margin: EdgeInsets.fromLTRB(12, top + 12, 12, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [color, c2], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(22), image: img,
              boxShadow: [BoxShadow(color: color.withOpacity(.35), blurRadius: 18, offset: const Offset(0, 8))]),
          child: Row(children: [
            AppLogo(url: logoUrl, size: 50, radius: 14),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(.8), fontSize: 12.5)),
            ])),
          ]),
        );
    }
  }
}

class _WaveClip extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(0, s.height - 26)
    ..quadraticBezierTo(s.width * .25, s.height, s.width * .5, s.height - 18)
    ..quadraticBezierTo(s.width * .78, s.height - 38, s.width, s.height - 14)
    ..lineTo(s.width, 0)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}


/// Rounded search field used by the Search header; submits to the website's search page.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.hint, required this.ink, required this.light, this.onSubmit});
  final String hint;
  final Color ink;
  final bool light;
  final ValueChanged<String>? onSubmit;
  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: widget.light ? Colors.white : Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(26),
          boxShadow: widget.light ? const [BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 5))] : null,
        ),
        child: Row(children: [
          Icon(Icons.search_rounded, color: widget.ink.withOpacity(.55)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _c,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: widget.ink, fontSize: 15.5),
              decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: widget.hint, hintStyle: TextStyle(color: widget.ink.withOpacity(.45))),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) widget.onSubmit?.call(v.trim());
                FocusScope.of(context).unfocus();
              },
            ),
          ),
        ]),
      );
}
