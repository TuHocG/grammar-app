/// Building blocks shared by every screen: the top bar with the "G" mark and a breadcrumb,
/// the centred content rail, white cards on the gray canvas, lilac panels, small badges,
/// round icon buttons and the pastel feature cards of the home page (DESIGN.md).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

/// One step of the breadcrumb; `route` null = current page (not tappable).
class Crumb {
  final String label;
  final String? route;
  const Crumb(this.label, [this.route]);
}

/// App bar: back arrow (when there is a page to pop), the "G" mark that goes home, then
/// either a breadcrumb (wide screens) or just the current title. Actions on the right.
class GrammarAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Crumb> crumbs;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  /// Optional widget shown in place of the breadcrumb (e.g. the dictionary search field).
  final Widget? title;
  const GrammarAppBar({super.key, this.crumbs = const [], this.actions = const [], this.bottom, this.title});

  @override
  Size get preferredSize => Size.fromHeight(56 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final theme = Theme.of(context);
    final wide = context.isWide;
    final router = GoRouter.maybeOf(context);
    final canPop = router?.canPop() ?? Navigator.of(context).canPop();
    final isHome = crumbs.isEmpty && title == null;

    Widget crumbWidget;
    if (title != null) {
      crumbWidget = title!;
    } else if (crumbs.isEmpty) {
      crumbWidget = Text('Grammar', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700));
    } else if (!wide || crumbs.length == 1) {
      crumbWidget = Text(crumbs.last.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium);
    } else {
      crumbWidget = Row(children: [
        for (var i = 0; i < crumbs.length; i++) ...[
          if (i > 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.chevron_right, size: 16, color: g.fog)),
          if (i == crumbs.length - 1)
            Flexible(child: Text(crumbs[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium))
          else
            InkWell(
              onTap: crumbs[i].route == null || router == null ? null : () => context.go(crumbs[i].route!),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(crumbs[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(color: g.slate)),
              ),
            ),
        ],
      ]);
    }

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      leadingWidth: 0,
      leading: const SizedBox.shrink(),
      title: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(children: [
          if (canPop)
            IconButton(tooltip: 'Quay lại', icon: const Icon(Icons.arrow_back), onPressed: () => router != null ? context.pop() : Navigator.of(context).pop())
          else
            const SizedBox(width: 8),
          GMark(onTap: isHome || router == null ? null : () => context.go('/')),
          const SizedBox(width: 12),
          Expanded(child: crumbWidget),
        ]),
      ),
      actions: [...actions, const SizedBox(width: 12)],
      bottom: bottom,
    );
  }
}

/// The square violet "G" logo mark.
class GMark extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;
  const GMark({super.key, this.onTap, this.size = 32});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: onTap == null ? '' : 'Trang chính',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        // The leaf G of Grammar 3.1 on its red tile, same art as the app icon (tool/icon).
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/brand/g_tile.png', width: size, height: size, filterQuality: FilterQuality.medium),
        ),
      ),
    );
  }
}

/// Centred content column of at most [Tokens.pageMaxWidth], with the page gutter.
class PageRail extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  const PageRail({super.key, required this.child, this.maxWidth = Tokens.pageMaxWidth, this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 40)});
  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: narrow ? padding.copyWith(left: 16, right: 16) : padding, child: child),
      ),
    );
  }
}

/// Scrollable page body: a rail of children.
class RailListView extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  final EdgeInsets padding;
  final ScrollController? controller;
  const RailListView({super.key, required this.children, this.maxWidth = Tokens.pageMaxWidth, this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 40), this.controller});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        controller: controller,
        child: PageRail(maxWidth: maxWidth, padding: padding, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
      );
}

