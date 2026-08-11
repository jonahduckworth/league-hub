import 'package:flutter/material.dart';

import '../core/design_system.dart';
import '../core/utils.dart';
import '../models/announcement.dart';
import 'app_glass.dart';

const int maxPinnedAnnouncementsInCarousel = 5;

List<Announcement> pinnedAnnouncementsForCarousel(
  List<Announcement> announcements,
) {
  return announcements
      .where((announcement) => announcement.isPinned)
      .take(maxPinnedAnnouncementsInCarousel)
      .toList(growable: false);
}

class PinnedAnnouncementsCarousel extends StatefulWidget {
  final List<Announcement> announcements;
  final VoidCallback onViewAll;
  final ValueChanged<Announcement> onAnnouncementTap;

  const PinnedAnnouncementsCarousel({
    super.key,
    required this.announcements,
    required this.onViewAll,
    required this.onAnnouncementTap,
  });

  @override
  State<PinnedAnnouncementsCarousel> createState() =>
      _PinnedAnnouncementsCarouselState();
}

class _PinnedAnnouncementsCarouselState
    extends State<PinnedAnnouncementsCarousel> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
  }

  @override
  void didUpdateWidget(PinnedAnnouncementsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page < widget.announcements.length) return;
    _page = widget.announcements.isEmpty ? 0 : widget.announcements.length - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) {
        _controller.jumpToPage(_page);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pinned = pinnedAnnouncementsForCarousel(widget.announcements);

    return Column(
      key: const ValueKey('pinned-announcements-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(onViewAll: widget.onViewAll),
        const SizedBox(height: AppSpacing.sm),
        if (pinned.isEmpty)
          const _NoPinnedAnnouncementsCard()
        else if (pinned.length == 1)
          SizedBox(
            height: _carouselHeight(context),
            child: _PinnedAnnouncementCard(
              announcement: pinned.single,
              position: 1,
              total: 1,
              onTap: () => widget.onAnnouncementTap(pinned.single),
            ),
          )
        else ...[
          SizedBox(
            key: const ValueKey('pinned-announcements-carousel'),
            height: _carouselHeight(context),
            child: PageView.builder(
              controller: _controller,
              padEnds: false,
              itemCount: pinned.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) {
                final announcement = pinned[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == pinned.length - 1 ? 0 : AppSpacing.sm,
                  ),
                  child: _PinnedAnnouncementCard(
                    announcement: announcement,
                    position: index + 1,
                    total: pinned.length,
                    onTap: () => widget.onAnnouncementTap(announcement),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Semantics(
              key: const ValueKey('pinned-page-semantics'),
              label: 'Announcement ${_page + 1} of ${pinned.length}',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < pinned.length; index++)
                    AnimatedContainer(
                      key: ValueKey('announcement-page-indicator-$index'),
                      duration: AppMotion.accessible(context, AppMotion.fast),
                      width: index == _page ? 18 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == _page
                            ? AppGlassColors.aqua
                            : AppGlassColors.inkMuted.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  double _carouselHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return 196 + ((scale - 1).clamp(0, 1) * 54);
  }
}

class _SectionHeader extends StatelessWidget {
  final VoidCallback onViewAll;

  const _SectionHeader({required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppGlassColors.gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppGlassColors.gold.withValues(alpha: 0.25),
            ),
          ),
          child: const Icon(
            Icons.push_pin_outlined,
            color: AppGlassColors.gold,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Pinned announcements',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppGlassColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('view-all-announcements'),
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            minimumSize: const Size(72, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('View all'),
        ),
      ],
    );
  }
}

class _NoPinnedAnnouncementsCard extends StatelessWidget {
  const _NoPinnedAnnouncementsCard();

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      key: const ValueKey('no-pinned-announcements'),
      radius: 20,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: const Row(
        children: [
          Icon(
            Icons.campaign_outlined,
            color: AppGlassColors.aqua,
            size: 24,
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No pinned announcements',
                  style: TextStyle(
                    color: AppGlassColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Important updates will appear here.',
                  style: TextStyle(
                    color: AppGlassColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedAnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final int position;
  final int total;
  final VoidCallback onTap;

  const _PinnedAnnouncementCard({
    required this.announcement,
    required this.position,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Pinned announcement $position of $total. '
          '${announcement.title}. ${announcement.body}',
      child: AppGlassSurface(
        key: ValueKey('pinned-announcement-${announcement.id}'),
        radius: 22,
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _CardBadge(
                        icon: Icons.push_pin_rounded,
                        label: 'Pinned',
                        color: AppGlassColors.gold,
                      ),
                      _CardBadge(
                        icon: Icons.groups_2_outlined,
                        label: announcement.scopeLabel,
                        color: AppGlassColors.aqua,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppGlassColors.inkMuted,
                  size: 19,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              announcement.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppGlassColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                announcement.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppGlassColors.inkSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.account_circle_outlined,
                  color: AppGlassColors.inkMuted,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    announcement.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppGlassColors.inkSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  AppUtils.formatDateTime(announcement.createdAt),
                  style: const TextStyle(
                    color: AppGlassColors.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CardBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
