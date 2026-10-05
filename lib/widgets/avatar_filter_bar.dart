import 'package:flutter/material.dart';
import '../models/avatar_browser.dart';
import '../models/user_avatar_catalog.dart';

class AvatarFilterBar extends StatefulWidget {
  const AvatarFilterBar({super.key, required this.filter, required this.avatars,
    required this.resultCount, required this.onChanged, this.enabled = true});
  final AvatarBrowserFilter filter;
  final List<UserAvatarDefinition> avatars;
  final int resultCount;
  final ValueChanged<AvatarBrowserFilter> onChanged;
  final bool enabled;

  @override
  State<AvatarFilterBar> createState() => _AvatarFilterBarState();
}

class _AvatarFilterBarState extends State<AvatarFilterBar> {
  late final TextEditingController _search = TextEditingController(text: widget.filter.query);

  @override
  void didUpdateWidget(AvatarFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_search.text != widget.filter.query) _search.text = widget.filter.query;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('avatar-search'),
        controller: _search,
        enabled: widget.enabled,
        onChanged: (v) => widget.onChanged(widget.filter.copyWith(query: v)),
        decoration: InputDecoration(
          labelText: 'Avatar ara', hintText: 'İsim yaz: Messi, Ömer…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: widget.filter.query.isEmpty ? null : IconButton(
            tooltip: 'Aramayı temizle',
            onPressed: widget.enabled ? () => widget.onChanged(widget.filter.copyWith(query: '')) : null,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('avatar-category-${widget.filter.category}'),
        initialValue: widget.filter.category,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Kategori'),
        items: [for (final entry in avatarCategories.entries)
          DropdownMenuItem(value: entry.key, child: Text(
            '${entry.value} (${entry.key == 'all' ? widget.avatars.length : widget.avatars.where((a) => avatarCategory(a) == entry.key).length})',
            overflow: TextOverflow.ellipsis,
          )),
        ],
        onChanged: widget.enabled ? (v) => widget.onChanged(widget.filter.copyWith(category: v)) : null,
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final entry in const {
          AvatarOwnershipFilter.all: 'Tümü',
          AvatarOwnershipFilter.owned: 'Sahip olduklarım',
          AvatarOwnershipFilter.locked: 'Kilitli',
        }.entries)
          ChoiceChip(label: Text(entry.value),
            selected: widget.filter.ownership == entry.key,
            onSelected: widget.enabled ? (_) => widget.onChanged(widget.filter.copyWith(ownership: entry.key)) : null),
      ]),
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8, children: [
          Text('${widget.resultCount} avatar', key: const ValueKey('avatar-result-count'),
            style: Theme.of(context).textTheme.labelLarge),
          PopupMenuButton<AvatarSort>(
            tooltip: 'Avatarları sırala',
            enabled: widget.enabled,
            initialValue: widget.filter.sort,
            onSelected: (v) => widget.onChanged(widget.filter.copyWith(sort: v)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: AvatarSort.recommended, child: Text('Önerilen sıra')),
              PopupMenuItem(value: AvatarSort.name, child: Text('İsim A–Z')),
            ],
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.sort_rounded, size: 18), const SizedBox(width: 6),
              Text(widget.filter.sort == AvatarSort.name ? 'İsim A–Z' : 'Önerilen sıra'),
            ])),
          ),
          if (widget.filter.active) TextButton(
            onPressed: widget.enabled ? () => widget.onChanged(const AvatarBrowserFilter()) : null,
            child: const Text('Filtreleri temizle')),
        ],
      ),
    ],
  );
}
