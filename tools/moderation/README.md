# Moderasyon aracı

Oyuncu raporlarını (Güvenlik ve Raporlar) ve topluluk taleplerini listeler,
durumlarını değiştirir. Bilgisayarda oturumu açık `firebase` CLI ile çalışır;
servis hesabı veya uygulamada yönetici ekranı gerekmez.

```
py -3 tools/moderation/moderate.py reports                 # açık ve incelenen raporlar
py -3 tools/moderation/moderate.py reports --all           # kapananlar dahil
py -3 tools/moderation/moderate.py report-status <id> reviewing
py -3 tools/moderation/moderate.py report-status <id> <id2> actioned
py -3 tools/moderation/moderate.py requests                # açık ve incelenen talepler
py -3 tools/moderation/moderate.py request-status <id> resolved
```

Rapor durumları: `open`, `reviewing`, `actioned`, `closed`.
Talep durumları: `open`, `reviewing`, `resolved`, `closed`.

Bir durum değişikliği kaydı (`safetyReports/<id>`, `communitySubmissions/<id>`)
ve oyuncunun kendi listesindeki özeti (`safetyReportIndex/<uid>/<id>`,
`communitySubmissionIndex/<uid>/<id>`) tek bir toplu güncellemeyle birlikte
yazar; uygulamadaki "Açık / Sonuçlanan" filtreleri hemen değişir. Bilinmeyen
bir kimlik ya da geçersiz durum verilirse hiçbir şey yazılmaz.

Test: `py -3 -m unittest discover tools/moderation`
