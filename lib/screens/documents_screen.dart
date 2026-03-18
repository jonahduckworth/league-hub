import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/document.dart';
import '../providers/mock_data.dart';
import '../widgets/league_filter.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String? _selectedLeagueId;
  String _selectedCategory = 'All';
  final _searchController = TextEditingController();

  final _categories = ['All', 'Rosters', 'Waivers', 'Schedules', 'Policies'];

  List<Document> get _filteredDocs {
    return mockDocuments.where((d) {
      if (_selectedCategory != 'All' && d.category != _selectedCategory) return false;
      if (_selectedLeagueId != null && d.leagueId != _selectedLeagueId) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(icon: const Icon(Icons.upload_file), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search documents...',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
              ),
            ),
          ),
          LeagueFilter(
            leagues: mockLeagues,
            selectedLeagueId: _selectedLeagueId,
            onSelected: (id) => setState(() => _selectedLeagueId = id),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _categories.map((cat) => _CategoryChip(
                label: cat,
                isSelected: _selectedCategory == cat,
                onTap: () => setState(() => _selectedCategory = cat),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filteredDocs.isEmpty
                ? const Center(child: Text('No documents found', style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredDocs.length,
                    itemBuilder: (context, index) => _DocumentTile(doc: _filteredDocs[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.isSelected, required this.onTap});

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
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isSelected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final Document doc;
  const _DocumentTile({required this.doc});

  IconData get _fileIcon {
    switch (doc.fileType.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'xlsx': case 'csv': return Icons.table_chart;
      case 'docx': case 'doc': return Icons.description;
      default: return Icons.insert_drive_file;
    }
  }

  Color get _fileColor {
    switch (doc.fileType.toLowerCase()) {
      case 'pdf': return AppColors.danger;
      case 'xlsx': case 'csv': return AppColors.success;
      case 'docx': case 'doc': return AppColors.primaryLight;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
              color: _fileColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_fileIcon, color: _fileColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(doc.category, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 8),
                    Text(AppUtils.formatFileSize(doc.fileSize), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(AppUtils.formatDateTime(doc.updatedAt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 4),
              const Text('v1', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
