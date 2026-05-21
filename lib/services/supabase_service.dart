// lib/services/supabase_service.dart

import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // CONFIGURATION: Replace these with your actual Supabase project credentials.
  static const String supabaseUrl = 'https://cpfvroxraylfwtimayhg.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_ecXZrY0z2C1uHYTrJwFtSA_zcfVkq4-';

  static final client = Supabase.instance.client;

  // --- AUTHENTICATION ---

  User? get currentUser => client.auth.currentUser;
  Session? get currentSession => client.auth.currentSession;
  bool get isAuthenticated => currentUser != null;

  Future<AuthResponse> signUp(String email, String password) async {
    return await client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // --- PROFILES ---

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<void> upsertProfile(String userId, String nickname) async {
    await client.from('profiles').upsert({
      'id': userId,
      'nickname': nickname,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // --- GROUPS & MEMBERS ---

  /// Generates a random 6-character uppercase alphanumeric code.
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<Map<String, dynamic>> createGroup(
    String name,
    String userId,
    String userNickname,
  ) async {
    // Generate unique code (attempts up to 5 times in case of collision)
    String inviteCode = _generateInviteCode();

    // Insert Group
    final groupData = await client
        .from('groups')
        .insert({
          'name': name,
          'invite_code': inviteCode,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    final String groupId = groupData['id'] as String;

    // Insert Creator into group_members
    await client.from('group_members').insert({
      'group_id': groupId,
      'user_id': userId,
      'nickname': userNickname,
      'joined_at': DateTime.now().toUtc().toIso8601String(),
    });

    return groupData;
  }

  Future<Map<String, dynamic>> joinGroup(
    String inviteCode,
    String userId,
    String userNickname,
  ) async {
    // 1. Find group by invite code
    final groupData = await client
        .from('groups')
        .select()
        .eq('invite_code', inviteCode.toUpperCase())
        .maybeSingle();

    if (groupData == null) {
      throw Exception('Group not found. Please check the 6-digit invite code.');
    }

    final String groupId = groupData['id'] as String;

    // Check if already a member
    final existingMember = await client
        .from('group_members')
        .select()
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existingMember == null) {
      // 2. Add member
      await client.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
        'nickname': userNickname,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    return groupData;
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    await client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> getJoinedGroups(String userId) async {
    // Query group_members for the user, and join the groups details
    final response = await client
        .from('group_members')
        .select('group_id, groups(id, name, invite_code, created_at)')
        .eq('user_id', userId);

    final list = <Map<String, dynamic>>[];
    for (final item in response) {
      if (item['groups'] != null) {
        list.add(item['groups'] as Map<String, dynamic>);
      }
    }
    return list;
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    final response = await client
        .from('group_members')
        .select('user_id, nickname, joined_at')
        .eq('group_id', groupId);

    return List<Map<String, dynamic>>.from(response);
  }

  // --- DOCUMENT UPDATES ---

  Future<List<Map<String, dynamic>>> getDocumentUpdates(
    String groupId,
    String noteId,
  ) async {
    final response = await client
        .from('document_updates')
        .select()
        .eq('group_id', groupId)
        .eq('note_id', noteId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> pushDocumentUpdate(
    String groupId,
    String noteId,
    String clientId,
    String updateBlobJson,
  ) async {
    await client.from('document_updates').insert({
      'group_id': groupId,
      'note_id': noteId,
      'client_id': clientId,
      'update_blob': updateBlobJson,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> deleteDocumentUpdates(String noteId) async {
    await client.from('document_updates').delete().eq('note_id', noteId);
  }

  // --- NOTES MANAGEMENT ---

  /// Returns notes for a group, pinned first then by updated_at desc.
  Future<List<Map<String, dynamic>>> getNotes(String groupId) async {
    final response = await client
        .from('notes')
        .select()
        .eq('group_id', groupId)
        .order('is_pinned', ascending: false)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createNote(String groupId, String title) async {
    final response = await client
        .from('notes')
        .insert({
          'group_id': groupId,
          'title': title,
          'snippet': 'No additional text',
          'is_pinned': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    return response;
  }

  Future<void> updateNoteMetadata(String noteId, String title, String snippet) async {
    await client
        .from('notes')
        .update({
          'title': title,
          'snippet': snippet,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', noteId);
  }

  Future<void> deleteNote(String noteId) async {
    await client.from('notes').delete().eq('id', noteId);
  }

  /// Toggles the is_pinned flag on a note.
  Future<void> toggleNotePin(String noteId, bool isPinned) async {
    await client
        .from('notes')
        .update({'is_pinned': isPinned})
        .eq('id', noteId);
  }

  // --- COMMENTS ---

  Future<List<Map<String, dynamic>>> getComments(String noteId) async {
    final response = await client
        .from('note_comments')
        .select()
        .eq('note_id', noteId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> addComment({
    required String noteId,
    required String groupId,
    required String userId,
    required String nickname,
    required String content,
    List<String> mentionedUsers = const [],
  }) async {
    final response = await client
        .from('note_comments')
        .insert({
          'note_id': noteId,
          'group_id': groupId,
          'user_id': userId,
          'nickname': nickname,
          'content': content,
          'mentioned_users': mentionedUsers,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    return response;
  }

  Future<void> deleteComment(String commentId) async {
    await client.from('note_comments').delete().eq('id', commentId);
  }
}
