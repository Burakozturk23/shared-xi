# Ses paketi entegrasyonu — 27 Ekim 2026

Kaynak: `Linkball_SES_PAKETI_TAM_YENI_25EKIM2026.zip` (5 müzik, 23 efekt). Paketin 42 SHA-256 değeri doğrulandı; uygulamaya alınan 33 ses dosyası `docs/audio/SHA256SUMS.txt` ile birebir aynıdır. Önizleme MP3'leri uygulamaya alınmadı.

## Dosyalar

- `assets/audio/music/`: her müzik için Android/masaüstü döngüsü (`*_loop.ogg`) ve iOS/macOS/web için MP3. Platform seçimi `MusicTrack.asset` içindedir.
- `assets/audio/sfx/`: 23 WAV efekt (32 kHz, 16-bit mono).
- `docs/audio/`: paket eşlemesi, teknik kurallar, kaynak/lisans notu, doğrulama raporu ve bu belge.
- Bağımlılık: `audioplayers 6.8.1` (sabit sürüm).

## Mimari

`lib/app/game_audio.dart` içindeki `GameAudio` uygulama genelinde tek ses sahibidir:

- **Tek müzik:** `MusicScene` sarmalayıcısı açık olduğu sürece parçasını seçer. En içteki sahne kazanır, kapanınca bir öncekine dönülür. Parça değişiminde 0,7 sn fade uygulanır. Aynı parça devam ediyorsa yeniden başlatılmaz; yeniden çizim (rebuild) müziği sıfırlamaz. Story bölümleri arasında Kupa Anı V6 kaldığı yerden sürer.
- **Seviyeler:** varsayılan müzik %27, Story ×0,20/0,27, online bekleme odası yarım ses, efekt %55. Galibiyet, düdük, başarı ve seviye efektlerinde müzik 1,6 sn kısılır.
- **Efektler:** 3 sesli sabit havuz kullanılır, 4. katman açılmaz. Aynı efekt 120 ms içinde tekrar çalmaz. Online ve sunucu olayları kimlikle tekilleştirilir; tekrar gelen yoklama aynı sesi çalmaz.
- **Yaşam döngüsü:** uygulama arka plandayken ve ödüllü reklam ekrandayken müzik durur, dönüşte aynı parça devam eder. Android'de müzik ses odağı alır, bu yüzden arama gelince veya başka medya başlayınca müzik duraklar. Efektler odak almaz. iOS'te `ambient` kategorisi kullanılır, böylece sessiz mod tuşuna uyulur.
- **Tercihler:** Ayarlar'da *Oyun sesleri* (efekt) ve *Müzik* ayrı anahtarlardır, ikisinin de ayrı seviye kaydırıcısı vardır. Eski `linkball.sound` değeri efekt tercihi olarak aynen korunur. Müzik ilk açılışta bu eski değeri alır; sesi kapatmış bir kullanıcıya müzik kendiliğinden açılmaz.

## Müzik eşlemesi

| Sahne | Parça |
| --- | --- |
| Ana sekmeler, mağaza, profil, keşif, Botla Oyna menüsü, Günün Maçları listesi | M1 Neon Tribün V2.5 |
| Online/arkadaş bekleme ve eşleşme | M1 (yarım ses) |
| Story Mode, sekiz hikâye ailesi, koleksiyonlar, Oyuncu Yolculuğu | M2 Kupa Anı V6 |
| Solo bulmaca ve kelime modları, Günün Maçları bulmacası, Club Manager, Solo Grid | M3 Tactical Focus V2 |
| Burst, Higher or Lower, Zincir Sprinti, Sahte Kulüp Hız Serisi, bot Loto ve Takım Yarışı, online Loto ve Rastgele Beş | M4 Final Whistle Rush V2 |
| O mu Bu mu?, bot Grid/Çinko/Beşler, diğer online maçlar ve düellolar | M5 Neon Pas V3 |

## Efekt olayları

- Doğru/yanlış: oyunların mevcut `AppFeedback.answer` çağrıları (controller veya sunucu onayından sonra), online hamle makbuzu, bot ve Grid tahmin sonuçları.
- `hint_reveal_soft`: ücretli yardım yalnız sunucu yeni oturumu döndürdükten sonra çalar; başarısız ödeme sessiz kalır.
- `coin_reward` ve `level_up`: görev, günlük giriş, başarım ve sezon ödülü sunucu tarafından verildikten sonra çalar. İpucu harcamasında Coin sesi çalmaz.
- `match_start`, `online_opponent_join`, `champion`/`whistle`, `connection_alert_soft`: bot/Grid/online oturum olayları. Bağlantı uyarısı yalnız aktif odanın gerçek kopuşunda bir kez çalar.
- `slot_lock`, `round_transition`, `perfect_combo`, `card_flip`, `coach_roulette_short`, `card_swipe`, `goal`, `countdown`: Loto/Çinko/Grid yerleştirme, tur geçişi, Matching kartları, Hoca 11/Harf 11/Kasa ruleti, Club Manager maç sonucu ve Loto saatinin son 5, 3 ve 1. saniyesi.
- `ui_tap`: `AppFeedback.selection()` seçimleri (throttle'lı). Klavyede tuş sesi yoktur.

## Bilinçli sınırlar ve açık kontroller

- Online Loto ve Rastgele Beş ayrı lobi ekranı kullanmayan `PvpPage` içinde oynandığı için maç ve bekleme ayrımı oda durumundan yapılır.
- `xp_reward` ve `streak` dosyaları pakette ve testte vardır. Mevcut ekranlarda XP veya seri kazanımı ayrı, doğrulanmış bir olay olarak gelmediği için henüz bir olaya bağlanmadı.
- `TEKNIK_KURALLAR.md` içindeki cihaz listesi bu ortamda çalıştırılamadı: fiziksel Android/iOS cihazda gapless döngü, kulaklık/Bluetooth, arama/medya odağı, sessiz mod ve reklam kontrolleri henüz yapılmadı.
- Paket notuna göre müziklerin bağımsız telif/kaynak denetimi yapılmadı; mağaza yayını öncesinde bu kontrol gerekir.
