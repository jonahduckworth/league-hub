import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/league_branding.dart';
import '../models/app_user.dart';
import '../providers/data_providers.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/avatar_widget.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomContentPadding = appShellBottomPadding(context);
    final topContentPadding = appShellTopPadding(context);
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, null);
    final usersAsync = ref.watch(orgUsersProvider);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'Contacts',
        leadingIcon: Icons.contacts_outlined,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.name ?? 'League Hub',
        showBackButton: true,
      ),
      child: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            topContentPadding,
            16,
            bottomContentPadding,
          ),
          children: const [
            _ContactsMessageCard(message: 'Unable to load contacts.'),
          ],
        ),
        data: (users) {
          final contacts = users.where((user) => user.isActive).toList()
            ..sort((a, b) => a.displayName
                .toLowerCase()
                .compareTo(b.displayName.toLowerCase()));

          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              topContentPadding,
              16,
              bottomContentPadding,
            ),
            children: [
              if (contacts.isEmpty)
                const _ContactsMessageCard(message: 'No contacts yet.')
              else
                _ContactsList(contacts: contacts),
            ],
          );
        },
      ),
    );
  }
}

class _ContactsList extends StatelessWidget {
  final List<AppUser> contacts;

  const _ContactsList({required this.contacts});

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 22,
      child: Column(
        children: contacts.asMap().entries.map((entry) {
          final isLast = entry.key == contacts.length - 1;
          return Column(
            children: [
              _ContactRow(
                user: entry.value,
                onTap: () => context.push('/contacts/${entry.value.id}'),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 76,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;

  const _ContactRow({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = user.title ?? 'No title set';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppGlassColors.aqua.withValues(alpha: 0.08),
        highlightColor: AppGlassColors.aqua.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              AvatarWidget(
                imageUrl: user.avatarUrl,
                name: user.displayName,
                size: 48,
                backgroundColor: AppGlassColors.aqua.withValues(alpha: 0.18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppGlassColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: user.title == null
                            ? AppGlassColors.inkMuted
                            : AppGlassColors.aqua,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: const Icon(
                  Icons.chevron_right,
                  color: AppGlassColors.inkSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactsMessageCard extends StatelessWidget {
  final String message;

  const _ContactsMessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: const EdgeInsets.all(20),
      radius: 20,
      child: Text(
        message,
        style: const TextStyle(
          color: AppGlassColors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
