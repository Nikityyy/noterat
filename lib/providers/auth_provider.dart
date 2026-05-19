// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

enum AuthStatus {
  uninitialized,
  authenticating,
  authenticated,
  unauthenticated,
  needsProfile, // User exists in auth but lacks nickname in profiles
  error,
}

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  
  AuthStatus _status = AuthStatus.uninitialized;
  String? _errorMessage;
  String? _nickname;
  
  // Registration flow state cache (Page 1-4)
  String email = '';
  String password = '';
  String confirmPassword = '';
  String tempNickname = '';

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get nickname => _nickname;
  User? get user => _supabaseService.currentUser;

  AuthProvider() {
    _init();
  }

  void _init() {
    // Listen to Supabase auth state changes
    SupabaseService.client.auth.onAuthStateChange.listen((data) async {
      final Session? session = data.session;
      if (session == null) {
        _status = AuthStatus.unauthenticated;
        _nickname = null;
        notifyListeners();
      } else {
        await checkProfile(session.user.id);
      }
    });
  }

  Future<void> checkProfile(String userId) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await _supabaseService.getProfile(userId);
      if (profile != null && profile['nickname'] != null) {
        _nickname = profile['nickname'] as String;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.needsProfile;
      }
    } catch (e) {
      _errorMessage = _getCleanErrorMessage(e);
      _status = AuthStatus.error;
    }
    notifyListeners();
  }

  Future<bool> registerUser() async {
    if (password != confirmPassword) {
      _errorMessage = 'Passwords do not match.';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }

    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabaseService.signUp(email, password);
      // SignUp success triggers the authStateChange or continues setup
      return true;
    } catch (e) {
      _errorMessage = _getCleanErrorMessage(e);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginUser(String loginEmail, String loginPassword) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabaseService.signIn(loginEmail, loginPassword);
      return true;
    } catch (e) {
      _errorMessage = _getCleanErrorMessage(e);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeProfileSetup() async {
    final currentUser = user;
    if (currentUser == null) {
      _errorMessage = 'No active user found.';
      notifyListeners();
      return false;
    }

    if (tempNickname.trim().isEmpty) {
      _errorMessage = 'Nickname cannot be empty.';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.authenticating;
    notifyListeners();

    try {
      await _supabaseService.upsertProfile(currentUser.id, tempNickname.trim());
      _nickname = tempNickname.trim();
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _getCleanErrorMessage(e);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _supabaseService.signOut();
    _status = AuthStatus.unauthenticated;
    _nickname = null;
    email = '';
    password = '';
    confirmPassword = '';
    tempNickname = '';
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _getCleanErrorMessage(dynamic e) {
    if (e is AuthException) {
      final code = e.code?.toLowerCase() ?? '';
      final message = e.message.toLowerCase();
      
      if (code == 'invalid_credentials' || 
          message.contains('invalid login credentials') ||
          message.contains('invalid credentials')) {
        return 'Invalid email or password.';
      }
      if (code == 'email_exists' || 
          message.contains('email already exists') || 
          message.contains('already registered') ||
          message.contains('already exists')) {
        return 'An account with this email already exists.';
      }
      if (code == 'weak_password' || 
          message.contains('password should be at least')) {
        return 'Password is too weak. Please use a stronger password.';
      }
      if (code == 'over_email_send_rate_limit' || 
          message.contains('email send limit') ||
          message.contains('too many requests')) {
        return 'Too many requests. Please try again in a few minutes.';
      }
      return e.message;
    }
    
    if (e is PostgrestException) {
      return e.message;
    }
    
    final str = e.toString();
    if (str.contains('SocketException') || str.contains('Failed host lookup')) {
      return 'Network connection error. Please check your internet connection.';
    }
    
    if (str.startsWith('Exception: ')) {
      return str.substring(11);
    }
    
    return str;
  }
}
