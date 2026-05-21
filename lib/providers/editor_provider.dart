// lib/providers/editor_provider.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../crdt/crdt.dart';
import '../services/supabase_service.dart';

// ---------------------------------------------------------------------------
// Legacy CRDT migrator — reads old CrdtDoc blobs and extracts plain text so
// they can be seeded into a fresh Quill document (one-time migration).
// ---------------------------------------------------------------------------
class _LegacyCrdtMigrator {
  /// Returns true if [updateBlobJson] looks like a CRDT char-list blob.
  static bool isLegacyBlob(String updateBlobJson) {
    try {
      final decoded = jsonDecode(updateBlobJson);
      if (decoded is! List) return false;
      if (decoded.isEmpty) return false;
      final first = decoded.first;
      return first is Map && first.containsKey('id') && first.containsKey('char');
    } catch (_) {
      return false;
    }
  }

  /// Reconstructs plain text from a list of legacy CRDT update blobs.
  static String extractText(List<Map<String, dynamic>> rows) {
    final doc = CrdtDoc();
    final chars = <CrdtChar>[];
    for (final row in rows) {
      try {
        final blob = row['update_blob'] as String;
        final list = jsonDecode(blob) as List<dynamic>;
        for (final item in list) {
          chars.add(CrdtChar.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
    doc.applyChanges(chars);
    return doc.text;
  }
}

// ---------------------------------------------------------------------------
// EditorProvider
// ---------------------------------------------------------------------------
class EditorProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  final String groupId;
  final String noteId;
  final String userId;
  final String nickname;

  late final String clientId;

  // Quill controller — the single source of truth for document content.
  final QuillController quillController = QuillController(
    document: Document()..format(0, 1, Attribute.h1),
    selection: const TextSelection.collapsed(offset: 0),
  );

  bool _isSynced = false;
  bool _isLoading = true;
  bool _isNotePinned = false;

  RealtimeChannel? _channel;
  Timer? _debounceTimer;
  StreamSubscription? _quillChangeSub;

  // Presence / Collaborator Cursors
  final Map<String, Map<String, dynamic>> _collaborators = {};

  bool get isSynced => _isSynced;
  bool get isLoading => _isLoading;
  bool get isNotePinned => _isNotePinned;
  Map<String, Map<String, dynamic>> get collaborators => _collaborators;

  String get noteTitle {
    final text = quillController.document.toPlainText().trim();
    if (text.isEmpty) return 'Untitled Note';
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'Untitled Note';
    final first = lines[0];
    return first.length > 40 ? '${first.substring(0, 37)}...' : first;
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

  // -------------------------------------------------------------------------
  // INIT
  // -------------------------------------------------------------------------

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    // Load cached document first for instant display.
    await _loadFromCache();

    try {
      await _fetchAndComposeRemote();
      _isSynced = true;
    } catch (e) {
      _isSynced = false;
    }

    _isLoading = false;
    notifyListeners();

    _connectRealtime();
    _listenToQuillChanges();
  }

  // -------------------------------------------------------------------------
  // LOCAL CACHE (stores composed Quill Delta JSON)
  // -------------------------------------------------------------------------

  String get _cacheKey => 'quill_delta_$noteId';
  String get _pendingKey => 'pending_updates_$noteId';
  String get _pinnedKey => 'note_pinned_$noteId';

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      _isNotePinned = prefs.getBool(_pinnedKey) ?? false;
      if (cachedJson != null) {
        final deltaJson = jsonDecode(cachedJson) as List<dynamic>;
        final doc = Document.fromJson(deltaJson);
        quillController.document = doc;
      }
    } catch (_) {}
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deltaJson = jsonEncode(quillController.document.toDelta().toJson());
      await prefs.setString(_cacheKey, deltaJson);
      await prefs.setBool(_pinnedKey, _isNotePinned);
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // REMOTE — fetch + compose (with legacy migration)
  // -------------------------------------------------------------------------

  Future<void> _fetchAndComposeRemote() async {
    final rows = await _supabaseService.getDocumentUpdates(groupId, noteId);
    if (rows.isEmpty) return;

    // Check if all blobs are legacy CRDT format → migrate.
    final allLegacy = rows.every((r) {
      final blob = r['update_blob'] as String? ?? '';
      return _LegacyCrdtMigrator.isLegacyBlob(blob);
    });

    if (allLegacy) {
      await _migrateLegacy(rows);
      return;
    }

    // Compose Quill Deltas in chronological order.
    Document composed = Document();
    bool firstDelta = true;
    for (final row in rows) {
      try {
        final blob = row['update_blob'] as String;
        final isLegacy = _LegacyCrdtMigrator.isLegacyBlob(blob);
        if (isLegacy) continue; // skip stale legacy blobs mixed in

        final deltaJson = jsonDecode(blob) as List<dynamic>;
        final delta = Delta.fromJson(deltaJson);
        if (firstDelta) {
          // Replace document with first delta.
          composed = Document.fromDelta(delta);
          firstDelta = false;
        } else {
          composed.compose(delta, ChangeSource.remote);
        }
      } catch (_) {}
    }

    if (!firstDelta) {
      quillController.document = composed;
    }

    await _saveToCache();
  }

  Future<void> _migrateLegacy(List<Map<String, dynamic>> rows) async {
    final plainText = _LegacyCrdtMigrator.extractText(rows);

    // Build a fresh Quill document from plain text.
    final doc = Document()..insert(0, plainText.isEmpty ? ' ' : plainText);
    doc.format(0, 1, Attribute.h1);
    quillController.document = doc;

    // Push single migration delta to the DB and delete old rows.
    final migrationDelta = doc.toDelta();
    final migrationJson = jsonEncode(migrationDelta.toJson());

    try {
      // Delete old CRDT rows.
      await _supabaseService.deleteDocumentUpdates(noteId);
      // Push the migrated delta.
      await _supabaseService.pushDocumentUpdate(groupId, noteId, clientId, migrationJson);
    } catch (_) {}

    await _saveToCache();
  }

  // -------------------------------------------------------------------------
  // QUILL CHANGE LISTENER (user edits)
  // -------------------------------------------------------------------------

  void _listenToQuillChanges() {
    _quillChangeSub = quillController.changes.listen((event) {
      if (event.source == ChangeSource.remote) return; // avoid echo loops

      final delta = event.change;
      final deltaJson = jsonEncode(delta.toJson());

      _pushOrQueueUpdate(deltaJson);
      _debounceAutoSaveNoteMetadata();
      _broadcastCursorPosition();
    });
  }

  Future<void> _pushOrQueueUpdate(String deltaJson) async {
    if (_isSynced) {
      try {
        await _supabaseService.pushDocumentUpdate(groupId, noteId, clientId, deltaJson);
        await _saveToCache();
      } catch (e) {
        _isSynced = false;
        notifyListeners();
        await _queuePendingUpdate(deltaJson);
      }
    } else {
      await _queuePendingUpdate(deltaJson);
    }
  }

  Future<void> _queuePendingUpdate(String deltaJson) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingKey) ?? [];
    pending.add(deltaJson);
    await prefs.setStringList(_pendingKey, pending);
  }

