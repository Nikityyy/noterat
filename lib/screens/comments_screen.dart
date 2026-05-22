// lib/screens/comments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/comments_provider.dart';
import '../theme/colors.dart';

void showCommentsSheet(
  BuildContext context,
  String noteId,
  String groupId,
  String userId,
  String nickname,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => CommentsProvider(
        noteId: noteId,
        groupId: groupId,
        userId: userId,
        nickname: nickname,
      ),
      child: const _CommentsSheet(),
    ),
  );
}

class _CommentsSheet extends StatelessWidget {
  const _CommentsSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, sc) => _CommentsBody(scrollCtrl: sc),
      ),
    );
  }
}

class _CommentsBody extends StatelessWidget {
  final ScrollController scrollCtrl;
  const _CommentsBody({required this.scrollCtrl});

  Color _avatarColor(String name) {
    const p = [
      AppColors.styrianForest,
      Color(0xFF2C5E7A),
      Color(0xFF7A2C5E),
      Color(0xFF7A5E2C),
      Color(0xFF2C7A5E),
      Color(0xFF5E2C7A),
    ];
    return p[name.hashCode.abs() % p.length];
  }

  @override
  Widget build(BuildContext context) {
    final pv = context.watch<CommentsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.borderGray;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(children: [
              const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.styrianForest),
              const SizedBox(width: 8),
              Text('Comments', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (pv.comments.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.styrianForest.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${pv.comments.length}',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.styrianForest, fontWeight: FontWeight.bold),
                  ),
                ),
            ]),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: pv.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.styrianForest))
                : pv.comments.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: pv.comments.length,
                        itemBuilder: (_, i) => _commentTile(context, pv.comments[i], pv),
                      ),
          ),
          // @ suggestion
          if (pv.showMentionSuggest) _mentionBar(context, pv),
          // Input
          _inputRow(context, pv, border),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.chat_bubble_outline, size: 40, color: AppColors.textLight.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('No comments yet', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textLight)),
          const SizedBox(height: 4),
          Text('Be the first to leave a comment.', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textLight)),
        ]),
      );

  Widget _commentTile(BuildContext context, Map<String, dynamic> c, CommentsProvider pv) {
    final name = c['nickname'] as String? ?? 'User';
    final content = c['content'] as String? ?? '';
    final ts = c['created_at'] as String? ?? '';
    final id = c['id'] as String;
    final isOwn = c['user_id'] == pv.userId;

    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: _avatarColor(name),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(name, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text(pv.formatTimestamp(ts), style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textLight)),
              if (isOwn) ...[
                const Spacer(),
                Text('You',
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold,
                        color: AppColors.styrianForest.withValues(alpha: 0.7))),
              ]
            ]),
            const SizedBox(height: 3),
            _richContent(content),
          ]),
        ),
      ]),
    );

    if (!isOwn) return tile;
    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(color: AppColors.kaiserRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.delete_outline, color: AppColors.kaiserRed, size: 20),
      ),
      confirmDismiss: (_) async { HapticFeedback.lightImpact(); return true; },
      onDismissed: (_) => pv.deleteComment(id),
      child: tile,
    );
  }

  Widget _richContent(String content) {
    final rx = RegExp(r'@(\w+)');
    if (!rx.hasMatch(content)) {
      return Text(content, style: GoogleFonts.outfit(fontSize: 14, height: 1.5, color: AppColors.textDark));
    }
    final spans = <InlineSpan>[];
    int last = 0;
    for (final m in rx.allMatches(content)) {
      if (m.start > last) {
        spans.add(TextSpan(text: content.substring(last, m.start),
            style: GoogleFonts.outfit(fontSize: 14, height: 1.5, color: AppColors.textDark)));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.styrianForest.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(m.group(0) ?? '',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.styrianForest)),
        ),
      ));
      last = m.end;
    }
    if (last < content.length) {
      spans.add(TextSpan(text: content.substring(last),
          style: GoogleFonts.outfit(fontSize: 14, height: 1.5, color: AppColors.textDark)));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _mentionBar(BuildContext context, CommentsProvider pv) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(maxHeight: 130),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.styrianForest.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: pv.mentionSuggestions.length,
        itemBuilder: (_, i) {
          final n = pv.mentionSuggestions[i];
          return InkWell(
            onTap: () { HapticFeedback.selectionClick(); pv.selectMention(n); },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.styrianForest.withValues(alpha: 0.12),
                  child: Text(n[0].toUpperCase(),
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.styrianForest)),
                ),
                const SizedBox(width: 8),
                Text('@$n', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.styrianForest)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _inputRow(BuildContext context, CommentsProvider pv, Color border) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border(top: BorderSide(color: border.withValues(alpha: 0.5))),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: pv.inputController,
              maxLines: 4,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.outfit(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Add a comment… type @ to mention',
                hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppColors.textLight),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.styrianForest, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceElevated : AppColors.steelLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); pv.addComment(); },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: AppColors.styrianForest, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    );
  }
}
