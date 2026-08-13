import 'package:flutter/material.dart';

import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';

/// Ortak oyuncu isim alanı.
///
/// - Autocomplete: tüm oyuncu havuzu
/// - Öneriye tıklanınca: [onPlayerSelected] varsa Player ile,
///   yoksa [onSubmitted] ile isim gönderilir (otomatik submit)
/// - Enter / done: [onSubmitted] ham metin
class PlayerNameField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final ValueChanged<Player>? onPlayerSelected;
  final Set<int> excludedPlayerIds;
  final bool showSuggestions;
  final bool submitOnSuggestionTap;

  const PlayerNameField({
    super.key,
    this.controller,
    this.labelText = 'Oyuncu adı',
    this.hintText = 'Örn. Suarez veya Luis Suarez',
    this.enabled = true,
    this.onSubmitted,
    this.onChanged,
    this.onPlayerSelected,
    this.excludedPlayerIds = const {},
    this.showSuggestions = true,
    this.submitOnSuggestionTap = true,
  });

  @override
  State<PlayerNameField> createState() => _PlayerNameFieldState();
}

class _PlayerNameFieldState extends State<PlayerNameField> {
  late final TextEditingController _controller;
  late final bool _ownsController;
  List<Player> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onText);
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onText() {
    final text = _controller.text;
    widget.onChanged?.call(text);
    if (!widget.showSuggestions) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    final list = SearchService.suggestions(
      players: Repository.instance.players,
      query: text,
      excludedPlayerIds: widget.excludedPlayerIds,
    );
    if (list != _suggestions) {
      setState(() => _suggestions = list);
    }
  }

  void _submit([String? value]) {
    final text = (value ?? _controller.text).trim();
    if (text.isEmpty) return;
    setState(() => _suggestions = const []);
    widget.onSubmitted?.call(text);
  }

  void _pick(Player player) {
    _controller.text = player.name;
    _controller.selection =
        TextSelection.collapsed(offset: player.name.length);
    setState(() => _suggestions = const []);
    widget.onChanged?.call(player.name);

    if (!widget.submitOnSuggestionTap) return;

    if (widget.onPlayerSelected != null) {
      widget.onPlayerSelected!(player);
      return;
    }

    widget.onSubmitted?.call(player.name);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          style: const TextStyle(color: AppTheme.textColor),
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
          ),
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _suggestions.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AppTheme.borderColor),
              itemBuilder: (context, i) {
                final p = _suggestions[i];
                return ListTile(
                  dense: true,
                  title: Text(
                    p.name,
                    style: const TextStyle(
                      color: AppTheme.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${p.position} • ${p.countryLabel}',
                    style: const TextStyle(
                      color: AppTheme.hintColor,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => _pick(p),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}