import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/league.dart';
import 'entity_avatar.dart';

class LeagueFilter extends StatelessWidget {
  final List<League> leagues;
  final String? selectedLeagueId;
  final void Function(String?) onSelected;

  const LeagueFilter({
    super.key,
    required this.leagues,
    required this.selectedLeagueId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterPill(
            label: 'All',
            isSelected: selectedLeagueId == null,
            onTap: () => onSelected(null),
          ),
          ...leagues.map((league) => _FilterPill(
                label: league.abbreviation,
                league: league,
                isSelected: selectedLeagueId == league.id,
                onTap: () => onSelected(league.id),
              )),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final League? league;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    this.league,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (league != null) ...[
              EntityAvatar(
                name: league!.abbreviation,
                imageUrl: league!.logoUrl,
                iconName: league!.iconName,
                fallbackIcon: Icons.emoji_events_outlined,
                size: 22,
                borderRadius: 8,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
