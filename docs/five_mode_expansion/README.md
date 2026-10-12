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

PDF yeni 51 görevin ödülünü belirlemiyor. `rewardPolicy: pending` bu sürümde
Coin/XP dağıtmaz; sonradan otomatik geriye dönük ödül çıkaracak bir işlem yoktur.
Tamamlanmalar, kariyer damgaları ve hanedanlık mühürleri kaydedilir. Eski Coin/XP,
bölüm/final/album ödülleri yalnızca eski görev kimlikleriyle hesaplanır. Örneğin
40 Player Journey kariyerini tamamlamak önceki 1110 Coin / 2060 XP toplamını korur.
Yeni içerik eski koleksiyon ödüllerinin yerine sayılamaz.

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
