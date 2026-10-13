# Beş mod genişleme paketi

PDF: Linkball 5 Mod Genişleme Paketi Final Planı, 12 Ekim 2026.
Temel dal: `codex/derby-day-v2`; mevcut geliştirme zinciri korunur.

| Mod | Yeni içerik | Toplam |
| --- | --- | --- |
| Player Journey | PJ-33–PJ-40, 8 kariyer / 32 görev | 40 kariyer / 160 görev |
| UCL Moments | UCL-35–UCL-37 | 37 maç |
| Türk Futbolu: Nostalji | TN-13–TN-15, 6 görev | 15 bölüm / 30 görev |
| International Glory | IG-41–IG-44 | 44 maç |
| Dynasties | DY-17–DY-19, 6 görev | 19 dönem / 38 görev |

Yeni katalog `assets/data/five_mode_expansion.json`, cevap anahtarı ve kaynaklar
`functions/config/five_mode_expansion.json` içindedir. Eski katalog dosyaları byte
olarak değişmez; hash kontrolleri CI'da çalışır. Çalışma zamanında ekleme yapılır.
Yeni seçenek anahtarları doğru cevap veya seçenek sırasını kodlamaz.

## Ekonomi ve kayıtlar

13 Ekim güncellemesi: kullanıcının talebiyle `rewardPolicy: mode_default` etkin.
Yeni içerikler kendi modlarının mevcut ekonomisini kullanır:

| Mod | İlk başarı | Ek tamamlama |
| --- | --- | --- |
| Player Journey | Dört görevlik kariyer: 20 Coin / 40 XP | Sekiz kariyerlik bölüm: 80 Coin / 120 XP; isteğe bağlı +80 Coin reklam/Pro bonusu |
| UCL Moments | Maç: 8 Coin / 20 XP | Mevcut 10/20/34 eşikleri |
| Nostalji | Görev: 6 Coin / 15 XP | Her bölüm: 15 Coin / 30 XP |
| International Glory | Maç: 8 Coin / 20 XP | Mevcut 10/20/30/40 eşikleri |
| Dynasties | Görev: 8 Coin / 20 XP | Mevcut 4/8/12/16 mühür eşikleri |

Yeni maçlar/mühürler mevcut sayı eşiklerine dahil edilir; aynı eşik yeniden ödemez.
Player Journey'nin ilk 32 kariyer finali ve Nostalji'nin ilk 12 bölüm albüm finali
aynı kimlik ve koşullarla korunur. Yeni bir genel final ödülü icat edilmez.
Sunucuda önceden tamamlanmış, ödülsüz genişleme kayıtları durum eşitlemesinde
hak kazanır. Mevcut makbuzlar `||=` ile korunur; Coin/XP yazımı kesilirse aynı
makbuzla yeniden denenir. Kullanıcıdan gelen yerel tamamlanma iddiası kullanılmaz.
Tüm içerik (reklam bonusu hariç): PJ 1350 Coin/2500 XP, UCL 506/1065,
Nostalji 465/1020, International 672/1355, Dynasties 504/1135.

Player Journey'nin mevcut Google hesabı koşulu devam eder. Yeni bölüm kayıtları
UID ile ayrılır. Yeni kariyer ve Nostalji görevlerinde sunucu onayından önce
başarı gösterilmez. Bağlantı kesilirse seçim saklanır. Kariyerde yeniden gönder;
Nostalji ve diğer modlarda Eşitle'yi kullan. Yanlış yanıt sonraki aşamayı açmaz.
Mevcut bölüm/kariyer ilerlemesi ve makbuz anahtarları taşınmaz veya silinmez.

Ücretsiz ipuçları her yeni görevde vardır. Yeni Player Journey/Nostalji görevleri
eski, istemcide cevap anahtarına ihtiyaç duyan ücretli yardım mekanizmasına
bağlanmaz. UCL/International/Dynasties mevcut sunucu doğrulama akışını kullanır.

## Veri ve kaynaklar

Canonical V4 oyuncuları doğrudan denetlendi: Pelé 4000000065, Maradona 4000000035,
Ronaldo Nazário 3140, Buffon 5023, Hagi 4000000002, Alex 4000000110,
Quaresma 4188, Burak Yılmaz 4000000108. Yeni oyuncu veya yaklaşık isim eşleştirmesi
yapılmadı. 1986 Steaua için bir modern kulüp kimliği uydurulmadı; tarihsel ad
kullanılır. Yeni görsel veya ham StatsBomb arşivi paketlenmedi.

Kaynak URL'leri PDF bağlantılarından `tools/five_mode_expansion/sources.json`
dosyasına alındı. Alex'in ilk/son Coritiba dönemleri kulüp arşivi ile desteklendi.
1970 finalinin başlangıç kadrosu FIFA'nın final tarihçesi ile desteklendi;
sezon kadrosundan ilk 11 türetilmedi. Barrera'nın iki golü farklı kart anahtarlarına
sahiptir; dakikalar yalnızca doğru yanıttan sonra gösterilir. Sıralama sorularında
alternatiflerin anlamı yanlış sıra/atamadır; dört gerçek gol yerine uydurma olaylar
eklenmez. Diğer seçim sorularında en az üç yanlış seçenek bulunur.

## Tekrarlanabilir kontrol

```text
python tools/five_mode_expansion/build.py
python tools/five_mode_expansion/verify.py
npm --prefix functions test
npm --prefix functions run lint
flutter analyze --no-fatal-warnings --no-fatal-infos lib test integration_test
flutter test
flutter build apk --debug
```

Sunucu regresyonları yeni içerik → eski içerik → tekrar gönderim sırasını kontrol
eder. Mobil testler yeni katalog toplamları, 32 kariyer görevi, çevrimdışı seçim,
çift gönderim, UID ayrımı, Nostalji yanlış cevap ve Katar rota seçeneklerini kapsar.
Beş modun örnek görevleri 320 px / %180 metin ölçeğinde açık/koyu temada açılır.

Canlı Firebase dağıtımı ve fiziksel cihaz/App Check testi bu kod değişikliğiyle
kendiliğinden yapılmaz. Cihazdaki uçtan uca test dağıtılmış sunucu sürümünü gerektirir.
