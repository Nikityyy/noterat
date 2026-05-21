// lib/providers/comments_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class CommentsProvider extends ChangeNotifier {
  final SupabaseService _service = SupabaseService();

  final String noteId;
  final String groupId;
  final String userId;
  final String nickname;

  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = false;
  List<String> _memberNicknames = [];

  // @ mention suggest state
  List<String> _mentionSuggestions = [];
  bool _showMentionSuggest = false;

  // Comment input controller (exposed for the UI to bind).
  final TextEditingController inputController = TextEditingController();

  RealtimeChannel? _channel;

  List<Map<String, dynamic>> get comments => _comments;
  bool get isLoading => _isLoading;
  List<String> get memberNicknames => _memberNicknames;
  List<String> get mentionSuggestions => _mentionSuggestions;
  bool get showMentionSuggest => _showMentionSuggest;

  CommentsProvider({
    required this.noteId,
    required this.groupId,
    required this.userId,
    required this.nickname,
  }) {
    inputController.addListener(_onInputChanged);
    loadComments();
    _loadMembers();
    _setupRealtime();
  }

  // -------------------------------------------------------------------------
  // LOAD
  // -------------------------------------------------------------------------

  Future<void> loadComments() async {
    _isLoading = true;
    notifyListeners();
    try {
      _comments = await _service.getComments(noteId);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await _service.getGroupMembers(groupId);
      _memberNicknames = members
          .map((m) => m['nickname'] as String? ?? '')
          .where((n) => n.isNotEmpty && n != nickname)
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // @ MENTION DETECTION
  // -------------------------------------------------------------------------

  void _onInputChanged() {
    final text = inputController.text;
    final cursor = inputController.selection.baseOffset;
    if (cursor < 0) return;

    // Find the last '@' before the cursor with no whitespace after it.
    final beforeCursor = text.substring(0, cursor.clamp(0, text.length));
    final atIndex = beforeCursor.lastIndexOf('@');

    if (atIndex == -1) {
      _hideMentionSuggest();
      return;
    }

    final fragment = beforeCursor.substring(atIndex + 1);
    if (fragment.contains(' ') || fragment.contains('\n')) {
      _hideMentionSuggest();
      return;
    }

    _mentionSuggestions = _memberNicknames
        .where((n) => n.toLowerCase().startsWith(fragment.toLowerCase()))
        .toList();
    _showMentionSuggest = _mentionSuggestions.isNotEmpty;
    notifyListeners();
  }

  void _hideMentionSuggest() {
    if (_showMentionSuggest) {
      _showMentionSuggest = false;
      _mentionSuggestions = [];
      notifyListeners();
    }
  }

  void selectMention(String selected) {
    final text = inputController.text;
    final cursor = inputController.selection.baseOffset;
    final beforeCursor = text.substring(0, cursor.clamp(0, text.length));
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex == -1) return;

    final afterCursor = text.substring(cursor.clamp(0, text.length));
    final newText = '${text.substring(0, atIndex)}@$selected $afterCursor';
    final newCursor = atIndex + selected.length + 2;

    inputController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor.clamp(0, newText.length)),
    );

    _hideMentionSuggest();
  }

  // -------------------------------------------------------------------------
  // ADD / DELETE
  // -------------------------------------------------------------------------

  Future<void> addComment() async {
    final content = inputController.text.trim();
    if (content.isEmpty) return;

    // Extract mentioned users from @nickname patterns in the content.
    final mentionRegex = RegExp(r'@(\w+)');
    final mentions = mentionRegex
        .allMatches(content)
        .map((m) => m.group(1) ?? '')
        .where((n) => _memberNicknames.contains(n))
        .toList();

    try {
      final newComment = await _service.addComment(
        noteId: noteId,
        groupId: groupId,
        userId: userId,
        nickname: nickname,
        content: content,
        mentionedUsers: mentions,
      );
      _comments.add(newComment);
      inputController.clear();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _service.deleteComment(commentId);
      _comments.removeWhere((c) => c['id'] == commentId);
      notifyListeners();
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // REALTIME
  // -------------------------------------------------------------------------

  void _setupRealtime() {
    _channel = SupabaseService.client.channel('comments:$noteId');
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'note_comments',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'note_id',
        value: noteId,
      ),
      callback: (payload) {
        final row = payload.newRecord;
        // Avoid duplicates — we already added our own comment optimistically.
        final exists = _comments.any((c) => c['id'] == row['id']);
        if (!exists) {
          _comments.add(row);
          notifyListeners();
        }
      },
    );

    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'note_comments',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'note_id',
        value: noteId,
      ),
      callback: (payload) {
        final oldRow = payload.oldRecord;
        final id = oldRow['id'] as String?;
        if (id != null) {
          _comments.removeWhere((c) => c['id'] == id);
          notifyListeners();
        }
      },
    );

    _channel!.subscribe();
  }

  // -------------------------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------------------------

  String formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    inputController.removeListener(_onInputChanged);
    inputController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }
}
