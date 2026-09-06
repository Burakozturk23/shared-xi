# Linkball Data Platform v3 — Step 03A

Bu paket **salt-okunur veri denetimi** yapar. `assets/data/` içindeki hiçbir dosyayı değiştirmez.

## Kurulum

ZIP içindeki `tools` klasörünü projenin ana dizinine kopyala. Yeni klasör şu olmalı:

`shared-xi/tools/data_audit/`

Mevcut uygulama dosyalarının üzerine yazılmaz.

## Çalıştırma — önerilen

Windows'ta çift tıkla:

`tools/data_audit/run_data_audit.bat`

Rapor burada oluşur:

`reports/data_audit/latest/`

## Deep audit

Normal rapor tamamlandıktan sonra ayrıca:

`tools/data_audit/run_data_audit_deep.bat`

çalıştırabilirsin. Bu mod varsa `players.json` ile `players_min.json` alan kapsamını ve değer farklarını da karşılaştırır. Daha fazla RAM kullanabilir.

## Neleri kontrol ediyor?

- player / club ID tekilliği
- player.clubIds -> clubs referans bütünlüğü
- careerTimeline -> club referans bütünlüğü
- timeline kronolojisi ve bozuk tarih aralıkları
- `Club {id}` placeholder kulüpler
- country / league eksikleri
- kullanılmayan kulüpler ve oyuncular tarafından çok kullanılan sorunlu kulüpler
- player alanlarının doluluk oranları
- famous transfer player/club referansları
- meta.json sayaç tutarlılığı
- full + min dosyaların aynı anda production bundle'a girme riski
- mevcut oyun modları için veri kapsamı
- gelecekte eklemek istediğimiz popularity / birthYear / foot / height gibi alanların hazır olup olmadığı

## Step 03B için bana geri gönder

`reports/data_audit/latest/` klasöründen şunları yükle:

1. `report.md`
2. `report.json`
3. `orphan_club_references.csv`
4. `club_issues.csv`
5. `field_coverage.csv`
6. `game_readiness.csv`
7. Deep audit yaptıysan `full_min_diff.csv`

Bunlara bakarak 03B canonical schema ve migration paketini mevcut gerçek verine göre hazırlayacağız.
