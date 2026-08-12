/// Haftanın gününe göre mücadele teması (PDF: Yaşayan Futbol Takvimi).
enum CalendarThemeKind {
  weekSummary, // Pazartesi–Salı
  europeNight, // Çarşamba–Perşembe
  derbyCountdown, // Cuma
  derbyDay, // Cumartesi–Pazar
}

class FootballCalendarTheme {
  final CalendarThemeKind kind;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final int roundSeconds;
  final int maxLives;
  final int targetFinds;

  const FootballCalendarTheme({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    this.roundSeconds = 60,
    this.maxLives = 3,
    this.targetFinds = 5,
  });

  static FootballCalendarTheme forDate(DateTime date) {
    // DateTime.weekday: 1=Mon ... 7=Sun
    switch (date.weekday) {
      case DateTime.monday:
      case DateTime.tuesday:
        return const FootballCalendarTheme(
          kind: CalendarThemeKind.weekSummary,
          title: 'Haftanın Özeti',
          subtitle: 'Günün Mücadelesi & ikonik eşleşmeler',
          badgeLabel: 'HAFTANIN ÖZETİ',
          roundSeconds: 90,
          maxLives: 5,
          targetFinds: 8,
        );
      case DateTime.wednesday:
      case DateTime.thursday:
        return const FootballCalendarTheme(
          kind: CalendarThemeKind.europeNight,
          title: 'Avrupa Gecesi',
          subtitle: 'Şampiyonlar Ligi & Avrupa kupaları özel modu',
          badgeLabel: 'AVRUPA GECESİ',
          roundSeconds: 60,
          maxLives: 3,
          targetFinds: 5,
        );
      case DateTime.friday:
        return const FootballCalendarTheme(
          kind: CalendarThemeKind.derbyCountdown,
          title: 'Derbiye Geri Sayım',
          subtitle: 'Hafta sonu derbisine özel iki takımda oynayanlar',
          badgeLabel: 'DERBİYE GERİ SAYIM',
          roundSeconds: 60,
          maxLives: 3,
          targetFinds: 5,
        );
      default:
        return const FootballCalendarTheme(
          kind: CalendarThemeKind.derbyDay,
          title: 'Derbi Günü',
          subtitle: 'Maç öncesi 60s yarışması',
          badgeLabel: 'DERBİ GÜNÜ',
          roundSeconds: 60,
          maxLives: 3,
          targetFinds: 5,
        );
    }
  }
}