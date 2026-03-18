import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/league.dart';

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
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
