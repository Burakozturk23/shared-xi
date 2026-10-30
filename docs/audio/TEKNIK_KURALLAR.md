# Linkball Ses Motoru — Entegrasyon ve QA Kuralları

**Durum:** Dosyalar ve eşleme hazır, Flutter entegrasyonu henüz yapılmadı. `pubspec.yaml` üzerinde bir ses oynatıcı bağımlılığı ve audio asset tanımı mevcut değil (25 Ekim 2026 main incelemesi).

## Temel yaşam döngüsü

1. Tek uygulama seviyesinde **AudioCoordinator** kullan; rota değişirken eski state'in `initState`/`dispose` olaylarına her seferinde yeni müzik başlatma bağlama.
2. Anasayfa, Oyunlar, Online ana sayfası, Profil, Mağaza, Günlük Ödül = M1 (V2.5); ana sekmelerde devam.
3. Story seçimi dahil Story ekranına girişte M2; bütün Story bölüm/mod değişimlerinde aynı player ve pozisyon korunur. Story'den çıkınca .7-1s fade ile M1'e dön.
4. Solo bulmaca M3, süre baskısı M4, bot/online rekabet M5 (oyun türüne göre M4 istisnaları JSON'da). Online bekleme odası M1 sessiz; maç başlama M4/M5.
5. Doğru/yanlış SFX sadece cevap client/controller/sunucu onayından sonra. Hata, network gecikmesi ve yanlış kullanıcı girişini karıştırma.
6. Coin sesi sadece idempotent backend/ledger ödemesinden sonra. İpucunda Coin kazanma sesi çalma.
7. Reklam oynarken, uygulama arka plandayken veya başka medya ses odağını alınca BGM pause/duck yap; döndüğünde gerektiğinde continue.
8. Müzik/efekt/titreşim ayrı ayarlar, ayrı ses seviyesi. Tavsiye başlangıç M1/M3/M4/M5 ~%27, Story %20, SFX ~%55. Kullanıcının kapatma tercihine saygı göster.
9. SFX benzer vuruşları 120ms throttle, aynı ses için overlap sınırı, genel 3-voice SFX sınırı. Online aynı event ID yeniden gelirse ikinci kez çalma.
10. Klavyede her karakter için click yok. Sayaç son 5sn ancak oyuncuyu bunaltmayacak seyrek sinyal. Sessiz hata geri bildirimi metin+ikonla da anlaşılmalı.

## Teknik dosyalar

- Android: Ogg/Vorbis loop; `*_loop.ogg`.
- iOS: MP3 alternatif var, fakat MP3 ve genel codeclerde uçtan uca gapless garanti edilmez; gerekirse AAC/WAV özel export.
- WAV SFX: 32 kHz 16-bit PCM, mono.
- Flutter `pubspec.yaml` içine `assets/audio/music/` ve `assets/audio/sfx/` dizinleri eklenecek; audio paketi uyumluluğunu Flutter sürümüne göre sabitle.
- `AppPreferences` içindeki `sound` boolean'ını veri kaybı olmadan yeni `musicEnabled`, `sfxEnabled`, `musicVolume`, `sfxVolume` alanlarına migrate et; mevcut haptics ayarını koru.

## PASS/FAIL cihaz kontrol listesi

- [ ] M1 V2.5 ve yalnız V2.5 anasayfada çalıyor; sekmelerde restart yok.
- [ ] Story sekiz kategoride M2 ve tek oynatıcı; her bölümde restart yok.
- [ ] Bulmaca, süreli, rekabet sahneleri doğru M3/M4/M5 atamasını alıyor.
- [ ] 23 WAV efektinin hepsi ayrı ayrı çalıyor; 5 yeni efekt olaylara bağlanmış.
- [ ] Coin ödülü sunucu doğrulaması gelmeden ses çıkarmıyor.
- [ ] 3/5 saniyelik sayaç sesi her frame'de tetiklenmiyor.
- [ ] Reklam, telefona gelen arama, media focus ve arka plan yönetimi doğru.
- [ ] Ses kapalıyken arayüz yine erişilebilir; doğru/yanlış sadece sese bağlı değil.
- [ ] Android fiziksel cihaz+emülatör, iOS cihaz (varsa), kablolu/Bluetooth kulaklık, düşük ses modu.
- [ ] Tekrar eden OGG dosyalarında cihazda klik/boşluk yok (özellikle M1/M3/M4/M5).
- [ ] Mode route rebuild ve navigator pop animasyonlarında iki müzik üst üste çalmıyor.
- [ ] `flutter analyze`, ilgili widget test ve emulator smoke PASS.

**Yalnız dosya/ses/ZIP testleri tamamlandı; bu liste kullanıcı uygulamasında henüz çalıştırılmadı.**
