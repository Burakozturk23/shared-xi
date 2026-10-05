import 'package:flutter/material.dart';
import 'app_preferences.dart';

/// Menu copy is local and works offline. Game/catalog content keeps its source language.
String appCopy(BuildContext context, String turkish, String english) =>
    PreferencesScope.maybeOf(context)?.languageCode == 'en' ? english : turkish;
