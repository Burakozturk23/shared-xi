# Player Journey finalizasyonu

9 Ekim 2026 tarihli kullanıcı PDF planı temel alınmıştır.

## İçerik ve deneyim

- 32 futbolcu, dört bölüm, 128 görev ve beş mekanik korunur.
- Her görevin `introNarrative` alanı vardır. Ayrı giriş ekranı → tek görev → mevcut açıklama akışı kullanılır. “Göreve geç” okumayı atlamaya izin verir; görevde “Hikâyeyi yeniden oku” seçimi kaybetmeden geri döner.
- Hikâyeler `tools/player_journey/narratives.py` içinde düzenlenir. Dört `build_chapter_*.py` dosyası aynı metinleri kataloglara taşır. Görev kimlikleri, cevaplar, kaynaklar ve tarih sınırları değişmemiştir.
- İlk iki kariyer her bölümde açıktır. O bölümde her tamamlanan kariyer bir sonraki seçeneği açar. Eski tamamlamalar, tekrar oynanan ve başlanmış kariyerler kilitlenmez.
- Eski cihaz ilerlemesinin korunduğu, sunucu damgası yoksa dört görevin yeniden doğrulanması gerektiği oyuncu listesinde açıklanır.
- Oyuncu ve bölüm ödülleri listede görünür. Damga sunucu makbuzu kesinleşince gösterilir. Reklam bonusu da yalnızca kesinleşmiş makbuzla kazanılmış kabul edilir.
- Yeni para birimi, enerji veya zorunlu reklam yoktur. Temel toplam 1110 Coin / 2060 XP ve tek seferlik ödeme kuralları korunur.

## Entegrasyon

`main` 56a5b6b ile PR #29 b66d15b birleştirilerek hazırlanmıştır. Bu, #22–#29 zincirindeki mağaza/avatar, Günün Futbolcusu, Anagram, dört Journey bölümü ve ödül çalışmasını aynı entegrasyon dalında toplar. Main'deki Windows LF ve Android CI düzeltmeleri korunur.

## Kontroller

- `python3 tools/player_journey/verify.py`: 32 kimlik, 128 görev, 128 farklı anlatı, başlık/soru/ipucu/anlatıda cevap adı bulunmaması; istemci/sunucu katalog eşitliği ve yeniden üretilebilirlik.
- `flutter test`: girişte seçeneklerin gizlenmesi, tekrar okurken seçimin korunması, sonraki aşama ve kayıttan devam; açık/koyu 320px ve 1.8 metin ölçeği; mevcut oynanış/ödül regresyonları.
- `npm --prefix functions run lint` ve `npm --prefix functions test`: katalog eşitliği, tek ödeme, tekrar oynama, kesinti, hesap ve SSV senaryoları.
- CI ayrıca Android debug APK üretir. Testler fiziksel cihaz veya canlı servis kabulü yerine geçmez.

## Canlı kabul (ayrıca uygulanmalı)

1. Entegre sürüm için `firebase deploy --only "functions,database" --project sharedix`.
2. Google bağlı hesap ve App Check ile dört görevi tamamlayıp 20 Coin /40 XP ve damgayı doğrula; tekrar oynayınca ikinci ödeme olmadığını kontrol et.
3. Bölüm ve final ödüllerini, aynı UID ile kesinti sonrası eşitlemeyi kontrol et. Hesap değiştirince önceki hesabın kuyruğu yeni hesaba gitmemeli.
4. Gerçek AdMob istemci/sunucu birimleri ve SSV yapılandırıldıktan sonra fiziksel cihazda story_hint/story_double, iptal, ağ hatası ve Pro senaryolarını dene. Test birimleri gerçek reklam yayını değildir.
5. İmzalı sürümde küçük ekran/büyük yazı, geri dönüş ve kaldığı aşamaya devamı kontrol et.

Bu çalışma canlı reklam birimi icat etmez; üretim Firebase/SSV veya fiziksel cihaz doğrulaması yapılmadıkça o kabul maddeleri tamamlandı sayılmaz. Ayrıntılı ekonomi kurulumu: `PLAYER_JOURNEY_REWARDS.md`.
