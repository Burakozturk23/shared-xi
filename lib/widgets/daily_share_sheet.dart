import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'daily_share_card.dart';

Future<void> showDailyShareSheet(
  BuildContext context, {
  required String shareText,
  required Widget card,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sonucu paylaş',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Center(child: card),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Metni kopyala'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: shareText));
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Paylaşım metni panoya kopyalandı.'),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.text_snippet_outlined),
                  label: const Text('Metni önizle'),
                  onPressed: () {
                    showDialog<void>(
                      context: ctx,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Paylaşım metni'),
                        content: SelectableText(shareText),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx),
                            child: const Text('Kapat'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: shareText));
                              if (dCtx.mounted) Navigator.pop(dCtx);
                            },
                            child: const Text('Kopyala'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
