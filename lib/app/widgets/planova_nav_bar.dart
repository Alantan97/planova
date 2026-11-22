import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// One tab in [PlanovaNavBar].
class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Subtle grey pill behind the selected tab, and a deeper orange for its icon
/// and label so the small text keeps WCAG AA contrast (4.5:1) on the grey.
const _selectedTint = Color(0xFFEFEFF2);
const _selectedInk = Color(0xFFA83C00);

/// The app's bottom bar: a rounded pill holding the tabs, with a highlight
/// that slides to the selected tab, and a separate round "+" on the right.
class PlanovaNavBar extends StatelessWidget {
  const PlanovaNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAdd,
  });
  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(child: _pill(duration)),
                const SizedBox(width: 12),
                _AddButton(onPressed: onAdd),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(Duration duration) => Container(
    height: height,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(height / 2),
      border: Border.all(color: planovaBorder),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / items.length;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: duration,
              curve: Curves.easeInOutCubic,
              left: itemWidth * selectedIndex,
              top: 0,
              bottom: 0,
              width: itemWidth,
              child: const DecoratedBox(
                decoration: ShapeDecoration(
                  color: _selectedTint,
                  shape: StadiumBorder(),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: items[i],
                      selected: i == selectedIndex,
                      duration: duration,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.duration,
    required this.onTap,
  });
  final NavItem item;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _selectedInk : planovaInk;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('nav-${item.label.toLowerCase()}'),
          customBorder: const StadiumBorder(),
          // No tap ripple or hover shade: they drew a grey pill on the
          // tapped tab before the sliding highlight arrived. Keyboard focus
          // still shows, so the bar stays usable without a touch screen.
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? _selectedTint
                : Colors.transparent,
          ),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: color),
                  duration: duration ~/ 2,
                  builder: (context, value, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? item.selectedIcon : item.icon,
                        color: value,
                        size: 24,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        maxLines: 1,
                        style: TextStyle(
                          color: value,
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The separate round "+" that opens the quick-add sheet. No visible label;
/// screen readers hear "Add".
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Add',
    excludeSemantics: true,
    onTap: onPressed,
    child: Container(
      width: PlanovaNavBar.height,
      height: PlanovaNavBar.height,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x33C74700),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: planovaActionOrange,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('quick-add'),
          onTap: onPressed,
          child: const Icon(
            Icons.add_rounded,
            color: planovaOnOrange,
            size: 32,
          ),
        ),
      ),
    ),
  );
}
