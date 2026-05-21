// lib/utils/navigation.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Returns a CupertinoPageRoute on iOS and MaterialPageRoute everywhere else.
/// Safely handles web (dart:io Platform is not available on web).
PageRoute<T> appRoute<T>(Widget screen) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return CupertinoPageRoute<T>(builder: (_) => screen);
  }
  return MaterialPageRoute<T>(builder: (_) => screen);
}
