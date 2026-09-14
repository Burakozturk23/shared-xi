import 'package:flutter/material.dart';
import 'app_shell.dart';

/// Stable welcome entry retained for existing routes and production smoke tools.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, this.observeAuth = true});
  final bool observeAuth;
  @override
  Widget build(BuildContext context) => AppShell(observeAuth: observeAuth);
}
