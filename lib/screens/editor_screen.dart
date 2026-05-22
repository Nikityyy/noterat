// lib/screens/editor_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/editor_provider.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../widgets/formatting_toolbar.dart';
import 'comments_screen.dart';

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
    return ChangeNotifierProvider<EditorProvider>(
      create: (_) => EditorProvider(
        groupId: groupId,
        noteId: noteId,
        userId: userId,
        nickname: nickname,
      ),
      child: _EditorBody(
        groupId: groupId,
        noteId: noteId,
        userId: userId,
        nickname: nickname,
      ),
    );
  }
}

class _EditorBody extends StatefulWidget {
  final String groupId;
  final String noteId;
  final String userId;
  final String nickname;

  const _EditorBody({
    required this.groupId,
    required this.noteId,
    required this.userId,
    required this.nickname,
  });

  @override
  State<_EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends State<_EditorBody> {
  final FocusNode _editorFocusNode = FocusNode();

  @override
  void dispose() {
    _editorFocusNode.dispose();
    super.dispose();
  }

  Color _avatarColor(String name) {
    const colors = [
      AppColors.styrianForest,
      Color(0xFF2C5E7A),
      Color(0xFF7A2C5E),
      Color(0xFF7A5E2C),
      Color(0xFF2C7A5E),
      Color(0xFF5E2C7A),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  Widget _collaboratorAvatars(EditorProvider p) {
    final list = p.collaborators.values.toList();
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
                  backgroundColor: _avatarColor(list[i]['nickname'] as String? ?? 'A'),
                  child: Text(
                    ((list[i]['nickname'] as String?) ?? 'A')[0].toUpperCase(),
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _deleteNote(BuildContext context, EditorProvider p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Note?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.kaiserRed)),
        content: Text('This note will be permanently deleted. This cannot be undone.', style: GoogleFonts.outfit()),
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
    if (ok == true && context.mounted) {
      HapticFeedback.lightImpact();
      try {
        await SupabaseService().deleteNote(p.noteId);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note deleted')));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete note.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EditorProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      floatingActionButton: p.isLoading
          ? null
          : FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.styrianForest,
              foregroundColor: Colors.white,
              tooltip: 'Comments',
              onPressed: () {
                HapticFeedback.lightImpact();
                showCommentsSheet(context, p.noteId, p.groupId, p.userId, p.nickname);
              },
              child: const Icon(Icons.chat_bubble_outline, size: 20),
            ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBackground.withValues(alpha: 0.9)
                    : const Color(0xEEF4F8F5),
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
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
                ),
                title: Text(
                  p.noteTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 17),
                ),
                actions: [
                  _collaboratorAvatars(p),
                  const SizedBox(width: 4),
                  // Sync status pill
                  Tooltip(
                    message: p.isSynced ? 'All changes saved' : 'Tap to sync',
                    child: GestureDetector(
                      onTap: () { HapticFeedback.lightImpact(); p.syncPendingUpdates(); },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.isSynced
                              ? AppColors.glacierMint.withValues(alpha: 0.15)
                              : AppColors.borderGray.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: p.isSynced ? AppColors.glacierMint : AppColors.borderGray,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.isSynced ? AppColors.glacierMint : AppColors.textLight,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            p.isSynced ? 'Saved' : 'Offline',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: p.isSynced ? AppColors.styrianForest : AppColors.textLight,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) {
                      if (v == 'pin') {
                        HapticFeedback.lightImpact();
                        p.togglePin();
                      } else if (v == 'delete') {
                        _deleteNote(context, p);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: Row(children: [
                          Icon(
                            p.isNotePinned ? Icons.push_pin : Icons.push_pin_outlined,
                            color: AppColors.styrianForest,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            p.isNotePinned ? 'Unpin Note' : 'Pin Note',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                          ),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          const Icon(Icons.delete_outline, color: AppColors.kaiserRed, size: 18),
                          const SizedBox(width: 10),
                          Text('Delete Note', style: GoogleFonts.outfit(color: AppColors.kaiserRed, fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: p.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.styrianForest))
          : Column(
              children: [
                // Quill editor canvas
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top + kToolbarHeight + 20,
                      20,
                      0,
                    ),
                    child: QuillEditor(
                      focusNode: _editorFocusNode,
                      scrollController: ScrollController(),
                      controller: p.quillController,
                      config: QuillEditorConfig(
                        onTapOutside: (event, focusNode) {
                          // Prevent keyboard from closing when tapping the formatting toolbar
                        },
                        padding: const EdgeInsets.only(bottom: 80),
                        placeholder: 'Title... Start writing...',
                      autoFocus: false,
                      expands: true,
                      scrollable: true,
                      customStyles: DefaultStyles(
                        paragraph: DefaultTextBlockStyle(
                          GoogleFonts.outfit(
                            fontSize: 15,
                            height: 1.65,
                            color: isDark ? AppColors.darkText : AppColors.textDark,
                          ),
                          const HorizontalSpacing(0, 0),
                          const VerticalSpacing(4, 4),
                          const VerticalSpacing(0, 0),
                          null,
                        ),
                        h1: DefaultTextBlockStyle(
                          GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                            color: isDark ? AppColors.darkText : AppColors.textDark,
                          ),
                          const HorizontalSpacing(0, 0),
                          const VerticalSpacing(8, 4),
                          const VerticalSpacing(0, 0),
                          null,
                        ),
                        h2: DefaultTextBlockStyle(
                          GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            color: isDark ? AppColors.darkText : AppColors.textDark,
                          ),
                          const HorizontalSpacing(0, 0),
                          const VerticalSpacing(6, 4),
                          const VerticalSpacing(0, 0),
                          null,
                        ),
                      ),
                      onLaunchUrl: (url) async {
                        final uri = Uri.tryParse(url);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                ),
              ),

                // Formatting toolbar (slides up with the keyboard)
                SafeArea(
                  top: false,
                  child: FormattingToolbar(
                    controller: p.quillController,
                    focusNode: _editorFocusNode,
                  ),
                ),
              ],
            ),
    );
  }
}