/// White card (8px radius, hairline border) that is the content surface of every page.
class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool elevated;
  const Surface({super.key, required this.child, this.padding = const EdgeInsets.all(24), this.onTap, this.color, this.elevated = false});
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusCard), side: BorderSide(color: g.border));
    final inner = Padding(padding: padding, child: child);
    return Material(
      color: color ?? g.card,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      elevation: elevated ? 6 : 0,
      shadowColor: elevated ? g.shadow : Colors.transparent,
      child: onTap == null ? inner : InkWell(onTap: onTap, child: inner),
    );
  }
}

/// Tinted lilac panel for translations, explanations, highlights.
class LilacPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const LilacPanel({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12)});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(color: context.g.lilac, borderRadius: BorderRadius.circular(Tokens.radiusCard)),
        padding: padding,
        child: child,
      );
}

/// Small pill badge: "24", "MP3", "BT".
/// Vietnamese respelling of a headword ("che z" for chairs): a soft pill instead of the
/// old app's ‹…› brackets, which were hard to read at small sizes.
class Respell extends StatelessWidget {
  final String text;
  final double fontSize;
  const Respell(this.text, {super.key, this.fontSize = 15});
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    return Tooltip(
      message: 'Phiên âm tiếng Việt',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: g.lilac, borderRadius: BorderRadius.circular(100)),
        child: Text(text, style: TextStyle(fontFamily: Tokens.uiFont, fontSize: fontSize, fontWeight: FontWeight.w600, color: g.indigo, height: 1.2)),
      ),
    );
  }
}

class SoftBadge extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? background;
  const SoftBadge(this.text, {super.key, this.color, this.background});
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background ?? g.lilac, borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color ?? g.iris)),
    );
  }
}

/// Uppercase small caption above a block ("HÃY CHỌN CÂU ĐÚNG", "THÌ · BÀI 5/18").
class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.g.slate, letterSpacing: 0.6),
      );
}

/// Section title row with an optional trailing hint.
class SectionTitle extends StatelessWidget {
  final String text;
  final String? hint;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.hint, this.trailing});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: Text(text, style: theme.textTheme.titleLarge)),
      if (hint != null) Flexible(child: Text(hint!, style: theme.textTheme.bodyMedium?.copyWith(color: context.g.slate), textAlign: TextAlign.end)),
      ?trailing,
    ]);
  }
}

/// 40px round bordered icon button.
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final double size;
  const RoundIconButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.active = false, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? g.lilac : g.card,
        shape: CircleBorder(side: BorderSide(color: active ? g.iris : g.border)),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.5, color: onPressed == null ? g.fog : (active ? g.iris : g.ink)),
          ),
        ),
      ),
    );
  }
}

/// Square icon tile (lilac background, violet icon) used in list rows and set cards.
class IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  const IconTile(this.icon, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: g.lilac, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: g.iris, size: size * 0.5),
    );
  }
}

/// Study-set card: icon, title, one-line subtitle, optional badge or progress.
class SetCard extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final double? progress;
  final VoidCallback? onTap;
  /// Shown in place of the icon tile (e.g. a 56 px thumbnail).
  final Widget? leading;
  /// When set, the title is one line and the subtitle always takes exactly this many lines
  /// (shorter text leaves blank space), so every card of a grid has the same height.
  final int? subtitleLines;
  const SetCard({super.key, this.icon, required this.title, this.subtitle, this.badge, this.progress, this.onTap, this.leading, this.subtitleLines});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.g;
    final enabled = onTap != null;
    return Surface(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)] else if (icon != null) ...[IconTile(icon!), const SizedBox(width: 12)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(color: enabled ? g.ink : g.fog), maxLines: subtitleLines == null ? 2 : 1, overflow: TextOverflow.ellipsis),
            if (subtitleLines != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Stack(children: [
                  // Invisible block of [subtitleLines] lines reserves the height.
                  Opacity(opacity: 0, child: Text(List.filled(subtitleLines!, ' ').join('\n'), style: theme.textTheme.bodySmall)),
                  Text(subtitle ?? '', style: theme.textTheme.bodySmall, maxLines: subtitleLines, overflow: TextOverflow.ellipsis),
                ]),
              )
            else if (subtitle != null)
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
            if (progress != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: progress, minHeight: 4)),
              ),
          ]),
        ),
        ?badge == null ? null : Padding(padding: const EdgeInsets.only(left: 8), child: SoftBadge(badge!)),
      ]),
    );
  }
}

