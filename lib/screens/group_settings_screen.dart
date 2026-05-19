// lib/screens/group_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
      setState(() {
        _members = list;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load members: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveGroup() async {
    HapticFeedback.lightImpact();
    final auth = context.read<AuthProvider>();
    
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.glacialWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: AppColors.borderGray, width: 1.0),
        ),
        title: Text(
          'Leave Group?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.kaiserRed),
        ),
        content: Text(
          'Are you sure you want to leave ${widget.groupName}? You will lose access to its collaborative notes.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.kaiserRed),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Left ${widget.groupName}')),
          );
          Navigator.pop(context); // Go back to dashboard
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to leave group: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.glacialWhite,
      appBar: AppBar(
        backgroundColor: AppColors.glacialWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Group Settings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.styrianForest),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.styrianForest),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.styrianForest))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group Name Card
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      key: const ValueKey('group_info_card'),
                      child: Row(
                        children: [
                          const Icon(Icons.cabin, size: 28, color: AppColors.styrianForest),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.groupName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  'Collaborative Workspace',
                                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Invite Code Label
                  Text(
                    'INVITATION DETAILS',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Invite Code Box + Copy
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: AppColors.steelLight,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: AppColors.borderGray, width: 1.0),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Share the code below with your peers:',
                          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textLight),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(color: AppColors.borderGray, width: 1.0),
                              ),
                              child: Text(
                                widget.inviteCode,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                  color: AppColors.styrianForest,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.copy, color: AppColors.styrianForest),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Clipboard.setData(ClipboardData(text: widget.inviteCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invite code copied to clipboard!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            )
                          ],
                        ),
                        const SizedBox(height: 20),
                        // QR Code Container
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: AppColors.borderGray, width: 1.0),
                          ),
                          child: QrImageView(
                            data: widget.inviteCode,
                            version: QrVersions.auto,
                            size: 160.0,
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppColors.styrianForest,
                            ),
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AppColors.styrianForest,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan QR code to join',
                          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Members Section
                  Text(
                    'CABIN MEMBERS (${_members.length})',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Members List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final name = member['nickname'] as String;
                      final joinedAt = DateTime.parse(member['joined_at'] as String);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.person_outline, color: AppColors.styrianForest),
                          title: Text(
                            name,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Joined: ${joinedAt.day}/${joinedAt.month}/${joinedAt.year}',
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textLight),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 36),

                  // Leave Group Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.kaiserRed,
                        side: const BorderSide(color: AppColors.kaiserRed, width: 1.0),
                      ),
                      onPressed: _leaveGroup,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.exit_to_app),
                          SizedBox(width: 8),
                          Text('Leave Cabin Group'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
