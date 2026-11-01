// Modern, animated app chrome: top header, bottom navigation and loaders, chosen live from the dashboard.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

const _ease = Curves.easeOutCubic;
const _dur = Duration(milliseconds: 320);

/// One bottom bar entry.
class BarItem {
  const BarItem(this.icon, this.label);
  final IconData icon;
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
  Widget _icon(IconData ic, Color c, bool on, {double size = 24}) => AnimatedScale(
        scale: on ? 1.12 : 1,
        duration: _dur,
        curve: Curves.easeOutBack,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: c),
          duration: _dur,
          builder: (_, col, __) => Icon(ic, color: col, size: size),
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
      // ---- Pill highlight: soft rounded box behind icon + label
      case 'pill':
        return _flat(_row((i, on) => AnimatedContainer(
              duration: _dur,
              curve: _ease,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: on ? active.withOpacity(.13) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _icon(items[i].icon, on ? active : idle, on),
                if (_showLabel(on)) Padding(padding: const EdgeInsets.only(top: 3), child: _label(items[i].label, on ? active : idle, on)),
              ]),
            )));

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

      // ---- Dot + label: a small dot appears above the selected icon
      case 'dot':
        return _flat(_row((i, on) => Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(duration: _dur, curve: _ease, width: on ? 6 : 0, height: 6, margin: const EdgeInsets.only(bottom: 4), decoration: BoxDecoration(color: active, shape: BoxShape.circle)),
              _icon(items[i].icon, on ? active : idle, on),
              if (_showLabel(on)) Padding(padding: const EdgeInsets.only(top: 3), child: _label(items[i].label, on ? active : idle, on)),
            ])));

      // ---- Underline: a bar slides under the selected icon
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
              AnimatedPositioned(duration: _dur, curve: _ease, left: w * selected + (w - 26) / 2, bottom: 5, width: 26, height: 3, child: DecoratedBox(decoration: BoxDecoration(color: active, borderRadius: BorderRadius.circular(3)))),
            ]);
          })),
        ]));

      // ---- Top line: a line slides along the top edge
      case 'topline':
        return _flat(Stack(children: [
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
                child: Icon(items[i].icon, color: on ? _onActive : idle, size: 24),
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
              child: Icon(items[i].icon, color: on ? const Color(0xFF0F172A) : Colors.white.withOpacity(.75), size: 23),
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
            Positioned.fill(child: _row((i, on) => Icon(items[i].icon, color: on ? _onActive : idle, size: 24))),
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
                child: Icon(items[i].icon, color: on ? active : idle, size: 24),
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
  });

  final String design;
  final Color bg, bg2, fg, statusBg, pageBg;
  final String title, subtitle;
  final bool center, hidden;
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
    final topColor = design == 'minimal' || design == 'floating' ? (design == 'minimal' ? pageBg : statusBg) : bg;
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
