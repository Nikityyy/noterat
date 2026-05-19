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
  
  // Realtime Channel for Note Updates
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
    super.dispose();
  }

  Future<void> _refreshNotes({bool showLoading = false}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load notes: $e')),
        );
      }
    }
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
      callback: (payload) {
        _refreshNotes();
      },
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
        // Redirect straight to Editor for the new note
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditorScreen(
              groupId: widget.groupId,
              noteId: newNote['id'] as String,
              groupName: widget.groupName,
              userId: auth.user!.id,
              nickname: auth.nickname ?? 'Alpinist',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create note: $e')),
        );
      }
    }
  }

  Future<void> _deleteNote(String noteId) async {
    HapticFeedback.lightImpact();
    try {
      await _supabaseService.deleteNote(noteId);
      _refreshNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete note: $e')),
        );
      }
    }
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.glacialWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: AppColors.borderGray, width: 1.0),
        ),
        title: Text(
          'Delete Note?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppColors.kaiserRed,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete this note? This action cannot be undone.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          OutlinedButton(
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
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[dt.month - 1];
      final day = dt.day.toString().padLeft(2, '0');
      return '$month $day, $hour:$minute';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.glacialWhite,
      appBar: AppBar(
        backgroundColor: AppColors.glacialWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.styrianForest),
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: AppColors.styrianForest,
              ),
            ),
            Text(
              '${_notes.length} ${_notes.length == 1 ? "note" : "notes"}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: AppColors.borderGray, width: 1.0),
              ),
              child: TextField(
                style: GoogleFonts.outfit(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search Notes...',
                  hintStyle: GoogleFonts.outfit(color: AppColors.textLight),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                    _filterNotes();
                  });
                },
              ),
            ),
          ),

          // Notes List
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        icon: const Icon(Icons.edit_note_outlined),
        label: const Text('Add Note'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        const Icon(
          Icons.note_alt_outlined,
          size: 72,
          color: AppColors.borderGray,
        ),
        const SizedBox(height: 16),
        Text(
          _searchQuery.isNotEmpty ? 'No Notes Match Query' : 'Cabin Notebook is Empty',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Text(
            _searchQuery.isNotEmpty
                ? 'Try editing your search query at the top.'
                : 'Create a collaborative note to start documenting with other cabin members.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesList(AuthProvider auth) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: _filteredNotes.length,
      itemBuilder: (context, index) {
        final note = _filteredNotes[index];
        final noteId = note['id'] as String;
        final title = note['title'] as String? ?? 'Untitled Note';
        final snippet = note['snippet'] as String? ?? '';
        final updatedAt = note['updated_at'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
            confirmDismiss: (direction) => _showDeleteConfirmation(context),
            onDismissed: (direction) => _deleteNote(noteId),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.steelLight,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: AppColors.borderGray, width: 1.0),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDateTime(updatedAt),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    snippet.trim().isEmpty ? 'Empty document' : snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.kaiserRed),
                      onPressed: () async {
                        final confirm = await _showDeleteConfirmation(context);
                        if (confirm == true) {
                          _deleteNote(noteId);
                        }
                      },
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textLight),
                  ],
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditorScreen(
                        groupId: widget.groupId,
                        noteId: noteId,
                        groupName: widget.groupName,
                        userId: auth.user!.id,
                        nickname: auth.nickname ?? 'Alpinist',
                      ),
                    ),
                  ).then((_) => _refreshNotes());
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
