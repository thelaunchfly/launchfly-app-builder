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
  static const floating = {'floating', 'glass', 'expand', 'island', 'dock', 'blobs', 'neumorph', 'detached', 'segments', 'gradient'};

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

      // ======== v26: ten more bottom bars ========
      // ---- Blobs: dark floating bar, every item in its own circle, selected one white
      case 'blobs':
        return _float(_row((i, on) => AnimatedContainer(
              duration: _dur,
              curve: Curves.easeOutBack,
              width: on ? 52 : 46,
              height: on ? 52 : 46,
              decoration: BoxDecoration(color: on ? Colors.white : const Color(0xFF2E3446), shape: BoxShape.circle),
              child: AppIco(items[i].icon, color: on ? const Color(0xFF111827) : Colors.white.withOpacity(.8), size: 22),
            )), color: const Color(0xFF1C2130), radius: 36, height: 68);

      // ---- Soft (neumorphic): light bar, selected item raised in a white bubble
      case 'neumorph':
        return _float(_row((i, on) => AnimatedContainer(
              duration: _dur,
              curve: _ease,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: on ? Colors.white : Colors.transparent,
                shape: BoxShape.circle,
                boxShadow: on ? const [BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(4, 6)), BoxShadow(color: Colors.white, blurRadius: 10, offset: Offset(-4, -4))] : const [],
              ),
              child: AppIco(items[i].icon, color: on ? active : const Color(0xFF64748B), size: 23),
            )), color: const Color(0xFFEEF1F6), radius: 34, height: 70);

      // ---- Arc: selected icon in a soft circle with a coloured arc over it
      case 'arc':
        return _flat(_row((i, on) => SizedBox(
              width: 54,
              height: 54,
              child: Stack(alignment: Alignment.center, children: [
                AnimatedContainer(duration: _dur, width: on ? 50 : 0, height: on ? 50 : 0, decoration: BoxDecoration(color: active.withOpacity(.12), shape: BoxShape.circle)),
                if (on) TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 450), curve: _ease, builder: (_, t, __) => CustomPaint(size: const Size(54, 54), painter: _ArcPainter(active, t))),
                AppIco(items[i].icon, color: on ? active : idle, size: 23),
              ]),
            )), height: 70);

      // ---- Detached: white pill bar plus the last item as a separate round button
      case 'detached':
        final last = items.length - 1;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              Expanded(
                child: Container(
                  height: 68,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(34), boxShadow: const [BoxShadow(color: Color(0x30000000), blurRadius: 24, offset: Offset(0, 10))]),
                  child: Row(children: [
                    for (var i = 0; i < last; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onTap(i),
                          child: AnimatedContainer(
                            duration: _dur,
                            curve: _ease,
                            decoration: BoxDecoration(color: i == selected ? active.withOpacity(.1) : Colors.transparent, borderRadius: BorderRadius.circular(28)),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              AppIco(items[i].icon, color: i == selected ? active : idle, size: 22),
                              if (labels != 'icons') Padding(padding: const EdgeInsets.only(top: 3), child: _label(items[i].label, i == selected ? active : idle, i == selected)),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => onTap(last),
                child: AnimatedContainer(
                  duration: _dur,
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(color: selected == last ? active : const Color(0xFF111111), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 8))]),
                  child: AppIco(items[last].icon, color: Colors.white, size: 26),
                ),
              ),
            ]),
          ),
        );

      // ---- Bump: the bar curves up under the selected item, which sits in a raised circle
      case 'bump':
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 82,
            child: LayoutBuilder(builder: (_, box) {
              final w = box.maxWidth / items.length;
              return TweenAnimationBuilder<double>(
                tween: Tween(end: w * selected + w / 2),
                duration: _dur,
                curve: _ease,
                builder: (_, x, __) => Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(top: 16, child: CustomPaint(painter: _BumpPainter(x, bg))),
                  Positioned(left: x - 25, top: 0, child: Container(width: 50, height: 50, decoration: BoxDecoration(color: active, shape: BoxShape.circle, boxShadow: [BoxShadow(color: active.withOpacity(.4), blurRadius: 14, offset: const Offset(0, 6))]), child: AppIco(items[selected].icon, color: _onActive, size: 22))),
                  Positioned.fill(
                    top: 16,
                    child: Row(children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onTap(i),
                            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                              if (i != selected) AppIco(items[i].icon, color: idle, size: 22),
                              if (labels != 'icons') Padding(padding: const EdgeInsets.only(top: 4, bottom: 10), child: _label(items[i].label, i == selected ? active : idle, i == selected)) else const SizedBox(height: 14),
                            ]),
                          ),
                        ),
                    ]),
                  ),
                ]),
              );
            }),
          ),
        );

      // ---- Segments: each item is its own outlined segment, the selected one is filled with its name
      case 'segments':
        return _float(Padding(
          padding: const EdgeInsets.all(6),
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                flex: i == selected ? 2 : 1,
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: _dur,
                    curve: _ease,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == selected ? Colors.white : Colors.white.withOpacity(.12),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(.35)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      AppIco(items[i].icon, color: i == selected ? active : Colors.white, size: 20),
                      if (i == selected && labels != 'icons') Flexible(child: Padding(padding: const EdgeInsets.only(left: 6), child: _label(items[i].label, active, true, size: 13))),
                    ]),
                  ),
                ),
              ),
          ]),
        ), color: active, radius: 30, height: 62);

      // ---- Slider: a soft pill slides behind the selected item
      case 'slider':
        return _flat(LayoutBuilder(builder: (_, box) {
          final w = box.maxWidth / items.length;
          return Stack(children: [
            AnimatedPositioned(duration: _dur, curve: _ease, left: w * selected + 6, width: w - 12, top: 8, bottom: 8, child: DecoratedBox(decoration: BoxDecoration(color: active.withOpacity(.13), borderRadius: BorderRadius.circular(18)))),
            Positioned.fill(child: _row((i, on) => Column(mainAxisSize: MainAxisSize.min, children: [
                  _icon(items[i].icon, on ? active : idle, on),
                  if (_showLabel(on)) Padding(padding: const EdgeInsets.only(top: 3), child: _label(items[i].label, on ? active : idle, on)),
                ]))),
          ]);
        }), height: 70);

      // ---- Gradient: colourful floating bar, white icons, a dot under the selected one
      case 'gradient':
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [active, Color.lerp(active, const Color(0xFF7C3AED), .55)!]),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: active.withOpacity(.45), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: _row((i, on) => Column(mainAxisSize: MainAxisSize.min, children: [
                  _icon(items[i].icon, on ? Colors.white : Colors.white.withOpacity(.6), on),
                  AnimatedContainer(duration: _dur, margin: const EdgeInsets.only(top: 5), width: on ? 6 : 0, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                ])),
          ),
        );

      // ---- Icon boxes: every icon in a rounded square, the selected square is coloured
      case 'iconbox':
        return _flat(_row((i, on) => Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: _dur,
                curve: _ease,
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: on ? active : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(13)),
                child: AppIco(items[i].icon, color: on ? _onActive : const Color(0xFF64748B), size: 21),
              ),
              if (labels != 'icons') Padding(padding: const EdgeInsets.only(top: 4), child: _label(items[i].label, on ? active : idle, on, size: 10.5)),
            ])), height: 76);

      // ---- Chip: the selected item becomes an outlined chip with its name
      case 'chip':
        return _flat(_spread((i, on) => AnimatedContainer(
              duration: _dur,
              curve: _ease,
              padding: EdgeInsets.symmetric(horizontal: on ? 14 : 10, vertical: 8),
              decoration: BoxDecoration(border: Border.all(color: on ? active : Colors.transparent, width: 1.6), borderRadius: BorderRadius.circular(24)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AppIco(items[i].icon, color: on ? active : idle, size: 22),
                AnimatedSize(duration: _dur, child: on && labels != 'icons' ? Padding(padding: const EdgeInsets.only(left: 7), child: _label(items[i].label, active, true, size: 13)) : const SizedBox.shrink()),
              ]),
            )));

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
    this.image = '',
  });

  /// Background photo for the Image header design.
  final String image;

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
      // ======== v26: ten more headers ========
      case 'wave':
        body = ClipPath(
          clipper: _WaveClip(),
          child: Container(
            decoration: BoxDecoration(gradient: grad),
            padding: EdgeInsets.only(top: top, bottom: 26),
            child: Column(mainAxisSize: MainAxisSize.min, children: [bar(), if (bottom != null) bottom!]),
          ),
        );
      case 'image':
        body = Container(
          height: top + 150,
          decoration: BoxDecoration(
            gradient: grad,
            image: image.isNotEmpty ? DecorationImage(image: NetworkImage(image), fit: BoxFit.cover) : null,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(.35), Colors.black.withOpacity(.55)]),
            ),
            padding: EdgeInsets.only(top: top),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconTheme(data: const IconThemeData(color: Colors.white), child: SizedBox(height: 50, child: Row(children: [if (leading != null) leading! else const SizedBox(width: 16), const Spacer(), ...actions, const SizedBox(width: 4)]))),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 13)),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                ]),
              ),
            ]),
          ),
        );
      case 'logo_center':
        body = Container(
          decoration: BoxDecoration(gradient: grad, boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 2))]),
          padding: EdgeInsets.only(top: top),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            IconTheme(
              data: IconThemeData(color: fg),
              child: SizedBox(
                height: 62,
                child: Row(children: [
                  SizedBox(width: 96, child: Align(alignment: Alignment.centerLeft, child: leading ?? const SizedBox())),
                  Expanded(child: Center(child: logo != null ? SizedBox(width: 38, height: 38, child: FittedBox(child: logo)) : Text(title, style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w800)))),
                  SizedBox(width: 96, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions.take(2).toList())),
                ]),
              ),
            ),
            if (bottom != null) bottom!,
          ]),
        );
      case 'dark_round':
        Widget dring(Widget w) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.06), border: Border.all(color: Colors.white.withOpacity(.14))),
              child: IconTheme(data: const IconThemeData(color: Colors.white, size: 20), child: Center(child: w)),
            );
        body = Container(
          decoration: const BoxDecoration(color: Color(0xFF16181D), borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
          padding: EdgeInsets.fromLTRB(12, top + 10, 12, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              if (leading != null) dring(leading!) else const SizedBox(width: 52),
              Expanded(child: Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w600, letterSpacing: -.3))),
              if (actions.isNotEmpty) dring(actions.first) else const SizedBox(width: 52),
            ]),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: bg.computeLuminance() < .05 ? const Color(0xFF22C55E) : bg, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 13)),
                ]),
              ),
            if (bottom != null) bottom!,
          ]),
        );
      case 'soft':
        final soft = Color.lerp(Colors.white, bg, .12)!;
        Widget sbtn(Widget w) => Container(
              margin: const EdgeInsets.only(left: 8),
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: IconTheme(data: const IconThemeData(color: Color(0xFF0F172A), size: 21), child: Center(child: w)),
            );
        body = Container(
          color: soft,
          padding: EdgeInsets.fromLTRB(20, top + 12, 14, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (logo != null) Padding(padding: const EdgeInsets.only(right: 10), child: ClipOval(child: SizedBox(width: 44, height: 44, child: FittedBox(fit: BoxFit.cover, child: logo)))),
              Expanded(child: Text(subtitle.isNotEmpty ? subtitle : 'Hello 👋', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w600))),
              for (final a in actions) sbtn(a),
              if (leading != null) sbtn(leading!),
            ]),
            const SizedBox(height: 12),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
            if (bottom != null) bottom!,
          ]),
        );
      case 'split':
        body = Container(
          color: Colors.white,
          padding: EdgeInsets.only(top: top),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: 62,
              child: Row(children: [
                Container(
                  width: 76,
                  height: 62,
                  decoration: BoxDecoration(gradient: grad, borderRadius: const BorderRadius.horizontal(right: Radius.circular(26))),
                  child: Center(child: logo ?? Icon(Icons.apps_rounded, color: fg)),
                ),
                if (leading != null) IconTheme(data: IconThemeData(color: bg), child: leading!),
                const SizedBox(width: 6),
                Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 19, fontWeight: FontWeight.w800))),
                IconTheme(data: IconThemeData(color: bg), child: Row(children: actions)),
                const SizedBox(width: 6),
              ]),
            ),
            if (bottom != null) bottom!,
          ]),
        );
      case 'outline':
        body = Container(
          decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: bg, width: 3))),
          padding: EdgeInsets.only(top: top),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            IconTheme(
              data: IconThemeData(color: bg),
              child: SizedBox(
                height: 58,
                child: Row(children: [
                  if (leading != null) leading! else const SizedBox(width: 16),
                  if (logo != null) Padding(padding: const EdgeInsets.only(right: 10), child: logo),
                  Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: center ? TextAlign.center : TextAlign.start, style: TextStyle(color: bg, fontSize: 20, fontWeight: FontWeight.w800))),
                  ...actions,
                  const SizedBox(width: 4),
                ]),
              ),
            ),
            if (bottom != null) bottom!,
          ]),
        );
      case 'glassfloat':
        body = Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [bg.withOpacity(.25), pageBg])),
          padding: EdgeInsets.fromLTRB(12, top + 8, 12, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(color: Colors.white.withOpacity(.72), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white)),
                child: IconTheme(
                  data: const IconThemeData(color: Color(0xFF0F172A)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(height: 56, child: Row(children: [
                      if (leading != null) leading! else const SizedBox(width: 16),
                      if (logo != null) Padding(padding: const EdgeInsets.only(right: 10), child: logo),
                      Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800))),
                      ...actions,
                      const SizedBox(width: 4),
                    ])),
                    if (bottom != null) bottom!,
                  ]),
                ),
              ),
            ),
          ),
        );
      case 'chip':
        Widget tbtn(Widget w) => Container(
              margin: const EdgeInsets.only(left: 6),
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: bg.withOpacity(.1), borderRadius: BorderRadius.circular(12)),
              child: IconTheme(data: IconThemeData(color: bg, size: 20), child: Center(child: w)),
            );
        body = Container(
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 3))]),
          padding: EdgeInsets.fromLTRB(4, top, 12, 0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: 62,
              child: Row(children: [
                if (leading != null) IconTheme(data: const IconThemeData(color: Color(0xFF0F172A)), child: leading!) else const SizedBox(width: 12),
                Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800))),
                if (subtitle.isNotEmpty)
                  Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: bg.withOpacity(.14), borderRadius: BorderRadius.circular(20)), child: Text(subtitle, style: TextStyle(color: bg, fontSize: 12, fontWeight: FontWeight.w700))),
                const Spacer(),
                for (final a in actions) tbtn(a),
              ]),
            ),
            if (bottom != null) bottom!,
          ]),
        );
      case 'shadow':
        body = Container(
          decoration: const BoxDecoration(color: Color(0xFF0B0B0C), boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 22, offset: Offset(0, 8))]),
          padding: EdgeInsets.only(top: top),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            IconTheme(
              data: const IconThemeData(color: Colors.white),
              child: SizedBox(
                height: 62,
                child: Row(children: [
                  SizedBox(width: 96, child: Align(alignment: Alignment.centerLeft, child: leading ?? const SizedBox())),
                  Expanded(child: Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700))),
                  SizedBox(width: 96, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions.take(2).toList())),
                ]),
              ),
            ),
            if (bottom != null) bottom!,
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
    final topColor = statusCustom ? statusBg : ({'outline': Colors.white, 'split': Colors.white, 'chip': Colors.white, 'soft': Color.lerp(Colors.white, bg, .12)!, 'glassfloat': pageBg, 'dark_round': const Color(0xFF16181D), 'shadow': const Color(0xFF0B0B0C), 'minimal': pageBg, 'bold': pageBg, 'search': pageBg, 'greeting': pageBg, 'floating': statusBg, 'island': statusBg, 'transparent': statusBg, 'pill': statusBg}[design] ?? bg);
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
      // ======== v26: ten more splash screens ========
      case 'wave':
        return Column(children: [
          Expanded(
            flex: 6,
            child: ClipPath(
              clipper: _WaveClip(),
              child: Container(width: double.infinity, decoration: grad, alignment: Alignment.center, child: showLogo ? _pop(AppLogo(url: logoUrl, size: 100, radius: 28)) : null),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (showTitle) _rise(Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 28, fontWeight: FontWeight.w800))),
                if (tagline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: _rise(Text(tagline, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))), delay: 150)),
              ]),
            ),
          ),
        ]);
      case 'rings':
        return Container(
          width: double.infinity,
          decoration: grad,
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (showLogo)
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(alignment: Alignment.center, children: [
                  for (final r in [250.0, 190.0, 135.0]) Container(width: r, height: r, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: titleColor.withOpacity(.16), width: 1.5))),
                  _Glow(color: titleColor, child: _pop(AppLogo(url: logoUrl, size: 92, radius: 26))),
                ]),
              ),
            if (showTitle) _rise(titleW, delay: 150),
            if (tagline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: _rise(tagW, delay: 250)),
          ]),
        );
      case 'neon':
        return Container(
          width: double.infinity,
          color: const Color(0xFF07080D),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (showLogo)
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(34), boxShadow: [BoxShadow(color: c1.withOpacity(.75), blurRadius: 60, spreadRadius: 6), BoxShadow(color: c2.withOpacity(.5), blurRadius: 120, spreadRadius: 10)]),
                child: _pop(AppLogo(url: logoUrl, size: 104, radius: 30)),
              ),
            if (showTitle) ...[const SizedBox(height: 34), _rise(Text(title, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, shadows: [Shadow(color: c1, blurRadius: 24)])))],
            if (tagline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: _rise(Text(tagline, style: TextStyle(color: Colors.white.withOpacity(.6))), delay: 150)),
          ]),
        );
      case 'dots':
        return Container(
          width: double.infinity,
          decoration: grad,
          child: CustomPaint(
            painter: _DotsPainter(titleColor.withOpacity(.14)),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (showLogo) _pop(Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(.2), borderRadius: BorderRadius.circular(32)), child: AppLogo(url: logoUrl, size: 96, radius: 26))),
                if (showTitle) ...[const SizedBox(height: 20), _rise(titleW, delay: 120)],
                if (tagline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: _rise(tagW, delay: 220)),
              ]),
            ),
          ),
        );
      case 'rise':
        return Container(
          width: double.infinity,
          decoration: grad,
          child: Column(children: [
            const Spacer(flex: 3),
            if (showLogo)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutBack,
                builder: (_, v, ch) => Transform.translate(offset: Offset(0, 160 * (1 - v)), child: Opacity(opacity: v.clamp(0, 1), child: ch)),
                child: AppLogo(url: logoUrl, size: 110, radius: 32),
              ),
            if (showTitle) ...[const SizedBox(height: 22), _rise(titleW, delay: 400)],
            if (tagline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: _rise(tagW, delay: 500)),
            const Spacer(flex: 4),
          ]),
        );
      case 'frame':
        return Container(
          width: double.infinity,
          color: Colors.white,
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (showLogo)
              _pop(Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(40), gradient: LinearGradient(colors: [c1, c2])),
                child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)), child: AppLogo(url: logoUrl, size: 92, radius: 24)),
              )),
            if (showTitle) ...[const SizedBox(height: 22), _rise(Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 26, fontWeight: FontWeight.w800)), delay: 120)],
            if (tagline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: _rise(Text(tagline, style: const TextStyle(color: Color(0xFF64748B))), delay: 200)),
          ]),
        );
      case 'stripes':
        return Container(
          width: double.infinity,
          decoration: grad,
          child: CustomPaint(
            painter: _StripesPainter(Colors.white.withOpacity(.08)),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (showLogo) _pop(AppLogo(url: logoUrl, size: 96, radius: 28)),
                if (showTitle) ...[const SizedBox(height: 18), _rise(titleW, delay: 120)],
                if (tagline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: _rise(tagW, delay: 200)),
              ]),
            ),
          ),
        );
      case 'line':
        return Container(
          width: double.infinity,
          color: c1,
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (showLogo) _pop(AppLogo(url: logoUrl, size: 54, radius: 16)),
              if (showTitle) Padding(padding: const EdgeInsets.only(left: 14), child: _rise(Text(title, style: TextStyle(color: titleColor, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.5)))),
            ]),
            const SizedBox(height: 26),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1800),
              curve: Curves.easeInOut,
              builder: (_, v, __) => Container(width: 180, height: 4, alignment: Alignment.centerLeft, decoration: BoxDecoration(color: titleColor.withOpacity(.15), borderRadius: BorderRadius.circular(4)), child: FractionallySizedBox(widthFactor: v, child: Container(decoration: BoxDecoration(color: titleColor, borderRadius: BorderRadius.circular(4))))),
            ),
            if (tagline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: Text(tagline, style: TextStyle(color: titleColor.withOpacity(.6)))),
          ]),
        );
      case 'mesh':
        return Stack(children: [
          Container(color: Color.lerp(c1, Colors.white, .85)),
          Positioned(left: -80, top: -60, child: _blob(c1, 320)),
          Positioned(right: -90, top: 200, child: _blob(c2, 300)),
          Positioned(left: 40, bottom: -100, child: _blob(Color.lerp(c1, c2, .5)!, 300)),
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: const SizedBox())),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (showLogo) _pop(Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(.6), borderRadius: BorderRadius.circular(34)), child: AppLogo(url: logoUrl, size: 96, radius: 26))),
              if (showTitle) ...[const SizedBox(height: 20), _rise(Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 28, fontWeight: FontWeight.w800)), delay: 120)],
              if (tagline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: _rise(Text(tagline, style: const TextStyle(color: Color(0xFF475569))), delay: 200)),
            ]),
          ),
        ]);
      case 'photo':
        return Container(
          width: double.infinity,
          decoration: grad,
          child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(.75)])),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 20, 26, 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Spacer(),
                  if (showLogo) _pop(AppLogo(url: logoUrl, size: 64, radius: 18)),
                  if (showTitle) ...[const SizedBox(height: 16), _rise(Text(title, style: const TextStyle(color: Colors.white, fontSize: 36, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -1)))],
                  if (tagline.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: _rise(Text(tagline, style: TextStyle(color: Colors.white.withOpacity(.8), fontSize: 16)), delay: 150)),
                ]),
              ),
            ),
          ),
        );
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
      // ======== v26: ten more menu headers ========
      case 'glass':
        return Container(
          margin: EdgeInsets.fromLTRB(12, top + 12, 12, 8),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [color, c2]), borderRadius: BorderRadius.circular(24)),
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.18), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.35))),
            child: Row(children: [
              AppLogo(url: logoUrl, size: 46, radius: 14),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 12.5)),
              ])),
            ]),
          ),
        );
      case 'pill':
        return Padding(
          padding: EdgeInsets.fromLTRB(12, top + 14, 12, 8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(40)),
            child: Row(children: [
              ClipOval(child: AppLogo(url: logoUrl, size: 46, radius: 0)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800)),
                if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink.withOpacity(.55), fontSize: 12)),
              ])),
              Container(width: 36, height: 36, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: const Icon(Icons.chevron_right_rounded, color: Colors.white)),
            ]),
          ),
        );
      case 'darkcard':
        return Container(
          margin: EdgeInsets.fromLTRB(12, top + 12, 12, 8),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFF111318), borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)), child: ClipOval(child: AppLogo(url: logoUrl, size: 48, radius: 0))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 12.5)),
            ])),
          ]),
        );
      case 'outline':
        return Container(
          margin: EdgeInsets.fromLTRB(12, top + 12, 12, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(.4), width: 1.5)),
          child: Row(children: [
            AppLogo(url: logoUrl, size: 46, radius: 14),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)),
              if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ])),
          ]),
        );
      case 'biglogo':
        return Padding(
          padding: EdgeInsets.fromLTRB(20, top + 24, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: color.withOpacity(.35), blurRadius: 24, offset: const Offset(0, 10))]), child: AppLogo(url: logoUrl, size: 92, radius: 28)),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(color: ink, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.6)),
            if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(color: ink.withOpacity(.55), fontSize: 14)),
          ]),
        );
      case 'stripe':
        return Container(
          margin: EdgeInsets.fromLTRB(0, top + 14, 16, 10),
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)), border: Border(left: BorderSide(color: color, width: 5))),
          child: Row(children: [
            AppLogo(url: logoUrl, size: 44, radius: 12),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)),
              if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink.withOpacity(.55), fontSize: 12.5)),
            ])),
          ]),
        );
      case 'overlap':
        return SizedBox(
          height: top + 140,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(height: top + 74, decoration: BoxDecoration(gradient: LinearGradient(colors: [color, c2]), borderRadius: const BorderRadius.only(bottomRight: Radius.circular(40)))),
            Positioned(
              left: 20,
              right: 16,
              top: top + 40,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: dark ? const Color(0xFF0F172A) : Colors.white, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12)]), child: ClipOval(child: AppLogo(url: logoUrl, size: 66, radius: 0))),
                const SizedBox(width: 12),
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w800)),
                    if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink.withOpacity(.55), fontSize: 12.5)),
                  ]),
                )),
              ]),
            ),
          ]),
        );
      case 'gradtext':
        return Padding(
          padding: EdgeInsets.fromLTRB(20, top + 26, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AppLogo(url: logoUrl, size: 40, radius: 12),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(20)), child: Text('Menu', style: TextStyle(color: dark ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 18),
            ShaderMask(
              shaderCallback: (r) => LinearGradient(colors: [color, Color.lerp(color, const Color(0xFFFF6B35), .7)!]).createShader(r),
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
            ),
            if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(color: ink.withOpacity(.55), fontSize: 14)),
          ]),
        );
      case 'underline':
        return Padding(
          padding: EdgeInsets.fromLTRB(22, top + 26, 22, 16),
          child: Row(children: [
            AppLogo(url: logoUrl, size: 50, radius: 15),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Container(width: 34, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
              if (subtitle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink.withOpacity(.55), fontSize: 12.5))),
            ])),
          ]),
        );
      case 'mesh':
        return ClipRRect(
          borderRadius: const BorderRadius.only(bottomRight: Radius.circular(30)),
          child: SizedBox(
            height: top + 150,
            child: Stack(children: [
              Container(color: Color.lerp(color, Colors.white, .8)),
              Positioned(left: -50, top: -40, child: _blob(color, 200)),
              Positioned(right: -60, bottom: -70, child: _blob(c2, 200)),
              Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), child: const SizedBox())),
              Positioned(
                left: 20,
                right: 16,
                bottom: 22,
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withOpacity(.6), borderRadius: BorderRadius.circular(18)), child: AppLogo(url: logoUrl, size: 54, radius: 14)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800)),
                    if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF475569), fontSize: 12.5)),
                  ])),
                ]),
              ),
            ]),
          ),
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


