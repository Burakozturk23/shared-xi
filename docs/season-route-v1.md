# Linkball Sezon Rotası ve kalıcı başarımlar

## Oyuncu deneyimi

- İstanbul takvim ayı başında başlayan, ay sonunda biten **20 duraklı Sezon Rotası**.
- Her 100 SP bir durak açar; günlük toplam en fazla 150 SP. SP harcanmaz, yalnızca rotayı ilerletir.
- Günlük buluşma ödülünü almak 10 SP; günlük görev ödülü 30 SP (en fazla üç); kariyer görevi ödülü 50 SP.
- Günün Maçları’nda o günün ilk normal galibiyet coin ödülü 50 SP. 2× reklam bonusu ayrıca SP üretmez.
- Günlük sınır üzerindeki SP sonraki güne taşınmaz. En hızlı tamamlama 14 oynanan gündür; bunun için yeterli görev/maç olması gerekir.
- Normal duraklarda ücretsiz 20, Pro 40 coin; her beşinci durakta ücretsiz 60, Pro 100 coin. Toplam ücretsiz **560**, Pro yolunda **ek 1.040** Link Coin.
- Pro yolu mevcut doğrulanmış Linkball Pro üyeliğine dahildir; ayrı sezon kartı satın alımı yoktur.
- Pro aynı hızda ilerler. Sezon içinde Pro olan oyuncu, ulaştığı durakların ikinci yol ödüllerini sezon sonuna kadar alabilir.
- Pro biterse alınmış ödüller kalır; yeni Pro ödülleri için aktif üyelik gerekir.
- Sezon puanı aylıktır; mevcut ömür boyu XP, eski yıllık sezon XP kaydı, cüzdan ve kalıcı rozetler silinmez.
- Ay sonunda alınmamış ödüller kapanır; önceki aylardan kazanılmış coinler korunur. Eski ekran yeni ayda ödül isteyemez.
- Başlangıç ayında daha önce alınmış uygun sunucu ödülleri de SP hesabına dahil edilir.

## Başarımlar

28 mevcut kimlik korunur; 26 yeni hedefle toplam **54** rozet.
Altı görünüm: Galibiyet, Seriler, Kariyer ve Elo, Mod ustalığı, Günlük futbol, Takım ruhu.
Galibiyet basamakları 1 / 5 / 10 / 25 / 50 / 100 / 250 / 500 / 750.
Maç basamakları 1 / 10 / 50 / 100 / 250 / 500 / 1.000.
Ortak XI, Grid, Çinko ve Rastgele Beş için 1 / 10 / 50 / 100 dereceli galibiyet.
Sosyal hedefler doğrulanmış arkadaş sayısına dayanır. Arkadaşla özel maç ve yerel bot sonuçları henüz sunucu otoriteli olmadığından yeni coin başarımı yapılmadı.
Rozetler sezon sonunda sıfırlanmaz. Var olan sunucu sinyalleri yeni basamakları geçmiş ilerlemeyle açar.
Yeni rozet coin değerleri `functions/config/achievement_expansion.json` içindedir; mevcut ekonomi yapılandırmasının başarım enabled anahtarına tabidir. Eski Remote Config şeması ve eski rozet ödül değerleri korunur.

## Sunucu doğrulaması ve sınırlar

`getSeasonPass` / `claimSeasonReward` Google bağlı hesap ve App Check ister.
SP yalnızca özel `economyState/{uid}/claims` kayıtlarından sunucuda hesaplanır. İstemci SP, premium durumu veya coin miktarı belirleyemez.
Coin satın alımı, reklam, rozet ve sezon ödülü SP üretmez. Tekrar ve eşzamanlı talepler `season_v1__ay__durak__yol` cüzdan anahtarıyla bir kez ödenir. Cüzdan görünümü yazımı kesilirse aynı isteğin tekrarı görünümü onarır.
Yeni istemci yazma yetkisi veya veritabanı kuralı gerekmez; mevcut hesap silme akışı economyState kayıtlarını da siler.
Bu sürüm her yüklemede kullanıcının özel cüzdan ödül kayıtlarını okur; çok uzun hesap geçmişlerinde aylık özetleme sonraki performans iyileştirmesidir.

## Yayın

Bu dal, Günün Maçları güncellemesini içeren PR #15 üzerine kuruludur.
Yeni Flutter kodu yanında sunucu değişiklikleri de dağıtılmalıdır:

```powershell
npm --prefix functions ci
npm --prefix functions run lint -- --fix
npm --prefix functions test
firebase deploy --only functions
flutter pub get
flutter run --no-enable-impeller
```

Canlı Firebase dağıtımı bu çalışma kapsamında yapılmadı. Emülatörde App Check debug token uygulamanın Firebase App Check ayarlarına kayıtlı olmalı; doğrulama kapatılmamalı.
CI `season-badge-previews` çıktısı yeni ekranları içerir. Gerçek cihazda Pro satın alma/yenileme ve hesap oturumu dağıtım sonrasında doğrulanmalıdır.
