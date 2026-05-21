// lib/screens/editor_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/editor_provider.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';

class EditorScreen extends StatelessWidget {
  final String groupId;
  final String noteId;
  final String groupName;
  final String userId;
  final String nickname;

  const EditorScreen({
    super.key,
    required this.groupId,
    required this.noteId,
    required this.groupName,
    required this.userId,
    required this.nickname,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false, // Let frosted AppBar extend to status bar
        child: ChangeNotifierProvider<EditorProvider>(
          create: (_) => EditorProvider(
            groupId: groupId,
            noteId: noteId,
            userId: userId,
            nickname: nickname,
          ),
          child: const _EditorScreenBody(),
        ),
      ),
    );
  }
}

class _EditorScreenBody extends StatefulWidget {
  const _EditorScreenBody();

  @override
  State<_EditorScreenBody> createState() => _EditorScreenBodyState();
}

class _EditorScreenBodyState extends State<_EditorScreenBody> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getAvatarColor(String name) {
    final hash = name.hashCode;
    final colors = [
      AppColors.styrianForest,
      const Color(0xFF2C5E7A),
      const Color(0xFF7A2C5E),
      const Color(0xFF7A5E2C),
      const Color(0xFF2C7A5E),
      const Color(0xFF5E2C7A),
    ];
    return colors[hash.abs() % colors.length];
  }

  Widget _buildCollaboratorAvatars(EditorProvider provider) {
    final list = provider.collaborators.values.toList();
    if (list.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < list.length; i++)
          Align(
            widthFactor: 0.65,
            child: Tooltip(
              message: '${list[i]['nickname']} — line ${list[i]['line'] ?? 1}',
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: _getAvatarColor(list[i]['nickname'] as String? ?? 'A'),
                  child: Text(
                    ((list[i]['nickname'] as String?) ?? 'A')[0].toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _deleteNote(BuildContext context, EditorProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Note?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.kaiserRed),
        ),
        content: Text(
          'This note will be permanently deleted. This cannot be undone.',
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

    if (confirm == true && context.mounted) {
      HapticFeedback.lightImpact();
      try {
        await SupabaseService().deleteNote(provider.noteId);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete note. Please try again.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();

    final wordCount = provider.controller.text.trim().isEmpty
        ? 0
        : provider.controller.text.trim().split(RegExp(r'\s+')).length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                // Subtle sage tint — visually distinct from the pure white canvas
                color: const Color(0xEEF4F8F5),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.styrianForest.withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 20),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                ),
                title: Text(
                  provider.noteTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                actions: [
                  _buildCollaboratorAvatars(provider),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: provider.isSynced ? 'All changes saved' : 'Tap to sync pending changes',
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        provider.syncPendingUpdates();
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: provider.isSynced
                              ? AppColors.glacierMint.withValues(alpha: 0.15)
                              : AppColors.borderGray.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: provider.isSynced ? AppColors.glacierMint : AppColors.borderGray,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: provider.isSynced ? AppColors.glacierMint : AppColors.textLight,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              provider.isSynced ? 'Saved' : 'Offline',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: provider.isSynced ? AppColors.styrianForest : AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteNote(context, provider);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, color: AppColors.kaiserRed, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              'Delete Note',
                              style: GoogleFonts.outfit(color: AppColors.kaiserRed, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.styrianForest))
          : Column(
              children: [
                // Document canvas — top padding accounts for AppBar + status bar
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        20,
                        MediaQuery.of(context).padding.top + kToolbarHeight + 20,
                        20,
                        32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hint: first line is the title
                          TextField(
                            controller: provider.controller,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              height: 1.65,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                              fillColor: Colors.transparent,
                              filled: false,
                              hintText: 'Title\n\nStart writing…',
                              hintStyle: GoogleFonts.outfit(
                                fontSize: 15,
                                height: 1.65,
                                color: AppColors.textLight.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Status bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_outline, size: 14, color: AppColors.textLight),
                          const SizedBox(width: 5),
                          Text(
                            '${provider.collaborators.length + 1} online',
                            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
                          ),
                        ],
                      ),
                      Text(
                        '$wordCount ${wordCount == 1 ? "word" : "words"}',
                        style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
