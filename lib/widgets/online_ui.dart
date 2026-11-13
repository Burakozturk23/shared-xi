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
    final text = Theme.of(context).textTheme;
    // One row: icon, title and rules, then the action this menu leads to.
    return Semantics(button: true, label: '${mode.title}. ${ranked ? 'Rakip eşleştirme' : 'Oda kur veya kodla katıl'}',
      excludeSemantics: true, child: Material(color: colors.surface, shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18), side: BorderSide(color: colors.border)), clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.fromLTRB(14, 14, 12, 14), child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: colors.tint,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: colors.border)),
          child: Icon(mode.icon, color: colors.accent, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(mode.title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(mode.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: colors.muted)),
        ])),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: colors.tint, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.accent.withValues(alpha: .5))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ranked ? Icons.public_rounded : Icons.key_rounded, size: 16, color: colors.accent),
            const SizedBox(width: 6),
            Text(ranked ? 'Eşleş' : 'Oda kur', style: text.labelLarge?.copyWith(color: colors.accent)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_rounded, size: 16, color: colors.accent),
          ])),
      ])))));
  }
}
