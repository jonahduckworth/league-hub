import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';

class AppIconScreen extends ConsumerStatefulWidget {
  const AppIconScreen({super.key});

  @override
  ConsumerState<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends ConsumerState<AppIconScreen> {
  int _selectedIndex = 0;
  bool _isLoading = false;

  static const _iconOptions = [
    _AppIconOption(
      name: 'Default',
      icon: Icons.sports,
      color: Color(0xFF1A3A5C),
      description: 'The standard League Hub icon',
    ),
    _AppIconOption(
      name: 'Soccer',
      icon: Icons.sports_soccer,
      color: Color(0xFF10B981),
      description: 'Soccer ball icon',
    ),
    _AppIconOption(
      name: 'Basketball',
      icon: Icons.sports_basketball,
      color: Color(0xFFF59E0B),
      description: 'Basketball icon',
    ),
    _AppIconOption(
      name: 'Football',
      icon: Icons.sports_football,
      color: Color(0xFF7C3AED),
      description: 'Football icon',
    ),
    _AppIconOption(
      name: 'Baseball',
      icon: Icons.sports_baseball,
      color: Color(0xFFEF4444),
      description: 'Baseball icon',
    ),
    _AppIconOption(
      name: 'Hockey',
      icon: Icons.sports_hockey,
      color: Color(0xFF0EA5E9),
      description: 'Hockey icon',
    ),
    _AppIconOption(
      name: 'Tennis',
      icon: Icons.sports_tennis,
      color: Color(0xFF84CC16),
      description: 'Tennis icon',
    ),
    _AppIconOption(
      name: 'Trophy',
      icon: Icons.emoji_events,
      color: Color(0xFFF97316),
      description: 'Championship trophy icon',
    ),
  ];

  Future<void> _save() async {
    final org = ref.read(organizationProvider).valueOrNull;
    if (org == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(firestoreServiceProvider).updateOrganization(
        org.id,
        {'appIcon': _iconOptions[_selectedIndex].name.toLowerCase()},
      );
      ref.invalidate(organizationProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App icon updated'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update icon: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canEdit = user?.role == UserRole.platformOwner ||
        user?.role == UserRole.superAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('App Icon'),
        actions: [
          if (canEdit)
            TextButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          // Preview
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _iconOptions[_selectedIndex].color,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _iconOptions[_selectedIndex].color.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              _iconOptions[_selectedIndex].icon,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _iconOptions[_selectedIndex].name,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text),
          ),
          Text(
            _iconOptions[_selectedIndex].description,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: _iconOptions.length,
              itemBuilder: (context, index) {
                final option = _iconOptions[index];
                final isSelected = index == _selectedIndex;
                return GestureDetector(
                  onTap: canEdit ? () => setState(() => _selectedIndex = index) : null,
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: option.color,
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected
                              ? Border.all(color: AppColors.primary, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: option.color.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(option.icon,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AppIconOption {
  final String name;
  final IconData icon;
  final Color color;
  final String description;

  const _AppIconOption({
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
  });
}
