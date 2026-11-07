# Fiyat değişikliği (linkball_prices_v1)

Güçlendirme fiyatları Remote Config'teki `linkball_prices_v1` parametresinde durur. Varsayılan değerler
`functions/config/linkball_prices.defaults.json` dosyasındadır ve bayrak kapalıdır (`enabled: false`).
Bayrak kapalıyken `boosts.js` fiyatları geçerlidir.

## Kim, nasıl

Fiyatı yalnızca Firebase projesinde Remote Config yayınlama yetkisi olan kişi değiştirir. Firebase
konsolundan elle düzenleme yapılmaz; değişiklik her zaman şu komutla yapılır, çünkü komut doğrulamayı ve
kaydı birlikte yapar:

1. Varsayılan dosyayı kopyala, fiyatları değiştir ve `revision` alanına yeni bir ad ver
   (ör. `prices-2026-11-15`). Fiyatları gerçekten uygulamak için `enabled: true` yap.
2. Kontrol et: `cd functions && npm run prices:check -- ../yeni-fiyatlar.json`. Komut her değişikliği
   listeler ve dosya geçersizse ya da `revision` değişmemişse hata verir. Bu adımda hiçbir şey yazılmaz.
3. Canlıdaki değerle karşılaştırmak için aynı komutu `--remote` ile çalıştır (Google kimlik bilgisi gerekir).
4. Yayınla: `npm run prices:publish -- ../yeni-fiyatlar.json`. Komut şablonu önce doğrular, sonra yayınlar.
   Parametre açıklamasına revision ve yapılandırma kimliği yazılır.
5. Değişikliğin nedenini ve yeni sürüm numarasını PR'a ya da ekip kanalına yaz.

## Kayıt ve geri alma

- Kayıt, Remote Config sürüm geçmişidir. Her yayının açıklamasında revision vardır.
- Geri almak için konsoldan önceki sürüme dön ya da önceki dosyayı yeni bir revision adıyla yayınla.
- Sunucu değeri yaklaşık 5 dakikada bir okur. Hatalı bir değer gelirse yalnızca fiyatlar varsayılana döner.
- Açık bir mağaza ekranı eski fiyatla satın almaya çalışırsa "Fiyat güncellendi" hatası alır ve coin
  harcanmaz. Başlamış bir oyun, başladığı andaki fiyatı kullanmaya devam eder.

## Bütçe testi

`functions/test/economy_budget.test.js` normal test takımının parçasıdır, yani kırılırsa birleştirme durur.
Bilinçli bir değişiklikte `functions/config/economy_budget.json` aynı PR'da güncellenir ve nedeni
PR açıklamasına yazılır. Bant: rutin gelir 100–230 coin/gün (Görevler v3 dahil). Katalog bitirme sınırı
400 gündür. Kontrol için: `npm run economy:check`.
