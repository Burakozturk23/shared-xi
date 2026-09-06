import 'package:flutter/material.dart';

import '../models/safety_models.dart';
import '../services/safety_service.dart';

class PlayerSafetyActions {
  PlayerSafetyActions._();

  static Future<bool> report({
    required BuildContext context,
    required String targetUid,
    String? targetDisplayName,
    String sourceContext = 'other',
    String? modeId,
  }) async {
    final descriptionController = TextEditingController();
    var category = PlayerReportCategory.harassment;
    var submitting = false;
    String? errorText;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (submitting) return;

              setDialogState(() {
                submitting = true;
                errorText = null;
              });

              try {
                await SafetyService.reportPlayer(
                  targetUid: targetUid,
                  category: category,
                  description: descriptionController.text,
                  sourceContext: sourceContext,
                  modeId: modeId,
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (error) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  submitting = false;
                  errorText = _messageFor(error);
                });
              }
            }

            final target = targetDisplayName?.trim().isNotEmpty == true
                ? targetDisplayName!.trim()
                : 'bu oyuncu';

            return AlertDialog(
              title: const Text('Oyuncuyu Bildir'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '$target için bildirim nedeni seç.',
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<PlayerReportCategory>(
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: 'Neden',
                          border: OutlineInputBorder(),
                        ),
                        items: PlayerReportCategory.values
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item.title),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: submitting
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() => category = value);
                              },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descriptionController,
                        enabled: !submitting,
                        maxLength: 500,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Açıklama (isteğe bağlı)',
                          hintText:
                              'Kısa ve somut bir açıklama ekleyebilirsin.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Bildirimler oyuncu güvenliği içindir. '
                        'Oyun hataları ve öneriler Topluluk Merkezi üzerinden '
                        'gönderilmelidir.',
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton.icon(
                  onPressed: submitting ? null : submit,
                  icon: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.flag_outlined),
                  label: Text(submitting ? 'Gönderiliyor…' : 'Bildir'),
                ),
              ],
            );
          },
        );
      },
    );

    descriptionController.dispose();

    if (submitted == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bildirim alındı. Durumunu Güvenlik & Raporlar ekranından '
            'takip edebilirsin.',
          ),
        ),
      );
    }

    return submitted == true;
  }

  static Future<bool> confirmBlock({
    required BuildContext context,
    String? targetDisplayName,
  }) async {
    final target = targetDisplayName?.trim().isNotEmpty == true
        ? targetDisplayName!.trim()
        : 'Bu oyuncu';

    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Oyuncuyu Engelle'),
              content: Text(
                '$target engellendiğinde arkadaşlık ve bekleyen sosyal '
                'istekler kaldırılır. Yeni arkadaşlık veya maç daveti '
                'gönderemez.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Engelle'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  static String _messageFor(Object error) {
    final text = error.toString();

    if (text.contains('Google')) {
      return 'Oyuncu güvenliği için Google hesabına bağlı profil gerekli.';
    }
    if (text.toLowerCase().contains('rate') ||
        text.toLowerCase().contains('too many') ||
        text.toLowerCase().contains('cooldown')) {
      return 'Çok sık bildirim gönderildi. Bir süre sonra tekrar dene.';
    }
    if (text.toLowerCase().contains('self')) {
      return 'Kendi hesabını bildiremezsin.';
    }

    return 'Bildirim gönderilemedi. Bir süre sonra tekrar dene.';
  }
}
