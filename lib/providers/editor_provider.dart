// lib/providers/editor_provider.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../crdt/crdt.dart';
import '../services/supabase_service.dart';

class EditorProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  final String groupId;
  final String noteId;
  final String userId;
  final String nickname;

  // Local Client ID (to distinguish our edits from remote edits)
  late final String clientId;

  final CrdtDoc doc = CrdtDoc();
  final TextEditingController controller = TextEditingController();

  bool _isSynced = false;
  bool _isLoading = true;
  String _lastKnownText = '';
  
  // Realtime Channel
  RealtimeChannel? _channel;
  Timer? _debounceTimer;
  
  // Presence / Collaborator Cursors
  // Maps: userId -> {'nickname': String, 'cursorIndex': int, 'lastActive': DateTime, 'line': int}
  final Map<String, Map<String, dynamic>> _collaborators = {};

  bool get isSynced => _isSynced;
  bool get isLoading => _isLoading;
  Map<String, Map<String, dynamic>> get collaborators => _collaborators;

  String get noteTitle {
    final text = doc.text.trim();
    if (text.isEmpty) return 'Untitled Note';
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'Untitled Note';
    final firstLine = lines[0];
    return firstLine.length > 40 ? '${firstLine.substring(0, 37)}...' : firstLine;
  }

  EditorProvider({
    required this.groupId,
    required this.noteId,
    required this.userId,
    required this.nickname,
  }) {
    clientId = _generateUuid();
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    // 1. Load Local Cache
    await _loadFromCache();

    // 2. Fetch Remote Updates & Sync
    try {
      await _fetchRemoteUpdates();
      _isSynced = true;
    } catch (e) {
      _isSynced = false;
    }

    _isLoading = false;
    notifyListeners();

    // 3. Connect to Supabase Realtime
    _connectRealtime();

    // 4. Start local controller listener
    controller.addListener(_onTextChanged);
  }

  // --- LOCAL CACHE ---

  String get _cacheKey => 'crdt_doc_$noteId';
  String get _pendingKey => 'pending_updates_$noteId';

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null) {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        doc.loadFromJson(decoded);
        _lastKnownText = doc.text;
        controller.text = _lastKnownText;
      }
    } catch (e) {
      // Fallback
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(doc.toJson());
      await prefs.setString(_cacheKey, encoded);
    } catch (e) {
      // Fallback
    }
  }

  // --- REMOTE DATABASE ---

  Future<void> _fetchRemoteUpdates() async {
    final updates = await _supabaseService.getDocumentUpdates(groupId, noteId);
    final List<CrdtChar> newChars = [];

    for (final row in updates) {
      final String updateBlobJson = row['update_blob'] as String;
      final List<dynamic> list = jsonDecode(updateBlobJson) as List<dynamic>;
      for (final item in list) {
        newChars.add(CrdtChar.fromJson(item as Map<String, dynamic>));
      }
    }

    doc.applyChanges(newChars);
    _lastKnownText = doc.text;
    
    // Update TextField while trying to keep cursor intact
    _updateTextAndPreserveCursor(_lastKnownText);
    await _saveToCache();
  }

  // --- CONTROLLER LISTENER (USER EDITS) ---

  void _onTextChanged() {
    final currentText = controller.text;
    if (currentText == _lastKnownText) {
      // Text change was programmatic (from remote update)
      return;
    }

    // 1. Calculate the local edit diff
    final diff = calculateDiff(_lastKnownText, currentText);

    final List<CrdtChar> newUpdates = [];

    // 2. Perform delete first if any
    if (diff.end > diff.start) {
      final deleted = doc.delete(diff.start, diff.end - diff.start, userId);
      newUpdates.addAll(deleted);
    }

    // 3. Perform insert next if any
    if (diff.inserted.isNotEmpty) {
      final inserted = doc.insert(diff.start, diff.inserted, userId, clientId);
      newUpdates.addAll(inserted);
    }

    _lastKnownText = doc.text;

    // 4. Save and Queue update
    if (newUpdates.isNotEmpty) {
      _saveToCache();
      _pushOrQueueUpdates(newUpdates);
    }

    // 5. Auto-update note title and snippet debounced
    _debounceAutoSaveNoteMetadata();

    // 6. Broadcast cursor index for presence
    _broadcastCursorPosition();
  }

  Future<void> _pushOrQueueUpdates(List<CrdtChar> updates) async {
    final updateBlobJson = jsonEncode(updates.map((u) => u.toJson()).toList());

    if (_isSynced) {
      try {
        await _supabaseService.pushDocumentUpdate(groupId, noteId, clientId, updateBlobJson);
      } catch (e) {
        _isSynced = false;
        notifyListeners();
        await _queuePendingUpdate(updateBlobJson);
      }
    } else {
      await _queuePendingUpdate(updateBlobJson);
    }
  }

  Future<void> _queuePendingUpdate(String updateJson) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingKey) ?? [];
    pending.add(updateJson);
    await prefs.setStringList(_pendingKey, pending);
  }

  Future<void> syncPendingUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingKey) ?? [];
    if (pending.isEmpty) return;

    _isSynced = false;
    notifyListeners();

    final remaining = <String>[];
    for (final updateJson in pending) {
      try {
        await _supabaseService.pushDocumentUpdate(groupId, noteId, clientId, updateJson);
      } catch (e) {
        remaining.add(updateJson);
      }
    }

    await prefs.setStringList(_pendingKey, remaining);

    if (remaining.isEmpty) {
      _isSynced = true;
      // Refresh to make sure we didn't miss other users' updates
      await _fetchRemoteUpdates();
    }
    notifyListeners();
  }

  // --- SUPABASE REALTIME (SYNC & BROADCAST) ---

  void _connectRealtime() {
    _channel = SupabaseService.client.channel('note:$noteId');

    // Listen to Database Insert updates on the document_updates table
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'document_updates',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'note_id',
        value: noteId,
      ),
      callback: (payload) {
        final newRow = payload.newRecord;
        final String remoteClientId = newRow['client_id'] as String;
        
        // Skip updates we generated locally
        if (remoteClientId == clientId) return;

        final String updateBlobJson = newRow['update_blob'] as String;
        final List<dynamic> list = jsonDecode(updateBlobJson) as List<dynamic>;
        final List<CrdtChar> remoteChars = list
            .map((item) => CrdtChar.fromJson(item as Map<String, dynamic>))
            .toList();

        // Apply and update
        doc.applyChanges(remoteChars);
        _lastKnownText = doc.text;
        _updateTextAndPreserveCursor(_lastKnownText);
        _saveToCache();
        notifyListeners();
      },
    );

    // Listen to Presence Cursor broadcast events
    _channel!.onBroadcast(
      event: 'cursor',
      callback: (payload) {
        final String remoteUserId = payload['userId'] as String;
        if (remoteUserId == userId) return;

        final String name = payload['nickname'] as String;
        final int index = payload['cursorIndex'] as int;
        final int line = payload['line'] as int;

        _collaborators[remoteUserId] = {
          'nickname': name,
          'cursorIndex': index,
          'line': line,
          'lastActive': DateTime.now(),
        };
        
        _cleanExpiredCollaborators();
        notifyListeners();
      },
    );

    // Subscribe to the channel
    _channel!.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isSynced = true;
        syncPendingUpdates();
      } else {
        _isSynced = false;
      }
      notifyListeners();
    });

    // Start a timer to remove inactive cursors
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (_cleanExpiredCollaborators()) {
        notifyListeners();
      }
    });
  }

  void _broadcastCursorPosition() {
    if (_channel == null || !_isSynced) return;

    final cursorIdx = controller.selection.baseOffset;
    if (cursorIdx < 0) return;

    // Calculate line number
    int lineNum = 1;
    final textBefore = controller.text.substring(0, cursorIdx);
    for (int i = 0; i < textBefore.length; i++) {
      if (textBefore[i] == '\n') lineNum++;
    }

    _channel!.sendBroadcastMessage(
      event: 'cursor',
      payload: {
        'userId': userId,
        'nickname': nickname,
        'cursorIndex': cursorIdx,
        'line': lineNum,
      },
    );
  }

  bool _cleanExpiredCollaborators() {
    bool changed = false;
    final now = DateTime.now();
    _collaborators.removeWhere((key, value) {
      final lastActive = value['lastActive'] as DateTime;
      if (now.difference(lastActive).inSeconds > 10) {
        changed = true;
        return true;
      }
      return false;
    });
    return changed;
  }

  // --- CURSOR ANCHORING ---

  void _updateTextAndPreserveCursor(String newText) {
    final textSelection = controller.selection;
    final cursorIndex = textSelection.baseOffset;

    if (cursorIndex < 0) {
      controller.text = newText;
      return;
    }

    // Get active chars before remote update
    final active = doc.activeChars;

    // Find the character node immediately before the cursor and at the cursor
    final CrdtChar? charBefore = cursorIndex > 0 && cursorIndex <= active.length 
        ? active[cursorIndex - 1] 
        : null;
    final CrdtChar? charAfter = cursorIndex < active.length 
        ? active[cursorIndex] 
        : null;

    final String? charBeforeId = charBefore?.id;
    final String? charAfterId = charAfter?.id;

    // Apply text update to the text controller
    controller.text = newText;

    // After setting the text, the sorted CRDT nodes are updated. Get new positions.
    final newActive = doc.activeChars;
    int newCursorIndex = -1;

    // Find where the cursor belongs in the new list of active characters
    int idxBefore = -1;
    int idxAfter = -1;

    if (charBeforeId != null) {
      idxBefore = newActive.indexWhere((c) => c.id == charBeforeId);
    }
    if (charAfterId != null) {
      idxAfter = newActive.indexWhere((c) => c.id == charAfterId);
    }

    if (idxBefore != -1 && idxAfter != -1) {
      newCursorIndex = idxBefore + 1;
    } else if (idxBefore != -1) {
      newCursorIndex = idxBefore + 1;
    } else if (idxAfter != -1) {
      newCursorIndex = idxAfter;
    } else {
      // Fallback: clamp old index to new bounds
      newCursorIndex = cursorIndex.clamp(0, newText.length);
    }

    // Update controller selection
    controller.selection = TextSelection.collapsed(offset: newCursorIndex);
  }

  // --- HELPER UUID GENERATOR ---

  String _generateUuid() {
    final rand = Random();
    final bytes = List.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // Variant 1
    
    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  void _debounceAutoSaveNoteMetadata() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () async {
      final text = doc.text.trim();
      String title = 'Untitled Note';
      String snippet = 'No additional text';

      if (text.isNotEmpty) {
        final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
        if (lines.isNotEmpty) {
          title = lines[0];
          if (title.length > 50) {
            title = '${title.substring(0, 47)}...';
          }
          if (lines.length > 1) {
            snippet = lines.sublist(1).join(' ');
          } else {
            snippet = '';
          }
          if (snippet.length > 80) {
            snippet = '${snippet.substring(0, 77)}...';
          }
        }
      }

      try {
        await _supabaseService.updateNoteMetadata(noteId, title, snippet);
      } catch (e) {
        // Fail silently for debounced auto-saves
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    controller.removeListener(_onTextChanged);
    controller.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }
}
