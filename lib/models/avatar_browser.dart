import '../services/search_service.dart';
import 'user_avatar_catalog.dart';

const avatarCategories = <String, String>{
  'all': 'Tüm kategoriler',
  'players': 'Futbolcular',
  'coaches': 'Teknik direktörler',
  'legends': 'Efsaneler',
  'creators': 'İçerik üreticileri',
  'friends': 'Özel avatarlar',
  'classic': 'Linkball',
};

String avatarCategory(UserAvatarDefinition avatar) =>
    avatar.visualKey.startsWith('persona_')
        ? avatar.visualKey.substring('persona_'.length)
        : 'classic';

enum AvatarOwnershipFilter { all, owned, locked }

enum AvatarSort { recommended, name }

class AvatarBrowserFilter {
  const AvatarBrowserFilter({
    this.query = '',
    this.category = 'all',
    this.ownership = AvatarOwnershipFilter.all,
    this.sort = AvatarSort.recommended,
  });

  final String query, category;
  final AvatarOwnershipFilter ownership;
  final AvatarSort sort;

  bool get active => query.isNotEmpty || category != 'all' ||
      ownership != AvatarOwnershipFilter.all || sort != AvatarSort.recommended;

  AvatarBrowserFilter copyWith({String? query, String? category,
    AvatarOwnershipFilter? ownership, AvatarSort? sort}) => AvatarBrowserFilter(
      query: query ?? this.query, category: category ?? this.category,
      ownership: ownership ?? this.ownership, sort: sort ?? this.sort);

  List<UserAvatarDefinition> apply(Iterable<UserAvatarDefinition> avatars,
      Set<String> owned, {String? selectedId}) {
    final tokens = SearchService.normalize(query).split(' ').where((s) => s.isNotEmpty);
    final result = avatars.where((a) {
      if (category != 'all' && avatarCategory(a) != category) return false;
      if (ownership == AvatarOwnershipFilter.owned && !owned.contains(a.id)) return false;
      if (ownership == AvatarOwnershipFilter.locked && owned.contains(a.id)) return false;
      final label = SearchService.normalize(a.title);
      return tokens.every(label.contains);
    }).toList();
    if (sort == AvatarSort.name) {
      result.sort((a, b) => SearchService.normalize(a.title).compareTo(SearchService.normalize(b.title)));
    } else if (selectedId != null) {
      final index = result.indexWhere((a) => a.id == selectedId);
      if (index > 0) result.insert(0, result.removeAt(index));
    }
    return result;
  }
}
