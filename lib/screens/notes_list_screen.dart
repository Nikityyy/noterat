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
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _refreshNotes(showLoading: true);
    _setupRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshNotes({bool showLoading = false}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final list = await _supabaseService.getNotes(widget.groupId);
      if (mounted) {
        setState(() {
          _notes = list;
          _filterNotes();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Could not load notes. Pull down to refresh.');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _setupRealtime() {
    _realtimeChannel = SupabaseService.client.channel('notes_list:${widget.groupId}');
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notes',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'group_id',
        value: widget.groupId,
      ),
      callback: (payload) => _refreshNotes(),
    );
    _realtimeChannel!.subscribe();
  }

  void _filterNotes() {
    if (_searchQuery.trim().isEmpty) {
      _filteredNotes = List.from(_notes);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredNotes = _notes.where((note) {
        final title = (note['title'] as String? ?? '').toLowerCase();
        final snippet = (note['snippet'] as String? ?? '').toLowerCase();
        return title.contains(query) || snippet.contains(query);
      }).toList();
    }
  }

  Future<void> _createNewNote() async {
    HapticFeedback.lightImpact();
    final auth = context.read<AuthProvider>();
    setState(() => _isLoading = true);
    try {
      final newNote = await _supabaseService.createNote(widget.groupId, 'Untitled Note');
      if (mounted) {
        _refreshNotes();
        Navigator.push(
          context,
          appRoute(EditorScreen(
            groupId: widget.groupId,
            noteId: newNote['id'] as String,
            groupName: widget.groupName,
            userId: auth.user!.id,
            nickname: auth.nickname ?? 'User',
          )),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Could not create note. Please try again.');
      }
    }
  }

  Future<void> _deleteNote(String noteId) async {
    HapticFeedback.lightImpact();
    try {
      await _supabaseService.deleteNote(noteId);
      _refreshNotes();
    } catch (e) {
      if (mounted) _showError('Could not delete note. Please try again.');
    }
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Note?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.kaiserRed),
        ),
        content: Text(
          'This note will be permanently deleted and cannot be recovered.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kaiserRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '${_notes.length} ${_notes.length == 1 ? "note" : "notes"}',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.outfit(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search notes…',
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textLight),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppColors.textLight),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _filterNotes();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _filterNotes();
                });
              },
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.styrianForest))
                : _filteredNotes.isEmpty
                    ? _buildEmptyState()
                    : _buildNotesList(auth),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewNote,
        backgroundColor: AppColors.styrianForest,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('New Note'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Container(
            width: 64,
            height: 64,
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
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _searchQuery.isNotEmpty
              ? 'Try a different search term.'
              : 'Create the first note for this workspace.',
          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textLight, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNotesList(AuthProvider auth) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _filteredNotes.length,
      itemBuilder: (context, index) {
        final note = _filteredNotes[index];
        final noteId = note['id'] as String;
        final title = note['title'] as String? ?? 'Untitled Note';
        final snippet = note['snippet'] as String? ?? '';
        final updatedAt = note['updated_at'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Dismissible(
            key: Key(noteId),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppColors.kaiserRed,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
            ),
            confirmDismiss: (direction) => _showDeleteConfirmation(context),
            onDismissed: (direction) => _deleteNote(noteId),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  appRoute(EditorScreen(
                    groupId: widget.groupId,
                    noteId: noteId,
                    groupName: widget.groupName,
                    userId: auth.user!.id,
                    nickname: auth.nickname ?? 'User',
                  )),
                ).then((_) => _refreshNotes());
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: AppColors.borderGray, width: 1.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
                      ],
                    ),
                    if (snippet.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textLight, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _formatDateTime(updatedAt),
                      style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textLight.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
