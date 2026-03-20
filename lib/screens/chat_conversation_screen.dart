import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../widgets/chat_bubble.dart';

class ChatConversationScreen extends ConsumerStatefulWidget {
  final String roomId;

  const ChatConversationScreen({super.key, required this.roomId});

  @override
  ConsumerState<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState
    extends ConsumerState<ChatConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (orgId == null || currentUser == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ref.read(firestoreServiceProvider).sendMessage(
            orgId,
            widget.roomId,
            senderId: currentUser.id,
            senderName: currentUser.displayName,
            text: text,
          );
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(chatRoomProvider(widget.roomId));
    final messagesAsync = ref.watch(messagesProvider(widget.roomId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    // Auto-scroll when new messages arrive.
    ref.listen<AsyncValue<List<Message>>>(
      messagesProvider(widget.roomId),
      (prev, next) {
        final prevCount = prev?.valueOrNull?.length ?? 0;
        final nextCount = next.valueOrNull?.length ?? 0;
        if (nextCount > prevCount) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
        }
      },
    );

    final room = roomAsync.valueOrNull;
    final roomName = room?.name ?? 'Chat';
    final participantCount = room?.participants.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(roomName,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            if (participantCount > 0)
              Text(
                  '$participantCount member${participantCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.info_outlined),
              onPressed: () => context.push('/chat/${widget.roomId}/info')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error loading messages: $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 56, color: AppColors.textMuted),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Be the first to say something!',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  );
                }

                // Build a flat list of widgets: date dividers + bubbles.
                final items = _buildMessageItems(messages, currentUser?.id);

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) => items[index],
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  /// Interleaves date-divider widgets between messages that span different days.
  List<Widget> _buildMessageItems(
      List<Message> messages, String? currentUserId) {
    final List<Widget> items = [];
    DateTime? lastDate;

    for (final message in messages) {
      final msgDate = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );

      if (lastDate == null || msgDate != lastDate) {
        items.add(_DateDivider(date: message.createdAt));
        lastDate = msgDate;
      }

      final isSelf = message.senderId == currentUserId;
      items.add(ChatBubble(message: message, isSelf: isSelf));
    }

    return items;
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: AppColors.primary)),
                filled: true,
                fillColor: AppColors.background,
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date divider widget
// ---------------------------------------------------------------------------

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(
              child: Divider(color: AppColors.border, endIndent: 12)),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _label(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Expanded(
              child: Divider(color: AppColors.border, indent: 12)),
        ],
      ),
    );
  }
}
