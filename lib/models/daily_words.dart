String dailyWordKey(String s) {
  const groups = {
    'A': 'àáâãäåāăąÀÁÂÃÄÅĀĂĄ', 'C': 'çćčÇĆČ', 'D': 'ďđðĎĐÐ',
    'E': 'èéêëēėęěÈÉÊËĒĖĘĚ', 'G': 'ğĞ', 'I': 'ıİìíîïīÌÍÎÏĪ',
    'L': 'łŁ', 'N': 'ñńňÑŃŇ', 'O': 'òóôõöøōÒÓÔÕÖØŌ',
    'R': 'řŘ', 'S': 'şšśŞŠŚ', 'T': 'ťŤ', 'U': 'ùúûüūůÙÚÛÜŪŮ',
    'Y': 'ýÿÝŸ', 'Z': 'žźżŽŹŻ',
  };
  for (final entry in groups.entries) {
    for (final c in entry.value.split('')) { s = s.replaceAll(c, entry.key); }
  }
  return s.replaceAll(RegExp('[ßẞ]'), 'SS').replaceAll(RegExp('[æÆ]'), 'AE').replaceAll(RegExp('[œŒ]'), 'OE')
    .toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
}
String dailyWordsTitle(String mode) => switch (mode) {
  'daily_lingo' => 'Günün Lingo’su', 'passa_daily' => 'Mini Passaparola',
  'passa_weekly' => 'Haftalık Passaparola', _ => 'Günün Anagramı',
};
String dailyWordMark(String mark) => switch (mark) {
  'exact' => 'Doğru yerde', 'present' => 'Başka yerde', _ => 'Yok veya fazla',
};
/// Share text is built from public outcome counters, never names/letters/prompts.
String dailyWordsShare(Map<String, dynamic> session) {
  final mode = '${session['mode']}'; final result = Map<String, dynamic>.from(session['result'] as Map? ?? {});
  final rows = (session['rounds'] as List? ?? []).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  final summary = mode == 'daily_lingo'
    ? (session['guesses'] as List? ?? []).map((g) => (g['marks'] as List)
        .map((m) => m == 'exact' ? '🟩' : m == 'present' ? '🟨' : '⬛').join()).join('\n')
    : rows.map((r) => r['status'] == 'correct' ? '🟩' : r['status'] == 'pending' ? '⬜' : '⬛').join();
  return 'Linkball · ${dailyWordsTitle(mode)}\n${session['period']}\n$summary\n'
    '${result['medal'] ?? 'Tamamlandı'} · ${result['solved'] ?? 0} doğru'
    '${mode == 'daily_anagram' ? ' · ${session['score'] ?? 0}/300' : ''}'
    '${session['assisted'] == true || result['assisted'] == true ? ' · Yardımlı' : ''}';
}
