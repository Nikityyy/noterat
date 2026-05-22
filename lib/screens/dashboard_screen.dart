// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../utils/navigation.dart';
import 'group_settings_screen.dart';
import 'notes_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshGroups();
  }

  Future<void> _refreshGroups() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        final list = await _supabaseService.getJoinedGroups(auth.user!.id);
        if (!mounted) return;
        setState(() => _groups = list);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Could not load workspaces. Pull down to refresh.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _confirmLogout(AuthProvider auth) async {
    HapticFeedback.lightImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Log Out?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      auth.logout();
    }
  }

  void _showCreateGroupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'New Workspace',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Workspace name',
            hintText: 'e.g. Product Team',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                HapticFeedback.lightImpact();
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  final auth = context.read<AuthProvider>();
                  await _supabaseService.createGroup(name, auth.user!.id, auth.nickname ?? 'User');
                  if (!mounted) return;
                  _refreshGroups();
                } catch (e) {
                  if (!mounted) return;
                  _showError('Could not create workspace. Please try again.');
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Join a Workspace',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: '6-digit invite code',
                hintText: 'e.g. X8J9A4',
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(6)],
            ),
            const SizedBox(height: 16),
            Text(
              'or',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textLight),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openQRScanner();
                },
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Scan QR Code'),
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
            onPressed: () async {
              final code = controller.text.trim().toUpperCase();
              if (code.length == 6) {
                HapticFeedback.lightImpact();
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  final auth = context.read<AuthProvider>();
                  await _supabaseService.joinGroup(code, auth.user!.id, auth.nickname ?? 'User');
                  if (!mounted) return;
                  _refreshGroups();
                } catch (e) {
                  if (!mounted) return;
                  _showError('Invalid code or workspace not found.');
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _openQRScanner() {
    Navigator.of(context).push(
      appRoute(
        Scaffold(
          appBar: AppBar(
            title: Text(
              'Scan Invite Code',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: AppColors.styrianForest,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: MobileScanner(
            onDetect: (capture) async {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final code = barcode.rawValue?.trim().toUpperCase();
                if (code != null && code.length == 6) {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    final auth = context.read<AuthProvider>();
                    await _supabaseService.joinGroup(code, auth.user!.id, auth.nickname ?? 'User');
                    if (!mounted) return;
                    _refreshGroups();
                  } catch (e) {
                    if (!mounted) return;
                    _showError('Could not join workspace from QR code.');
                    setState(() => _isLoading = false);
                  }
                  break;
                }
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Noterat',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: AppColors.styrianForest,
              ),
            ),
            if (auth.nickname != null)
              Text(
                'Hi, ${auth.nickname}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log Out',
              onPressed: () => _confirmLogout(auth),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshGroups,
        color: AppColors.styrianForest,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.styrianForest),
              )
            : _groups.isEmpty
                ? _buildEmptyState()
                : _buildGroupsList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showActionSheet();
        },
        backgroundColor: AppColors.styrianForest,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
    );
  }

  void _showActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.styrianForest.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, color: AppColors.styrianForest, size: 20),
                ),
                title: Text(
                  'Create Workspace',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  'Start a new shared workspace',
                  style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textLight),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateGroupDialog();
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.styrianForest.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.group_add_outlined, color: AppColors.styrianForest, size: 20),
                ),
                title: Text(
                  'Join Workspace',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  'Enter an invite code',
                  style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textLight),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showJoinGroupDialog();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.steelLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: const Icon(Icons.workspaces_outlined, size: 32, color: AppColors.textLight),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'No Workspaces Yet',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Create a workspace to start writing with others, or join one using an invite code.',
          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textLight, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        Center(
          child: ElevatedButton.icon(
            onPressed: _showActionSheet,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Your First Workspace'),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupsList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        final groupId = group['id'] as String;
        final groupName = group['name'] as String;
        final inviteCode = group['invite_code'] as String;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.styrianForest.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.folder_outlined, color: AppColors.styrianForest, size: 22),
            ),
            title: Text(
              groupName,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Text(
              'Tap to open',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: AppColors.textLight, size: 20),
                  tooltip: 'Workspace settings',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      appRoute(GroupSettingsScreen(
                        groupId: groupId,
                        groupName: groupName,
                        inviteCode: inviteCode,
                      )),
                    ).then((_) => _refreshGroups());
                  },
                ),
                const Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
              ],
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                appRoute(NotesListScreen(groupId: groupId, groupName: groupName)),
              );
            },
          ),
        );
      },
    );
  }
}
