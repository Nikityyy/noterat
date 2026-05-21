// lib/screens/group_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';

class GroupSettingsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String inviteCode;

  const GroupSettingsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.inviteCode,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoading = true);
    try {
      final list = await _supabaseService.getGroupMembers(widget.groupId);
      if (!mounted) return;
      setState(() => _members = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load members.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveGroup() async {
    HapticFeedback.lightImpact();
    final auth = context.read<AuthProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Leave Workspace?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.kaiserRed),
        ),
        content: Text(
          'You will lose access to "${widget.groupName}" and all its notes.',
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
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _supabaseService.leaveGroup(widget.groupId, auth.user!.id);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Left "${widget.groupName}"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not leave workspace. Please try again.')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _copyInviteCode() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: widget.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied!')),
    );
  }

  void _shareInviteCode() {
    HapticFeedback.lightImpact();
    Share.share(
      'Join my workspace on Noterat using code: ${widget.inviteCode}',
      subject: 'Noterat Invite — ${widget.groupName}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Workspace Info',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.styrianForest))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Workspace name card
                  _buildSectionCard(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.styrianForest.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(Icons.folder_outlined, color: AppColors.styrianForest, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.groupName,
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Shared workspace',
                                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section: Invite
                  _buildSectionLabel('INVITE'),
                  const SizedBox(height: 10),

                  _buildSectionCard(
                    child: Column(
                      children: [
                        Text(
                          'Share this code with anyone you want to invite:',
                          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textLight),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Invite code display
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.styrianForest.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.styrianForest.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            widget.inviteCode,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 6.0,
                              color: AppColors.styrianForest,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Copy + Share row
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _copyInviteCode,
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _shareInviteCode,
                                icon: const Icon(Icons.share_outlined, size: 16),
                                label: const Text('Share'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // QR code — modern rounded style
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderGray),
                          ),
                          child: QrImageView(
                            data: widget.inviteCode,
                            version: QrVersions.auto,
                            size: 160.0,
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.circle,
                              color: AppColors.styrianForest,
                            ),
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.circle,
                              color: AppColors.styrianForest,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan to join this workspace',
                          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section: Members
                  _buildSectionLabel('MEMBERS (${_members.length})'),
                  const SizedBox(height: 10),

                  _buildSectionCard(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _members.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Theme.of(context).dividerColor,
                      ),
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final name = member['nickname'] as String;
                        final joinedAt = DateTime.parse(member['joined_at'] as String);
                        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.styrianForest.withValues(alpha: 0.1),
                                child: Text(
                                  initial,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.styrianForest,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Joined ${joinedAt.day}/${joinedAt.month}/${joinedAt.year}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Leave workspace
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.kaiserRed,
                        side: const BorderSide(color: AppColors.kaiserRed, width: 1.0),
                      ),
                      onPressed: _leaveGroup,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Leave Workspace'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: AppColors.textLight,
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: child,
    );
  }
}