  Future<void> syncPendingUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingKey) ?? [];
    if (pending.isEmpty) return;

    _isSynced = false;
    notifyListeners();

    final remaining = <String>[];
    for (final deltaJson in pending) {
      try {
        await _supabaseService.pushDocumentUpdate(groupId, noteId, clientId, deltaJson);
      } catch (e) {
        remaining.add(deltaJson);
      }
    }

    await prefs.setStringList(_pendingKey, remaining);

    if (remaining.isEmpty) {
      _isSynced = true;
      await _fetchAndComposeRemote();
    }
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // SUPABASE REALTIME
  // -------------------------------------------------------------------------

  void _connectRealtime() {
    _channel = SupabaseService.client.channel('note:$noteId');

    // DB inserts on document_updates
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
        final String remoteClientId = newRow['client_id'] as String? ?? '';
        if (remoteClientId == clientId) return; // skip our own echoes

        try {
          final blob = newRow['update_blob'] as String;
          if (_LegacyCrdtMigrator.isLegacyBlob(blob)) return; // ignore legacy
          final deltaJson = jsonDecode(blob) as List<dynamic>;
          final delta = Delta.fromJson(deltaJson);
          quillController.document.compose(delta, ChangeSource.remote);
          _saveToCache();
          notifyListeners();
        } catch (_) {}
      },
    );

    // Presence cursor broadcast
    _channel!.onBroadcast(
      event: 'cursor',
      callback: (payload) {
        final String remoteUserId = payload['userId'] as String? ?? '';
        if (remoteUserId == userId) return;

        _collaborators[remoteUserId] = {
          'nickname': payload['nickname'] as String? ?? 'User',
          'cursorIndex': payload['cursorIndex'] as int? ?? 0,
          'line': payload['line'] as int? ?? 1,
          'lastActive': DateTime.now(),
        };

        _cleanExpiredCollaborators();
        notifyListeners();
      },
    );

    _channel!.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isSynced = true;
        syncPendingUpdates();
      } else {
        _isSynced = false;
      }
      notifyListeners();
    });

    // Remove inactive collaborator cursors every 5 s
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (_cleanExpiredCollaborators()) notifyListeners();
    });
  }

  void _broadcastCursorPosition() {
    if (_channel == null || !_isSynced) return;
    final sel = quillController.selection;
    if (!sel.isValid) return;
    final idx = sel.baseOffset;
    final text = quillController.document.toPlainText();
    int line = 1;
    for (int i = 0; i < idx && i < text.length; i++) {
      if (text[i] == '\n') line++;
    }
    _channel!.sendBroadcastMessage(
      event: 'cursor',
      payload: {
        'userId': userId,
        'nickname': nickname,
        'cursorIndex': idx,
        'line': line,
      },
    );
  }

  bool _cleanExpiredCollaborators() {
    bool changed = false;
    final now = DateTime.now();
    _collaborators.removeWhere((_, v) {
      final lastActive = v['lastActive'] as DateTime;
      if (now.difference(lastActive).inSeconds > 10) {
        changed = true;
        return true;
      }
      return false;
    });
    return changed;
  }

  // -------------------------------------------------------------------------
  // PINNING
  // -------------------------------------------------------------------------

  Future<void> togglePin() async {
    final newVal = !_isNotePinned;
    _isNotePinned = newVal;
    notifyListeners();
    try {
      await _supabaseService.toggleNotePin(noteId, newVal);
      await _saveToCache();
    } catch (e) {
      // Revert on failure
      _isNotePinned = !newVal;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // DEBOUNCED METADATA UPDATE
  // -------------------------------------------------------------------------

  void _debounceAutoSaveNoteMetadata() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () async {
      final text = quillController.document.toPlainText().trim();
      String title = 'Untitled Note';
      String snippet = '';

      if (text.isNotEmpty) {
        final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
        if (lines.isNotEmpty) {
          title = lines[0].length > 50 ? '${lines[0].substring(0, 47)}...' : lines[0];
          if (lines.length > 1) {
            snippet = lines.sublist(1).join(' ');
            if (snippet.length > 80) snippet = '${snippet.substring(0, 77)}...';
          }
        }
      }

      try {
        await _supabaseService.updateNoteMetadata(noteId, title, snippet);
      } catch (_) {}
    });
  }

  // -------------------------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------------------------

  String _generateUuid() {
    final rand = Random();
    final bytes = List.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _quillChangeSub?.cancel();
    quillController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }
}
