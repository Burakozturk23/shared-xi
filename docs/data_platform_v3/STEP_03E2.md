# 03E.2 — Historical Popularity Balance

03E.1 modern oyuncularda doğru çalışıyor; ancak emekli bazı yıldızlarda kaynak profili
milli takım caps bilgisini boş bırakıyor ve appearance datası kariyerin yalnızca son
bölümünü kapsıyor.

Bu nedenle V3 yalnızca şu gruba konservatif bir historical floor uygular:
- güvenli factual TM identity,
- international caps eksik/0,
- son sezon 2023 veya daha eski,
- dataset içinde en az 80 appearance gözlenmiş.

Floor sinyalleri:
- en iyi 3 canonical kulübün context skoru,
- UCL appearance,
- dataset içinde gözlenen appearance,
- elite club sayısı.

Özellikle kullanılmaz:
- toplam kulüp sayısı,
- HIGH-trust relation sayısı,
- market value,
- career goals.

Böylece Robben / Özil / Ibrahimović gibi eksik-kapsamlı yıldızlar geri kazanılırken
journeyman oyuncular tekrar yukarı fırlamaz.

Ayrıca `historical_layer_priority.csv`, daha eski legends/nostalgia katmanında
harici historical enrichment gerektiren legacy oyuncuları listeler.

`assets/data` değişmez.
