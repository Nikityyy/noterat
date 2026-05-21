// lib/screens/notes_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../utils/navigation.dart';
import 'editor_screen.dart';

class NotesListScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const NotesListScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  final SupabaseService _svc = SupabaseService();
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  RealtimeChannel? _rt;

  @override
  void initState() {
    super.initState();
    _refresh(showLoading: true);
    _setupRealtime();
  }

  @override
  void dispose() {
    _rt?.unsubscribe();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool showLoading = false}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final list = await _svc.getNotes(widget.groupId);
      if (mounted) setState(() { _notes = list; _applyFilter(); _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRealtime() {
    _rt = SupabaseService.client.channel('notes_list:${widget.groupId}');
    _rt!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notes',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'group_id', value: widget.groupId),
      callback: (_) => _refresh(),
    );
    _rt!.subscribe();
  }

  void _applyFilter() {
    if (_searchQuery.trim().isEmpty) {
      _filtered = List.from(_notes);
    } else {
      final q = _searchQuery.toLowerCase();
      _filtered = _notes.where((n) {
        final t = (n['title'] as String? ?? '').toLowerCase();
        final s = (n['snippet'] as String? ?? '').toLowerCase();
        return t.contains(q) || s.contains(q);
      }).toList();
    }
  }

  Future<void> _createNote() async {
    HapticFeedback.lightImpact();
    final auth = context.read<AuthProvider>();
    setState(() => _isLoading = true);
    try {
      final note = await _svc.createNote(widget.groupId, 'Untitled Note');
      if (mounted) {
        _refresh();
        Navigator.push(
          context,
          appRoute(EditorScreen(
            groupId: widget.groupId,
            noteId: note['id'] as String,
            groupName: widget.groupName,
            userId: auth.user!.id,
            nickname: auth.nickname ?? 'User',
          )),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNote(String noteId) async {
    HapticFeedback.lightImpact();
    try {
      await _svc.deleteNote(noteId);
      _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete note.')));
      }
    }
  }

  Future<void> _togglePin(String noteId, bool currentlyPinned) async {
    HapticFeedback.lightImpact();
    try {
      await _svc.toggleNotePin(noteId, !currentlyPinned);
      _refresh();
    } catch (_) {}
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete Note?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.kaiserRed)),
          content: Text('This note will be permanently deleted.', style: GoogleFonts.outfit()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.kaiserRed, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

  String _fmt(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[dt.month - 1]} ${dt.day}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pinned = _filtered.where((n) => n['is_pinned'] == true).toList();
    final unpinned = _filtered.where((n) => n['is_pinned'] != true).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.groupName, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3)),
          Text('${_notes.length} ${_notes.length == 1 ? "note" : "notes"}',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight)),
        ]),
      ),
      body: Column(children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.outfit(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search notes…',
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textLight),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppColors.textLight),
                      onPressed: () { _searchCtrl.clear(); setState(() { _searchQuery = ''; _applyFilter(); }); },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() { _searchQuery = v; _applyFilter(); }),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.styrianForest))
              : _filtered.isEmpty
                  ? _emptyState()
                  : _buildList(auth, pinned, unpinned),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNote,
        backgroundColor: AppColors.styrianForest,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('New Note'),
      ),
    );
  }

  Widget _emptyState() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Center(
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.steelLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderGray),
              ),
              child: const Icon(Icons.notes_outlined, size: 28, color: AppColors.textLight),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No Results Found' : 'No Notes Yet',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty ? 'Try a different search term.' : 'Create the first note for this workspace.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textLight, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _buildList(AuthProvider auth, List<Map<String, dynamic>> pinned, List<Map<String, dynamic>> unpinned) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (pinned.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            sliver: SliverToBoxAdapter(
              child: Row(children: [
                const Icon(Icons.push_pin, size: 13, color: AppColors.styrianForest),
                const SizedBox(width: 5),
                Text('Pinned',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold,
                        color: AppColors.styrianForest, letterSpacing: 0.5)),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _noteCard(context, pinned[i], auth, isPinned: true),
                childCount: pinned.length,
              ),
            ),
          ),
        ],
        if (unpinned.isNotEmpty) ...[
          if (pinned.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Text('Notes',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold,
                        color: AppColors.textLight, letterSpacing: 0.5)),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, pinned.isEmpty ? 8 : 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _noteCard(context, unpinned[i], auth, isPinned: false),
                childCount: unpinned.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _noteCard(BuildContext ctx, Map<String, dynamic> note, AuthProvider auth, {required bool isPinned}) {
    final noteId = note['id'] as String;
    final title = note['title'] as String? ?? 'Untitled Note';
    final snippet = note['snippet'] as String? ?? '';
    final updatedAt = note['updated_at'] as String? ?? '';
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(noteId),
        // Right swipe → pin/unpin  |  Left swipe → delete
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: AppColors.styrianForest.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              color: AppColors.styrianForest, size: 22),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.kaiserRed,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
        ),
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            _togglePin(noteId, isPinned);
            return false; // don't actually dismiss — just trigger pin
          }
          return _confirmDelete(ctx);
        },
        onDismissed: (dir) {
          if (dir == DismissDirection.endToStart) _deleteNote(noteId);
        },
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              ctx,
              appRoute(EditorScreen(
                groupId: widget.groupId,
                noteId: noteId,
                groupName: widget.groupName,
                userId: auth.user!.id,
                nickname: auth.nickname ?? 'User',
              )),
            ).then((_) => _refresh());
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            showModalBottomSheet(
              context: ctx,
              builder: (_) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                    leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                        color: AppColors.styrianForest),
                    title: Text(isPinned ? 'Unpin Note' : 'Pin Note', style: GoogleFonts.outfit()),
                    onTap: () { Navigator.pop(ctx); _togglePin(noteId, isPinned); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: AppColors.kaiserRed),
                    title: Text('Delete Note', style: GoogleFonts.outfit(color: AppColors.kaiserRed)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await _confirmDelete(ctx);
                      if (ok == true) _deleteNote(noteId);
                    },
                  ),
                ]),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderGray),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Container(
                decoration: isPinned
                    ? const BoxDecoration(border: Border(left: BorderSide(color: AppColors.styrianForest, width: 3)))
                    : null,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textDark),
                  ),
                ),
                if (isPinned) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.push_pin, size: 13, color: AppColors.styrianForest),
                ],
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
              ]),
              if (snippet.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(snippet, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textLight, height: 1.4)),
              ],
              const SizedBox(height: 8),
              Text(_fmt(updatedAt),
                  style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textLight.withValues(alpha: 0.7))),
            ]),
          ),
        ),
      ),
    ),
  ),
);
  }
}
