# Kadro taramasını genişletme ve eksik oyuncular — 29 Eylül 2026

Önceki 347 bağlantılı güncelleme yalnız mevcut oyuncuları kapsıyordu. Bu sürüm yeni oyuncu kimliklerini de ekler. Kaynak: worldcup26.ir public `/get/soccer/{league}/clubs/{clubId}`. Kullanıcı kararı gereği güncel kadro üyeliği kulüp bağlantısı için yeterlidir.

## Kimlik ve kapsam

- Bu paket 17 birinci ligdeki 326 erkek kulübü kapsar: Türkiye, İngiltere, İspanya, İtalya, Almanya, Fransa, Hollanda, İskoçya, Portekiz, Belçika, Avusturya, ABD, Meksika, Arjantin, Brezilya, Suudi Arabistan ve Japonya. Kupa, alt lig, altyapı ve rezerv organizasyonları bu geçişte dışarıda bırakılır.
- Kadro aynı kulüp kimliğiyle birden fazla organizasyonda görünüyorsa tekilleştirilir. Kaynak kadro kayıtları 29 Eylül 2026 tarihinde 05:15–14:25 UTC arasında senkronize edilmiştir.
- Kadro karşılaştırması lig/ülke ile doğrulanan kulüp eşlemelerini kullanır. Altyapı ve reserve adları A takıma birleştirilmez. Kadrosu boş veya kulübü eşleşmemiş kayıtlar kapsam raporunda tutulur.
- Mevcut oyuncu: normalize tam ad/alias + doğum yılı; veya tam ad + mevcut aynı kulüp bağlantısı + ülke + çelişmeyen doğum yılı. Ad-soyad sırası farklı ama tüm parçalar aynıysa doğum yılıyla eşleştirme yapılır.
- Yeni oyuncu: kaynak kimliği, tam ad, doğum yılı ve ülke mevcut; mevcut oyuncu ad/alias havuzunda kesin veya muhtemel çakışma yok. Bulanık benzerlik yalnız mükerrerlik uyarısı üretir, otomatik birleştirme yapmaz. Kaynakta farklı güncel kulüplerde görünen kimlikler ayrılır.
- Kimlik alanı: `3000000000 + kaynak oyuncu ID`. Mevcut bütün kimlikler aynıdır. Yeni kayıtların kaynağı `worldcup26-roster` ile ayırt edilir.
- Yeni oyunculara yalnız gözlenen güncel kulüp eklenir. Önceki kariyer, transfer tarihi, maç sayısı, piyasa değeri veya gol istatistiği uydurulmaz. Eksik tarihçe nedeniyle eski kulüp eşleşmeleri henüz cevaplanamayabilir.
- Yeni oyuncuların ad/alias, ülke, pozisyon ve arama kayıtları eklenir. Yeni sıralamalar mevcut sıralamaların sonuna konur; kolay/normal soru havuzu eşikleri korunur. Cevap ve arama sorguları yeni kimlikleri kabul eder.

## Bu revizyonda eklenenler

- 6.145 yeni oyuncu kimliği ve 6.362 güncel oyuncu-kulüp bağlantısı eklendi.
- Yeni toplam oyuncu sayısı 30.135'ten 36.280'e çıktı; kulüp, transfer, kariyer ve koç tabloları korunuyor.
- 1.965 belirsiz, eksik, çakışan veya 16 yaş altı kayıt otomatik eklenmedi. Bunlar kaynak taramasının sonraki incelemesi için yerel denetim çıktısında kaldı.
- Yeni oyuncular `worldcup26-roster` kaynağıyla, bağlantılar `roster:worldcup26:2026-09-29.2` kaynağıyla ayırt edilir. `v4-2026-09-29.2` paketi mevcut SQLite SHA-256 değeri `1f6a125d3402188d5c5e53d3c05697d4f9a26b99a0959b4a6ff70cd792336b9c` üzerine uygulanır.

## Uygulama güvenliği

Açılıştaki sabit 30.135 oyuncu şartı manifest + metadata + gerçek SQLite sayısının eşitliğiyle değiştirildi. V4 sorgularındaki 30.000 sıralama sınırı mevcut oyuncular için korunur; onaylanmış yeni kaynak oyuncuları ayrıca kabul edilir. Bu değişiklikler veri genişlemesinin açılışı veya oyuncu aramasını bozmamasını sağlar.

`apply_roster_expansion.py` ağ kullanmaz, girdinin hash'ini ve kanıt parçalarının hash'lerini doğrular; geçici kopyada işlem yapar, bütünlük/foreign key/arama kontrollerinden sonra paketi değiştirir. Aynı yamanın aynı çıktıya tekrar uygulanması işlemsizdir. Eski SQLite ve manifest önceki commit'te kalır.

## Tekrar üretim

```sh
python tools/data_platform_v4/apply_roster_expansion.py tools/data_platform_v4/patches/roster-expansion-2026-09-29.json
python tools/data_platform_v4/verify_game_data_v4_freeze.py
python -m unittest discover -s tools/data_platform_v4 -p 'test_roster_expansion.py'
```

Uygulamayı tamamen durdurup yeni asset ile yeniden derleyin. Hot reload, paketlenmiş veritabanını değiştirmez.
