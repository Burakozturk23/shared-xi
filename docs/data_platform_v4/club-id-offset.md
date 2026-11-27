# Kulüp kimliği ofseti (TM + 1 000 000 000)

V4 derleyicisi Transfermarkt kulüp kimliklerini `1 000 000 000 + TM kimliği` olarak saklar.
Eski kaynakların kimlikleri çoğu kulüpte TM kimliğiyle aynıdır; bu yüzden katalog üreticileri
`kimlik − 1 000 000 000` var olan bir kulüpse ikisini aynı kulüp sayar ("PSG" = "Paris
Saint-Germain", "Loko Moscow" = "Lokomotiv Moscow").

188 ofset çiftinin 35'inde bu varsayım yanlış: eski kimlik başka bir kulübe aittir (Al-Jazira →
Universitatea Craiova, Saprissa → Dungannon Swifts, Dinamo Tbilisi → Chaves, Qarabağ →
Antwerp). Bu kulüpler `tools/data_platform_v4/club_offset_mismatch.json` listesindedir ve kendi
kimliklerini korur. Liste 11 Kasım 2026'da adlar tek tek okunarak hazırlandı; kalan 153 çift aynı
kulübün kısa adıdır (K'lautern, Odd, Bayonne, Çin kulüplerinin kısaltmaları).

Listeyi kullananlar: `tools/career_transfer`, `tools/mystery_chain`, `tools/fake_club`,
`tools/choice`, `tools/arcade` üreticileri ve `tools/pvp/fetch_coach_tenures.primaries` (Grid
kulüp listesinin ikiz grupları).

Etki (düzeltmeden önce): Kariyer Yarışı'nda Kvaratskhelia Chaves'le, Keylor Navas ve Joel Campbell
Dungannon Swifts'le, Aránguiz B 93'le başlıyordu; Transfer Düellosu'nda 12 hatalı transfer vardı
(Arsenal → Universitatea Craiova gibi); Sahte Kulüp'te Farfán'ın "gerçek" kulübü
Universitatea Craiova görünüyordu.

Arcade kataloğu bu düzeltmeden önce de veritabanıyla uyuşmuyordu (`--check` drift); kodu
düzeltildi ama katalog yeniden üretilmedi, o iş ayrıca incelenmeli.

Yeni bir veri sürümünde: ofset çiftlerini adlarıyla listele, farklı kulüpleri bu dosyaya ekle,
etkilenen katalogları yeniden üret.
