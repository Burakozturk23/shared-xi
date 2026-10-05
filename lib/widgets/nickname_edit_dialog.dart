import 'package:flutter/material.dart';
import '../services/nickname_service.dart';

class NicknameEditDialog extends StatefulWidget {
  const NicknameEditDialog({
    super.key,
    required this.initialName,
    required this.save,
  });
  final String initialName;
  final Future<void> Function(String) save;
  @override
  State<NicknameEditDialog> createState() => _NicknameEditDialogState();
}

class _NicknameEditDialogState extends State<NicknameEditDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(_controller.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is NicknameException
            ? error.message
            : 'Takma ad kaydedilemedi. Tekrar dene.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Takma adını düzenle'),
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          autofocus: true,
          enabled: !_saving,
          maxLength: NicknameService.maxLength,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'Takma ad',
            helperText: '3–16 karakter · harf, rakam ve _',
            helperMaxLines: 3,
            errorText: _error,
            errorMaxLines: 4,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
        ),
      ],
    ),
  );
}
