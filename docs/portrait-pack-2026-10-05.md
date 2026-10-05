# Kullanıcı portre paketi — 5 Ekim 2026

Taban: `codex/player-portraits-avatar-refresh` / `167002f` (PR #20).

## Davranış

- İki ZIP içindeki isim etiketleri incelendi. 16–18. sayfaların tekrarları çıkarıldı; 216 portre, 23 değiştirilmemiş PNG kaynakta paketlendi.
- Yeni kaynaklar oyun kartlarında öncelikli. Paket dışındaki eski, doğrulanmış portreler korunuyor; diğer oyuncularda forma/baş harf yedeği devam ediyor.
- 123 görselli koleksiyon avatarı: önceki 66 seçeneğin 64'ü korundu, 59 yeni seçenek eklendi. Sekiz klasik simge avatarı ayrıca korunuyor.
- Metin Oktay, Lefter, Batistuta, Vieira, Kahn, Cafu; Arda Turan, Fàbregas, Xabi Alonso; diğer seçilmiş efsaneler ve teknik direktörler eklendi.
- Guardiola'nın mevcut `persona_pep_guardiola` kimliği teknik direktör portresini kullanıyor. `persona_pep_guardiola_player` ayrı futbolcu portresini kullanıyor. Oyundaki Guardiola futbolcu kartı da futbolcu portresine bağlı.
- Ayrı TD portresi olmayan isimler mevcut futbolcu portresini paylaşır. Teknik Direktör XI başlığında da portre gösterilir; bilinmeyen TD baş harf kullanır.
- Erman Yaşar, Hasan Arda, Emre Özcan gönderilen üçlü görsele bağlı.
- Nwakaeme ve Hamšík için mevcut kaynaklarda portre bulunmadığından seçimden kaldırıldı; sunucu teklifleri devre dışı. Geçmiş satın alma kayıtları ve coin bakiyeleri silinmez. Eski seçili, artık bilinmeyen avatar mevcut profil onarımında başlangıç avatarına döner.

## Veri sınırı

Bu çalışma portre/mağaza koleksiyonudur; SQLite oyuncu veya kulüp geçmişlerini değiştirmez.
12 kaynak ismi için doğru oynanabilir oyuncu kaydı bulunamadı: Rafael Márquez, Jefferson Farfán, Oliver Kahn, Peter Schmeichel, Cafu, Metin Oktay, Bülent Korkmaz, Ümit Davala, Burak Yılmaz, Guti, Alex de Souza, Micah Richards. Portreleri paketli; seçilenler profil avatarında kullanılabilir. Oyuncu verisine eklemek, ayrı ve kaynaklı kariyer verisi çalışması gerektirir.

Cafu (466279/203655), Burak Yılmaz (164148), Guti (186623) adaşlarına görsel bağlanmadı. Tam ad, kanonik ID ve mevcut kulüp bağlantıları birlikte incelendi; belirsiz ad eşleşmesi otomatik kullanılmadı.

## Tekrar üretim ve doğrulama

```sh
python3 tools/uploaded_portraits/generate_catalog.py
python3 tools/uploaded_portraits/generate_catalog.py --check
python3 tools/uploaded_portraits/verify.py
node --test functions/test/store_collection.test.js
flutter test test/avatar_portraits_test.dart test/uploaded_portrait_test.dart
```

Manifest her kartın kaynak sayfasını, sıra numarasını, gösterim alanını, SHA256 ve doğrulanmış oyuncu kimliğini tutar. PNG dosyaları kullanıcı kaynaklarıyla bayt düzeyinde aynı. İsimler ve başlıklar uygulamada Flutter kırpmasıyla gizlenir; dosyalar yeniden çizilmez.

## Dağıtım

Yeni mağaza seçeneklerinin satın alınması için eşleşen Firebase Functions kataloğu (sürüm 6) dağıtılmalı. Bu PR canlı Firebase dağıtımı veya main birleştirmesi yapmaz. Yeni istemci eski sunucudan gelen artık bilinmeyen/devre dışı teklifleri de filtreler.
