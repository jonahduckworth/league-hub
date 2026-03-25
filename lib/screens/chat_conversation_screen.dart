import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  Timer? _typingTimer;

  /// When non-null, the user is editing an existing message instead of composing.
  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening the conversation.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAsRead());
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    // Clear typing indicator when leaving.
    _clearTyping();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Read receipts
  // ---------------------------------------------------------------------------

  Future<void> _markAsRead() async {
    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (orgId == null || userId == null) return;
    try {
      await ref
          .read(firestoreServiceProvider)
          .markMessagesAsRead(orgId, widget.roomId, userId);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Typing indicator
  // ---------------------------------------------------------------------------

  void _onTextChanged() {
    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    final user = ref.read(currentUserProvider).valueOrNull;
    if (orgId == null || user == null) return;

    if (_messageController.text.isNotEmpty) {
      ref
          .read(firestoreServiceProvider)
          .setTyping(orgId, widget.roomId, user.id, user.displayName);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 4), _clearTyping);
    } else {
      _clearTyping();
    }
  }

  void _clearTyping() {
    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (orgId == null || userId == null) return;
    ref
        .read(firestoreServiceProvider)
        .clearTyping(orgId, widget.roomId, userId);
  }

  // ---------------------------------------------------------------------------
  // Scroll
  // ---------------------------------------------------------------------------

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Send / Edit / Delete
  // ---------------------------------------------------------------------------

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (orgId == null || currentUser == null) return;

    setState(() => _isSending = true);
    _messageController.clear();
    _clearTyping();

    try {
      if (_editingMessageId != null) {
        await ref.read(firestoreServiceProvider).updateMessage(
              orgId,
              widget.roomId,
              _editingMessageId!,
              text,
            );
        setState(() => _editingMessageId = null);
      } else {
        await ref.read(firestoreServiceProvider).sendMessage(
              orgId,
              widget.roomId,
              senderId: currentUser.id,
              senderName: currentUser.displayName,
              text: text,
            );
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());
      }
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

  void _startEditing(Message message) {
    setState(() {
      _editingMessageId = message.id;
      _messageController.text = message.text ?? '';
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _messageController.clear();
    });
  }

  Future<void> _deleteMessage(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message'),
        content:
            const Text('This message will be removed for everyone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;

    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    if (orgId == null) return;
    try {
      await ref
          .read(firestoreServiceProvider)
          .deleteMessage(orgId, widget.roomId, message.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Media picker
  // ---------------------------------------------------------------------------

  Future<void> _pickAndSendImage() async {
    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (orgId == null || currentUser == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _isSending = true);

      // Upload via Firebase Storage and get the download URL.
      // The storage upload is handled by the service layer; for now
      // we send a placeholder path that the backend Cloud Function
      // or client-side upload logic resolves.
      final storagePath =
          'orgs/$orgId/chat/${widget.roomId}/${DateTime.now().millisecondsSinceEpoch}_${picked.name}';

      // In production, upload picked.path to Firebase Storage at
      // storagePath and get the download URL. For the MVP we record
      // the intended path so the upload layer can resolve it.
      await ref.read(firestoreServiceProvider).sendMediaMessage(
            orgId,
            widget.roomId,
            senderId: currentUser.id,
            senderName: currentUser.displayName,
            mediaUrl: storagePath,
            mediaType: 'image/${picked.name.split('.').last}',
            caption: null,
          );
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send image: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(chatRoomProvider(widget.roomId));
    final messagesAsync = ref.watch(messagesProvider(widget.roomId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final typingUsers =
        ref.watch(typingUsersProvider(widget.roomId)).valueOrNull ?? [];

    // Auto-scroll and mark-as-read when new messages arrive.
    ref.listen<AsyncValue<List<Message>>>(
      messagesProvider(widget.roomId),
      (prev, next) {
        final prevCount = prev?.valueOrNull?.length ?? 0;
        final nextCount = next.valueOrNull?.length ?? 0;
        if (nextCount > prevCount) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
          _markAsRead();
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
            if (typingUsers.isNotEmpty)
              Text(
                _typingLabel(typingUsers),
                style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.white70),
              )
            else if (participantCount > 0)
              Text(
                  '$participantCount member${participantCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.info_outlined),
              onPressed: () =>
                  context.push('/chat/${widget.roomId}/info')),
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

                final items =
                    _buildMessageItems(messages, currentUser?.id);

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) => items[index],
                );
              },
            ),
          ),
          if (_editingMessageId != null) _buildEditBanner(),
          _buildInputBar(),
        ],
      ),
    );
  }

  String _typingLabel(List<String> names) {
    if (names.length == 1) return '${names.first} is typing...';
    if (names.length == 2) return '${names[0]} and ${names[1]} are typing...';
    return '${names.first} and ${names.length - 1} others are typing...';
  }

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
      items.add(ChatBubble(
        message: message,
        isSelf: isSelf,
        onEdit: isSelf && !message.deleted ? () => _startEditing(message) : null,
        onDelete: isSelf && !message.deleted ? () => _deleteMessage(message) : null,
      ));
    }

    return items;
  }

  Widget _buildEditBanner() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.edit, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Editing message',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: _cancelEditing,
            child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
          ),
        ],
      ),
    );
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
          // Media attachment button
          IconButton(
            icon: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
            onPressed: _isSending ? null : _pickAndSendImage,
            tooltip: 'Send image',
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: _editingMessageId != null
                    ? 'Edit your message...'
                    : 'Type a message...',
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
            decoration: BoxDecoration(
              color: _editingMessageId != null
                  ? AppColors.accent
                  : AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(
                      _editingMessageId != null ? Icons.check : Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
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
