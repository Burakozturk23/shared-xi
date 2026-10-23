import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../online/online_mode_catalog.dart';
import '../theme/ortak_saha_theme.dart';
import 'pitch_ui.dart';

bool validRoomCode(String value) => RegExp(r'^[A-F0-9]{8}$').hasMatch(value.trim().toUpperCase());

class RoomCodeField extends StatelessWidget {
  const RoomCodeField({super.key, required this.controller, required this.onChanged, this.enabled = true});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, enabled: enabled, onChanged: onChanged,
    maxLength: 8, textCapitalization: TextCapitalization.characters, autocorrect: false,
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp('[a-fA-F0-9]')),
      TextInputFormatter.withFunction((oldValue, value) => value.copyWith(text: value.text.toUpperCase())),
    ],
    decoration: const InputDecoration(labelText: 'Oda kodu', hintText: 'Örn. A1B2C3D4',
      helperText: 'Aynı modu seç; 8 karakterli kodu gir veya yapıştır.', helperMaxLines: 3,
      prefixIcon: Icon(Icons.key_rounded)),
  );
}

class OnlineRoomCode extends StatelessWidget {
  const OnlineRoomCode({super.key, required this.code});
  final String code;
  @override
  Widget build(BuildContext context) => PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('ODA KODU', style: Theme.of(context).textTheme.labelLarge),
    const SizedBox(height: 8),
    SelectableText(code, textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: PitchColors.of(context).accent)),
    const SizedBox(height: 12),
    OutlinedButton.icon(icon: const Icon(Icons.copy_rounded), label: const Text('Oda kodunu kopyala'),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: code));
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oda kodu kopyalandı.')));
      }),
  ]));
}

class OnlineModeTile extends StatelessWidget {
  const OnlineModeTile({super.key, required this.mode, required this.ranked, required this.onTap});
  final OnlinePlayMode mode;
  final bool ranked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = PitchColors.of(context);
    return Material(color: colors.surface, shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20), side: BorderSide(color: colors.border)), clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: colors.tint,
              borderRadius: BorderRadius.circular(14)), child: Icon(mode.icon, color: colors.accent)),
            const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mode.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6), Text(mode.subtitle, style: TextStyle(color: colors.muted)),
            ])),
          ]),
          const SizedBox(height: 18),
          Row(children: [Icon(ranked ? Icons.public_rounded : Icons.key_rounded, size: 18, color: colors.accent),
            const SizedBox(width: 8), Expanded(child: Text(ranked ? 'Rakip eşleştirme' : 'Oda kur / kodla katıl',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.accent))),
            Icon(Icons.arrow_forward_rounded, size: 20, color: colors.accent)]),
        ]))));
  }
}
