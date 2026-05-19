// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
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
        setState(() {
          _groups = list;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load groups: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCreateGroupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.glacialWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: AppColors.borderGray, width: 1.0),
        ),
        title: Text(
          'Create a Cabin Group',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.styrianForest),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            hintText: 'e.g. Styrian Expedition',
          ),
        ),
        actions: [
          OutlinedButton(
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
                  await _supabaseService.createGroup(name, auth.user!.id, auth.nickname ?? 'Alpinist');
                  if (!mounted) return;
                  _refreshGroups();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create group: $e')),
                  );
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
        backgroundColor: AppColors.glacialWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: AppColors.borderGray, width: 1.0),
        ),
        title: Text(
          'Join a Cabin Group',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.styrianForest),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: '6-Digit Invite Code',
                hintText: 'e.g. X8J9A4',
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(6),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'OR',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openQRScanner();
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR Code'),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
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
                  await _supabaseService.joinGroup(code, auth.user!.id, auth.nickname ?? 'Alpinist');
                  if (!mounted) return;
                  _refreshGroups();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
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
      MaterialPageRoute(
        builder: (scannerCtx) => Scaffold(
          appBar: AppBar(
            title: Text(
              'Scan Invite QR',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: AppColors.styrianForest,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(scannerCtx),
            ),
          ),
          body: MobileScanner(
            onDetect: (capture) async {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final code = barcode.rawValue?.trim().toUpperCase();
                if (code != null && code.length == 6) {
                  HapticFeedback.lightImpact();
                  Navigator.pop(scannerCtx); // Close scanner screen
                  
                  setState(() => _isLoading = true);
                  try {
                    final auth = context.read<AuthProvider>();
                    await _supabaseService.joinGroup(code, auth.user!.id, auth.nickname ?? 'Alpinist');
                    if (!mounted) return;
                    _refreshGroups();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to join group from QR: $e')),
                    );
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
      backgroundColor: AppColors.glacialWhite,
      appBar: AppBar(
        backgroundColor: AppColors.glacialWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: AppColors.styrianForest,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.person, size: 14, color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(
                  auth.nickname ?? 'Alpinist',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.styrianForest),
            onPressed: () {
              HapticFeedback.lightImpact();
              auth.logout();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshGroups,
        color: AppColors.styrianForest,
        backgroundColor: Colors.white,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.styrianForest))
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
      ),
    );
  }

  void _showActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.glacialWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined, color: AppColors.styrianForest),
                title: Text(
                  'Create a New Group',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateGroupDialog();
                },
              ),
              const Divider(color: AppColors.borderGray, height: 1),
              ListTile(
                leading: const Icon(Icons.group_add_outlined, color: AppColors.styrianForest),
                title: Text(
                  'Join Existing Group',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showJoinGroupDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Icon(
          Icons.landscape_outlined,
          size: 80,
          color: AppColors.borderGray,
        ),
        const SizedBox(height: 16),
        Text(
          'Your Cabin is Empty',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Text(
            'Create a group to start collaborative text editing or join a friend\'s cabin group.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupsList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        final groupId = group['id'] as String;
        final groupName = group['name'] as String;
        final inviteCode = group['invite_code'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const CircleAvatar(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.styrianForest,
              radius: 20,
              child: Icon(Icons.cabin),
            ),
            title: Text(
              groupName,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Row(
              children: [
                Text(
                  'Code: ',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
                ),
                Text(
                  inviteCode,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.styrianForest,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.settings, color: AppColors.textLight),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupSettingsScreen(
                          groupId: groupId,
                          groupName: groupName,
                          inviteCode: inviteCode,
                        ),
                      ),
                    ).then((_) => _refreshGroups());
                  },
                ),
                const Icon(Icons.chevron_right, color: AppColors.textLight),
              ],
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotesListScreen(
                    groupId: groupId,
                    groupName: groupName,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
