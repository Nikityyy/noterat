// lib/widgets/formatting_toolbar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

class FormattingToolbar extends StatefulWidget {
  final QuillController controller;
  final FocusNode focusNode;

  const FormattingToolbar({super.key, required this.controller, required this.focusNode});

  @override
  State<FormattingToolbar> createState() => _FormattingToolbarState();
}

class _FormattingToolbarState extends State<FormattingToolbar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  bool _isActive(Attribute attribute) {
    final style = widget.controller.getSelectionStyle();
    if (attribute.key == Attribute.bold.key) {
      return style.attributes[Attribute.bold.key]?.value == true;
    }
    if (attribute.key == Attribute.italic.key) {
      return style.attributes[Attribute.italic.key]?.value == true;
    }
    if (attribute.key == Attribute.underline.key) {
      return style.attributes[Attribute.underline.key]?.value == true;
    }
    if (attribute.key == Attribute.strikeThrough.key) {
      return style.attributes[Attribute.strikeThrough.key]?.value == true;
    }
    if (attribute.key == Attribute.inlineCode.key) {
      return style.attributes[Attribute.inlineCode.key]?.value == true;
    }
    if (attribute.key == Attribute.h1.key) {
      return style.attributes[Attribute.header.key]?.value == 1;
    }
    if (attribute.key == Attribute.h2.key) {
      return style.attributes[Attribute.header.key]?.value == 2;
    }
    if (attribute.key == Attribute.ul.key) {
      return style.attributes[Attribute.list.key]?.value == 'bullet';
    }
    if (attribute.key == Attribute.ol.key) {
      return style.attributes[Attribute.list.key]?.value == 'ordered';
    }
    if (attribute.key == Attribute.checked.key) {
      final v = style.attributes[Attribute.list.key]?.value;
      return v == 'checked' || v == 'unchecked';
    }
    if (attribute.key == Attribute.blockQuote.key) {
      return style.attributes[Attribute.blockQuote.key]?.value == true;
    }
    if (attribute.key == Attribute.codeBlock.key) {
      return style.attributes[Attribute.codeBlock.key]?.value == true;
    }
    return false;
  }

  void _toggle(Attribute attribute) {
    HapticFeedback.selectionClick();
    final active = _isActive(attribute);
    if (active) {
      widget.controller.formatSelection(Attribute.clone(attribute, null));
    } else {
      widget.controller.formatSelection(attribute);
    }
    widget.focusNode.requestFocus();
  }

  void _toggleHeader(int level) {
    HapticFeedback.selectionClick();
    final style = widget.controller.getSelectionStyle();
    final current = style.attributes[Attribute.header.key]?.value;
    if (current == level) {
      widget.controller.formatSelection(Attribute.clone(Attribute.header, null));
    } else {
      widget.controller.formatSelection(HeaderAttribute(level: level));
    }
    widget.focusNode.requestFocus();
  }

  void _toggleList(String listType) {
    HapticFeedback.selectionClick();
    final style = widget.controller.getSelectionStyle();
    final current = style.attributes[Attribute.list.key]?.value;
    if (current == listType) {
      widget.controller.formatSelection(Attribute.clone(Attribute.list, null));
    } else {
      widget.controller.formatSelection(Attribute.fromKeyValue('list', listType));
    }
    widget.focusNode.requestFocus();
  }

  void _toggleChecklist() {
    HapticFeedback.selectionClick();
    final style = widget.controller.getSelectionStyle();
    final current = style.attributes[Attribute.list.key]?.value;
    if (current == 'checked' || current == 'unchecked') {
      widget.controller.formatSelection(Attribute.clone(Attribute.list, null));
    } else {
      widget.controller.formatSelection(Attribute.unchecked);
    }
    widget.focusNode.requestFocus();
  }

  void _indent() {
    HapticFeedback.selectionClick();
    widget.controller.indentSelection(true);
    widget.focusNode.requestFocus();
  }

  void _outdent() {
    HapticFeedback.selectionClick();
    widget.controller.indentSelection(false);
    widget.focusNode.requestFocus();
  }

  void _insertLink() {
    final selection = widget.controller.selection;
    final selectedText = widget.controller.document.getPlainText(
      selection.baseOffset,
      selection.extentOffset - selection.baseOffset,
    );

    final urlCtrl = TextEditingController();
    final textCtrl = TextEditingController(text: selectedText);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Insert Link', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textCtrl,
              decoration: InputDecoration(
                labelText: 'Display text',
                hintText: 'Link text',
                prefixIcon: const Icon(Icons.text_fields, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://',
                prefixIcon: const Icon(Icons.link, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlCtrl.text.trim();
              final text = textCtrl.text.trim();
              if (url.isNotEmpty) {
                // If no selection, insert the display text first.
                if (selection.isCollapsed && text.isNotEmpty) {
                  widget.controller.document.insert(selection.baseOffset, text);
                  widget.controller.updateSelection(
                    TextSelection(
                      baseOffset: selection.baseOffset,
                      extentOffset: selection.baseOffset + text.length,
                    ),
                    ChangeSource.local,
                  );
                }
                widget.controller.formatSelection(LinkAttribute(url));
              }
              widget.focusNode.requestFocus();
              Navigator.pop(ctx);
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  void _toggleHighlight() {
    HapticFeedback.selectionClick();
    final style = widget.controller.getSelectionStyle();
    final current = style.attributes[Attribute.background.key]?.value;
    if (current == '#FFF176') {
      widget.controller.formatSelection(Attribute.clone(Attribute.background, null));
    } else {
      widget.controller.formatSelection(BackgroundAttribute('#FFF176'));
    }
    widget.focusNode.requestFocus();
  }

  bool _isHighlightActive() {
    final style = widget.controller.getSelectionStyle();
    return style.attributes[Attribute.background.key]?.value == '#FFF176';
  }

  bool _isHeaderActive(int level) {
    final style = widget.controller.getSelectionStyle();
    return style.attributes[Attribute.header.key]?.value == level;
  }

  bool _isListActive(String listType) {
    final style = widget.controller.getSelectionStyle();
    return style.attributes[Attribute.list.key]?.value == listType;
  }

  bool _isChecklistActive() {
    final style = widget.controller.getSelectionStyle();
    final v = style.attributes[Attribute.list.key]?.value;
    return v == 'checked' || v == 'unchecked';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.borderGray;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bottomPadding = isKeyboardOpen ? 0.0 : 24.0;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: border, width: 0.5),
        ),
      ),
      child: SizedBox(
        height: 44,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _ToolbarButton(
              label: 'B',
              bold: true,
              isActive: _isActive(Attribute.bold),
              onTap: () => _toggle(Attribute.bold),
              tooltip: 'Bold',
            ),
            _ToolbarButton(
              label: 'I',
              italic: true,
              isActive: _isActive(Attribute.italic),
              onTap: () => _toggle(Attribute.italic),
              tooltip: 'Italic',
            ),
            _ToolbarButton(
              label: 'U',
              underline: true,
              isActive: _isActive(Attribute.underline),
              onTap: () => _toggle(Attribute.underline),
              tooltip: 'Underline',
            ),
            _ToolbarButton(
              label: 'S',
              strikethrough: true,
              isActive: _isActive(Attribute.strikeThrough),
              onTap: () => _toggle(Attribute.strikeThrough),
              tooltip: 'Strikethrough',
            ),
            _ToolbarDivider(),
            _ToolbarIconButton(
              icon: Icons.highlight,
              isActive: _isHighlightActive(),
              onTap: _toggleHighlight,
              tooltip: 'Highlight',
              activeColor: const Color(0xFFFFF176),
              activeIconColor: const Color(0xFF795548),
            ),
            _ToolbarIconButton(
              icon: Icons.link,
              isActive: false,
              onTap: _insertLink,
              tooltip: 'Insert Link',
            ),
            _ToolbarDivider(),
            _ToolbarButton(
              label: 'H1',
              isActive: _isHeaderActive(1),
              onTap: () => _toggleHeader(1),
              tooltip: 'Heading 1',
              fontSize: 11,
            ),
            _ToolbarButton(
              label: 'H2',
              isActive: _isHeaderActive(2),
              onTap: () => _toggleHeader(2),
              tooltip: 'Heading 2',
              fontSize: 11,
            ),
            _ToolbarDivider(),
            _ToolbarIconButton(
              icon: Icons.format_list_bulleted,
              isActive: _isListActive('bullet'),
              onTap: () => _toggleList('bullet'),
              tooltip: 'Bullet List',
            ),
            _ToolbarIconButton(
              icon: Icons.format_list_numbered,
              isActive: _isListActive('ordered'),
              onTap: () => _toggleList('ordered'),
              tooltip: 'Numbered List',
            ),
            _ToolbarIconButton(
              icon: Icons.checklist,
              isActive: _isChecklistActive(),
              onTap: _toggleChecklist,
              tooltip: 'Checklist',
            ),
            _ToolbarDivider(),
            _ToolbarIconButton(
              icon: Icons.format_quote,
              isActive: _isActive(Attribute.blockQuote),
              onTap: () => _toggle(Attribute.blockQuote),
              tooltip: 'Block Quote',
            ),
            _ToolbarIconButton(
              icon: Icons.code,
              isActive: _isActive(Attribute.inlineCode),
              onTap: () => _toggle(Attribute.inlineCode),
              tooltip: 'Inline Code',
            ),
            _ToolbarDivider(),
            _ToolbarIconButton(
              icon: Icons.format_indent_increase,
              isActive: false,
              onTap: _indent,
              tooltip: 'Indent',
            ),
            _ToolbarIconButton(
              icon: Icons.format_indent_decrease,
              isActive: false,
              onTap: _outdent,
              tooltip: 'Outdent',
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _ToolbarButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final double fontSize;

  const _ToolbarButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.tooltip,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.styrianForestDark : AppColors.styrianForest;
    final bg = isActive ? activeColor.withValues(alpha: 0.12) : Colors.transparent;
    final fg = isActive ? activeColor : (isDark ? AppColors.darkTextSecondary : AppColors.textLight);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              decoration: underline
                  ? TextDecoration.underline
                  : strikethrough
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;
  final Color? activeColor;
  final Color? activeIconColor;

  const _ToolbarIconButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.tooltip,
    this.activeColor,
    this.activeIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.styrianForestDark : AppColors.styrianForest;
    final bg = isActive ? (activeColor ?? green.withValues(alpha: 0.12)) : Colors.transparent;
    final fg = isActive
        ? (activeIconColor ?? green)
        : (isDark ? AppColors.darkTextSecondary : AppColors.textLight);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: fg),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      color: isDark ? AppColors.darkBorder : AppColors.borderGray,
    );
  }
}
