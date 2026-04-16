import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../models/document.dart';
import '../models/league.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/permission_service.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/league_filter.dart';
import '../widgets/status_badge.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

List<String> buildVisibleDocumentCategories(List<Document> documents) {
  final existingCategories = documents.map((doc) => doc.category).toSet();
  return [
    'All',
    ..._documentCategories.where(existingCategories.contains),
  ];
}

const _documentCategories = [
  'Rosters',
  'Waivers',
  'Schedules',
  'Policies',
  'Other',
];

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _canUpload(AppUser? user) {
    if (user == null) return false;
    return PermissionService.isAtLeast(user.role, UserRole.managerAdmin);
  }

  @override
  Widget build(BuildContext context) {
    final bottomContentPadding = appShellBottomPadding(context);
    final docsAsync = ref.watch(documentsProvider);
    final leaguesAsync = ref.watch(leaguesProvider);
    final selectedLeagueId = ref.watch(selectedLeagueProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final leagues = leaguesAsync.valueOrNull ?? [];
    final showLeagueFilter = leagues.length > 1;
    final visibleCategories =
        buildVisibleDocumentCategories(docsAsync.valueOrNull ?? const []);

    return AppShellScaffold(
      floatingActionButton: _canUpload(currentUser)
          ? FloatingActionButton(
              heroTag: 'documents_fab',
              onPressed: () => context.push('/documents/upload'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      header: AppShellHeader(
        eyebrow: 'DOCS',
        leadingIcon: Icons.folder_copy_outlined,
        title: 'Documents',
        subtitle:
            'Policies, rosters, schedules, and shared files for your league.',
        bottom: AppHeaderSearchField(
          controller: _searchController,
          hintText: 'Search documents...',
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        ),
      ),
      stickyContent: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLeagueFilter) ...[
            LeagueFilter(
              leagues: leagues,
              selectedLeagueId: selectedLeagueId,
              onSelected: (id) =>
                  ref.read(selectedLeagueProvider.notifier).state = id,
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: visibleCategories
                  .map((cat) => _CategoryChip(
                        label: cat,
                        isSelected: selectedCategory == cat,
                        onTap: () => ref
                            .read(selectedCategoryProvider.notifier)
                            .state = cat,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
      child: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.danger)),
        ),
        data: (docs) {
          final filtered = _searchQuery.isEmpty
              ? docs
              : docs
                  .where((d) => d.name.toLowerCase().contains(_searchQuery))
                  .toList();

          if (filtered.isEmpty) {
            return EmptyState(
              icon: Icons.folder_open,
              title: 'No documents found',
              action: _canUpload(currentUser)
                  ? ElevatedButton.icon(
                      onPressed: () => context.push('/documents/upload'),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Document'),
                    )
                  : null,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(documentsProvider),
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottomContentPadding),
              itemCount: filtered.length,
              itemBuilder: (context, index) => _DocumentTile(
                doc: filtered[index],
                leagues: leagues,
                onTap: () => context.push('/documents/${filtered[index].id}'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final Document doc;
  final List<League> leagues;
  final VoidCallback onTap;

  const _DocumentTile({
    required this.doc,
    required this.leagues,
    required this.onTap,
  });

  IconData get _fileIcon {
    switch (doc.fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return Icons.table_chart;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color get _fileColor {
    switch (doc.fileType.toLowerCase()) {
      case 'pdf':
        return AppColors.danger;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return AppColors.success;
      case 'docx':
      case 'doc':
        return AppColors.primaryLight;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  String? get _leagueName {
    if (doc.leagueId == null) return null;
    return leagues
        .where((l) => l.id == doc.leagueId)
        .map((l) => l.abbreviation)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final versionCount = doc.versions.isEmpty ? 1 : doc.versions.length;
    final leagueName = _leagueName;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _fileColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_fileIcon, color: _fileColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBadge(
                          label: doc.category,
                          color: AppColors.primary,
                          fontSize: 11,
                          showBorder: false),
                      if (leagueName != null)
                        StatusBadge(
                            label: leagueName,
                            color: AppColors.accent,
                            fontSize: 11,
                            showBorder: false),
                      Text(
                        '${doc.fileType.toUpperCase()} • ${AppUtils.formatFileSize(doc.fileSize)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppUtils.formatDateTime(doc.updatedAt),
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  'v$versionCount',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
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
