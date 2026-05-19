// lib/screens/editor_screen.dart

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
      backgroundColor: AppColors.glacialWhite,
      body: SafeArea(
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
  int _lineCount = 1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateLineCount(String text) {
    final count = '\n'.allMatches(text).length + 1;
    if (count != _lineCount) {
      setState(() {
        _lineCount = count;
      });
    }
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

  Widget _buildHeaderCollaborators(EditorProvider provider) {
    final list = provider.collaborators.values.toList();
    if (list.isEmpty) return const SizedBox.shrink();

    final List<Widget> avatars = [];
    for (int i = 0; i < list.length; i++) {
      final name = list[i]['nickname'] as String? ?? 'A';
      final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
      final color = _getAvatarColor(name);

      avatars.add(
        Align(
          widthFactor: 0.65, // Overlap
          child: Tooltip(
            message: '$name (Line ${list[i]['line'] ?? 1})',
            child: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.glacialWhite,
              child: CircleAvatar(
                radius: 13,
                backgroundColor: color,
                child: Text(
                  initial,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: avatars,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();

    // Update line count dynamically
    _updateLineCount(provider.controller.text);

    final charCount = provider.controller.text.length;
    final wordCount = provider.controller.text.trim().isEmpty
        ? 0
        : provider.controller.text.trim().split(RegExp(r'\s+')).length;

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
              provider.noteTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.styrianForest,
              ),
            ),
            Text(
              'Collaborative Cabin Note',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
        actions: [
          // Delete Note Button
          IconButton(
            tooltip: 'Delete Note',
            icon: const Icon(Icons.delete_outline, color: AppColors.kaiserRed),
            onPressed: () async {
              final confirm = await showDialog<bool>(
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
                    'Are you sure you want to permanently delete this note? This action cannot be undone and will close the editor.',
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

              if (confirm == true && context.mounted) {
                HapticFeedback.lightImpact();
                try {
                  final SupabaseService supabaseService = SupabaseService();
                  await supabaseService.deleteNote(provider.noteId);
                  if (context.mounted) {
                    Navigator.pop(context); // Close editor
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Note deleted')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete note: $e')),
                    );
                  }
                }
              }
            },
          ),
          const SizedBox(width: 4),

          // Overlapping avatars
          _buildHeaderCollaborators(provider),
          const SizedBox(width: 8),
          
          // Synced Pill
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              provider.syncPendingUpdates();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: provider.isSynced
                    ? AppColors.glacierMint.withValues(alpha: 0.15)
                    : AppColors.borderGray.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: provider.isSynced ? AppColors.glacierMint : AppColors.borderGray,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: provider.isSynced ? AppColors.glacierMint : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    provider.isSynced ? 'SYNCED' : 'OFFLINE',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: provider.isSynced ? AppColors.styrianForest : AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.styrianForest))
          : Column(
              children: [
                // Main Document Canvas
                Expanded(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      margin: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: AppColors.borderGray, width: 1.0),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11.0),
                        child: Scrollbar(
                          controller: _scrollController,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Line Numbers (Gutter)
                                Container(
                                  width: 45,
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: List.generate(_lineCount, (index) {
                                      return SizedBox(
                                        height: 24, // Matches TextField line height exactly
                                        child: Text(
                                          '${index + 1}',
                                          style: GoogleFonts.jetBrainsMono(
                                            color: AppColors.textLight.withValues(alpha: 0.5),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                                
                                // Vertical divider line separating gutter
                                Container(
                                  width: 1,
                                  height: _lineCount * 24.0,
                                  color: AppColors.borderGray,
                                ),
                                
                                // Main Writing Area
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: TextField(
                                      controller: provider.controller,
                                      maxLines: null,
                                      keyboardType: TextInputType.multiline,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        height: 1.71, // Matches 24px line height (14 * 1.714)
                                        color: AppColors.textDark,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        isDense: true,
                                        hintText: 'Start writing your collaborative thoughts here...',
                                      ),
                                      onChanged: (text) {
                                        _updateLineCount(text);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Info Bottom Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: AppColors.borderGray, width: 1.0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_outline, size: 16, color: AppColors.textLight),
                          const SizedBox(width: 6),
                          Text(
                            'PEERS: ${provider.collaborators.length + 1}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'WORDS: $wordCount  |  CHARS: $charCount',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
