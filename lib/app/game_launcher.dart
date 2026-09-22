import 'package:flutter/material.dart';

import '../repositories/repository.dart';
import '../services/auth_service.dart';
import '../screens/sign_in_page.dart';
import 'app_feedback.dart';
import 'game_catalog.dart';
import 'route_appearance.dart';

class GameLauncher {
  static bool _preparing = false;

  static Future<void> open(BuildContext context, GameEntry entry) async {
    if (_preparing) return;
    _preparing = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (entry.requiresPersistentAccount &&
          !AuthService.hasPersistentAccount) {
        final signedIn = await Navigator.of(context).push<bool>(
          LinkballRoute(
            builder: (_) => const LinkballSignInPage(allowSkip: false),
            modern: false,
          ),
        );
        if (!context.mounted ||
            signedIn != true ||
            !AuthService.hasPersistentAccount) {
          return;
        }
      }
      final waits = <Future<void>>[];
      if (entry.requiresRepository && !Repository.instance.isInitialized) {
        waits.add(Repository.instance.initialize());
      }
      if (entry.requiresAuth) waits.add(AuthService.ensureSignedIn());
      if (waits.isNotEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            duration: Duration(minutes: 1),
            content: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Expanded(child: Text('Oyunun hazırlanıyor…')),
              ],
            ),
          ),
        );
        await Future.wait(waits);
        if (!context.mounted) return;
        messenger.hideCurrentSnackBar();
      }
      if (!context.mounted) return;
      AppFeedback.selection();
      final route = LinkballRoute<void>(
        builder: (_) => entry.page,
        modern: entry.modern,
      );
      // Only preparation is locked, not the entire lifetime of a game route.
      final result = Navigator.of(context).push(route);
      _preparing = false;
      await result;
    } catch (error, stack) {
      debugPrint('[GameLauncher] $error\n$stack');
      if (context.mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Oyun açılamadı. Bağlantını kontrol edip tekrar dene.',
            ),
          ),
        );
      }
    } finally {
      _preparing = false;
    }
  }
}
