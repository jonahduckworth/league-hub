import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';

class BrandingScreen extends ConsumerStatefulWidget {
  const BrandingScreen({super.key});

  @override
  ConsumerState<BrandingScreen> createState() => _BrandingScreenState();
}

class _BrandingScreenState extends ConsumerState<BrandingScreen> {
  late Color _primaryColor;
  late Color _secondaryColor;
  late Color _accentColor;
  late TextEditingController _nameController;
  bool _initialized = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _init() {
    if (_initialized) return;
    final org = ref.read(organizationProvider).valueOrNull;
    _primaryColor = _parseColor(org?.primaryColor ?? '#1A3A5C');
    _secondaryColor = _parseColor(org?.secondaryColor ?? '#2E75B6');
    _accentColor = _parseColor(org?.accentColor ?? '#4DA3FF');
    _nameController = TextEditingController(text: org?.name ?? '');
    _initialized = true;
  }

  Color _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) buffer.write('FF');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _save() async {
    final org = ref.read(organizationProvider).valueOrNull;
    if (org == null) return;

    setState(() => _isLoading = true);
    try {
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'primaryColor': _colorToHex(_primaryColor),
        'secondaryColor': _colorToHex(_secondaryColor),
        'accentColor': _colorToHex(_accentColor),
      };
      await ref
          .read(firestoreServiceProvider)
          .updateOrganization(org.id, updates);
      ref.invalidate(organizationProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Branding updated successfully'),
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
            content: Text('Failed to update branding: $e'),
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
    _init();
    final user = ref.watch(currentUserProvider).valueOrNull;
    final canEdit = user?.role == UserRole.platformOwner ||
        user?.role == UserRole.superAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Branding & Appearance'),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'ORGANIZATION NAME',
            child: TextFormField(
              controller: _nameController,
              enabled: canEdit,
              decoration: const InputDecoration(
                hintText: 'Organization name',
                prefixIcon: Icon(Icons.business),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'BRAND COLORS',
            child: Column(
              children: [
                _ColorPickerTile(
                  label: 'Primary Color',
                  color: _primaryColor,
                  enabled: canEdit,
                  onColorChanged: (c) => setState(() => _primaryColor = c),
                ),
                const Divider(height: 1),
                _ColorPickerTile(
                  label: 'Secondary Color',
                  color: _secondaryColor,
                  enabled: canEdit,
                  onColorChanged: (c) => setState(() => _secondaryColor = c),
                ),
                const Divider(height: 1),
                _ColorPickerTile(
                  label: 'Accent Color',
                  color: _accentColor,
                  enabled: canEdit,
                  onColorChanged: (c) => setState(() => _accentColor = c),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'PREVIEW',
            child: _buildPreview(),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _nameController.text.isEmpty
                    ? 'Organization'
                    : _nameController.text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('Primary',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: _secondaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('Secondary',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('Accent',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorPickerTile extends StatelessWidget {
  final String label;
  final Color color;
  final bool enabled;
  final ValueChanged<Color> onColorChanged;

  const _ColorPickerTile({
    required this.label,
    required this.color,
    required this.enabled,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label,
          style: const TextStyle(fontSize: 14, color: AppColors.text)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: enabled
                ? () => _showColorPicker(context, color, onColorChanged)
                : null,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showColorPicker(
      BuildContext context, Color current, ValueChanged<Color> onChanged) {
    final presets = [
      const Color(0xFF1A3A5C),
      const Color(0xFF2E75B6),
      const Color(0xFF4DA3FF),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF7C3AED),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
      const Color(0xFFF97316),
      const Color(0xFF6366F1),
      const Color(0xFF0EA5E9),
      const Color(0xFF84CC16),
      const Color(0xFF1E293B),
      const Color(0xFF334155),
      const Color(0xFF475569),
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Color'),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: presets.map((c) {
              final isSelected = c.value == current.value;
              return GestureDetector(
                onTap: () {
                  onChanged(c);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: c.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2)
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
