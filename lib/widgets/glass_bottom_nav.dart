import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_glass.dart';

const double leagueHubGlassBottomNavBarHeight = 64;

class LeagueHubGlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final GlassNavBarItem? overrideLastItem;

  const LeagueHubGlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.overrideLastItem,
  });

  @override
  Widget build(BuildContext context) {
    return _LiquidGlassBottomBar(
      currentIndex: currentIndex,
      onTap: onTap,
      activeColor: AppGlassColors.aqua,
      items: [
        const GlassNavBarItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
          iconSize: 26,
        ),
        const GlassNavBarItem(
          icon: Icons.campaign_outlined,
          activeIcon: Icons.campaign_rounded,
          label: 'Announcements',
          iconSize: 25,
        ),
        const GlassNavBarItem(
          icon: Icons.forum_outlined,
          activeIcon: Icons.forum_rounded,
          label: 'Chats',
          iconSize: 25,
        ),
        overrideLastItem ??
            const GlassNavBarItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              iconSize: 27,
            ),
      ],
    );
  }
}

class GlassNavBarItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final int? badge;
  final double iconSize;

  const GlassNavBarItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badge,
    this.iconSize = 24,
  });
}

class _LiquidGlassBottomBar extends StatefulWidget {
  final List<GlassNavBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color activeColor;

  const _LiquidGlassBottomBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.activeColor,
  });

  @override
  State<_LiquidGlassBottomBar> createState() => _LiquidGlassBottomBarState();
}

class _LiquidGlassBottomBarState extends State<_LiquidGlassBottomBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pillAnimation;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _pillAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(_LiquidGlassBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return SizedBox(
      height: leagueHubGlassBottomNavBarHeight + bottomPadding + 12,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 12),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 384),
            child: SizedBox(
              height: leagueHubGlassBottomNavBarHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.32),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: AppGlassColors.aqua.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildGlassBackground()),
                      Positioned.fill(child: _buildGlassBorder()),
                      _buildSlidingPill(),
                      _buildNavItems(),
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

  Widget _buildGlassBackground() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE6132030),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.16),
                AppGlassColors.pageWarm.withValues(alpha: 0.72),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassBorder() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 0.5,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              Colors.white.withValues(alpha: 0.14),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlidingPill() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / widget.items.length;
        const verticalPadding = 4.0;
        const horizontalInset = 8.0;
        final pillWidth =
            (itemWidth - horizontalInset * 2).clamp(64.0, 118.0).toDouble();
        const pillHeight =
            leagueHubGlassBottomNavBarHeight - verticalPadding * 2;

        return AnimatedBuilder(
          animation: _pillAnimation,
          builder: (context, child) {
            final startLeft =
                itemWidth * _previousIndex + (itemWidth - pillWidth) / 2;
            final endLeft =
                itemWidth * widget.currentIndex + (itemWidth - pillWidth) / 2;
            final currentLeft = lerpDouble(
              startLeft,
              endLeft,
              _pillAnimation.value,
            )!;

            return Stack(
              children: [
                Positioned(
                  left: currentLeft,
                  top: verticalPadding,
                  child: _GlassPill(
                    width: pillWidth,
                    height: pillHeight,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNavItems() {
    return Row(
      children: List.generate(widget.items.length, (index) {
        final item = widget.items[index];
        final isSelected = index == widget.currentIndex;

        return Expanded(
          child: Tooltip(
            message: item.label,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onTap(index);
              },
              behavior: HitTestBehavior.opaque,
              child: _NavItem(
                icon: isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                label: item.label,
                isSelected: isSelected,
                activeColor: widget.activeColor,
                badge: item.badge,
                iconSize: item.iconSize,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final double width;
  final double height;

  const _GlassPill({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withValues(alpha: 0.16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 0.5,
        ),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color activeColor;
  final int? badge;
  final double iconSize;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.activeColor,
    this.badge,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected ? activeColor : AppGlassColors.inkSecondary;
    final textColor = isSelected ? activeColor : AppGlassColors.inkMuted;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 29,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    bottom: 0,
                    child: AnimatedScale(
                      scale: isSelected ? 1.08 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.92, end: 1)
                                  .animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          icon,
                          key: ValueKey<int>(icon.codePoint),
                          size: iconSize,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ),
                  if (badge != null && badge! > 0)
                    Positioned(
                      right: -10,
                      top: -6,
                      child: _Badge(count: badge!),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: textColor,
                    letterSpacing: 0,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: Text(
                      label,
                      key: ValueKey<String>(label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;

  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withValues(alpha: 0.58),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