/// Large pastel card with a white inner panel (home page only).
class FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color tint;
  final Widget preview;
  final String caption;
  final VoidCallback onTap;
  const FeatureCard({super.key, required this.title, required this.icon, required this.tint, required this.preview, required this.caption, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.g;
    return Material(
      color: g.pastel(tint),
      borderRadius: BorderRadius.circular(Tokens.radiusFeature),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusFeature),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, color: g.ink), const SizedBox(width: 10), Expanded(child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: g.ink)))]),
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: g.card, borderRadius: BorderRadius.circular(Tokens.radiusCard), boxShadow: [BoxShadow(color: g.shadow.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))]),
                child: ClipRect(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: DefaultTextStyle(style: theme.textTheme.bodyMedium!.copyWith(color: g.slate, height: 1.45), child: preview),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(caption, style: theme.textTheme.bodyMedium?.copyWith(color: g.slate), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

/// Letter in a circle: option a–d, explanation marker.
class LetterDot extends StatelessWidget {
  final String letter;
  final Color? fill;
  final Color? border;
  final Color? color;
  final Widget? child;
  final double size;
  const LetterDot(this.letter, {super.key, this.fill, this.border, this.color, this.child, this.size = 32});
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: fill ?? Colors.transparent, border: Border.all(color: border ?? g.border)),
      child: child ?? Text(letter, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color ?? g.slate)),
    );
  }
}

/// Bottom bar with previous / next pills and something in the middle.
class PrevNextBar extends StatelessWidget {
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final String prevLabel;
  final String nextLabel;
  final Widget? middle;
  const PrevNextBar({super.key, this.onPrev, this.onNext, this.prevLabel = 'Bài trước', this.nextLabel = 'Bài kế', this.middle});
  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(color: context.g.card, border: Border(top: BorderSide(color: context.g.border))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: OutlinedButton.icon(onPressed: onPrev, icon: const Icon(Icons.chevron_left, size: 18), label: Text(narrow ? 'Trước' : prevLabel, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ),
          Expanded(child: middle == null ? const SizedBox.shrink() : Align(alignment: Alignment.center, heightFactor: 1, child: middle)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: OutlinedButton(
              onPressed: onNext,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text(narrow ? 'Kế' : nextLabel, maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Pill-shaped search field (home, dictionary, TOC filters).
class SearchPill extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool autofocus;
  final bool readOnly;
  final Widget? trailing;
  const SearchPill({super.key, this.controller, this.focusNode, required this.hint, this.onChanged, this.onSubmitted, this.onTap, this.autofocus = false, this.readOnly = false, this.trailing});
  @override
  Widget build(BuildContext context) {
    final g = context.g;
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(color: g.fog),
        prefixIcon: Icon(Icons.search, size: 20, color: g.fog),
        suffixIcon: trailing,
        isDense: true,
        filled: true,
        fillColor: g.canvas,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide(color: g.iris, width: 1.5)),
      ),
    );
  }
}

/// Simple "nothing here" message.
class EmptyNote extends StatelessWidget {
  final String text;
  const EmptyNote(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.g.slate))));
}

/// Responsive grid: as many columns of at least [minWidth] as fit.
class AutoGrid extends StatelessWidget {
  final List<Widget> children;
  final double minWidth;
  final double gap;
  final double? rowHeight;
  const AutoGrid({super.key, required this.children, this.minWidth = 260, this.gap = 16, this.rowHeight});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / (minWidth + gap)).floor().clamp(1, 6);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final ch in children) SizedBox(width: w, height: rowHeight, child: ch)],
        );
      });
}