/// Soft round colour blob (mesh backgrounds).
Widget _blob(Color c, double size) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: c.withOpacity(.85)));

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.color, this.t);
  final Color color;
  final double t;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromLTWH(1, 1, s.width - 2, s.height - 2), -2.4, 1.65 * t, false, p);
  }

  @override
  bool shouldRepaint(_ArcPainter o) => o.t != t || o.color != color;
}

/// Bar shape that bulges up under the selected item.
class _BumpPainter extends CustomPainter {
  _BumpPainter(this.x, this.color);
  final double x;
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    const r = 34.0;
    final path = Path()
      ..moveTo(0, 14)
      ..lineTo(x - r - 14, 14)
      ..quadraticBezierTo(x - r, 14, x - r + 4, 4)
      ..cubicTo(x - r + 12, -16, x + r - 12, -16, x + r - 4, 4)
      ..quadraticBezierTo(x + r, 14, x + r + 14, 14)
      ..lineTo(s.width, 14)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 8, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BumpPainter o) => o.x != x || o.color != color;
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color;
    for (double y = 12; y < s.height; y += 22) {
      for (double x = 12; x < s.width; x += 22) {
        canvas.drawCircle(Offset(x, y), 2, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter o) => o.color != color;
}

class _StripesPainter extends CustomPainter {
  _StripesPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 26;
    for (double x = -s.height; x < s.width; x += 70) {
      canvas.drawLine(Offset(x, s.height), Offset(x + s.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(_StripesPainter o) => o.color != color;
}
