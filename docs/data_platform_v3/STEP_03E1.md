# 03E.1 — Popularity / Recognizability V2

03E V1'de kariyer genişliği ve yüksek-popularity kulüplerde bulunma fazla ağırlık alıyordu.
Bu durum bazı journeyman oyuncuların dünya yıldızlarının üzerine çıkmasına neden oluyordu.

V2, kaynak ZIP'i yalnızca **iç popularity/selection metadata üretmek** için kullanır ve
source player ID'yi canonical ID ile kullanmadan önce normalize edilmiş oyuncu adını doğrular.

Kullanılan factual aggregate sinyaller:
- toplam appearance
- top competition appearance
- UCL appearance
- milli takım caps
- gol + asist toplamı
- last season / recency

Kulüp-context V1 skoru artık yalnızca %16 ağırlığa sahiptir.

Kullanılmayan alanlar:
- market value
- highest market value
- image URL
- source URL

CASUAL ve NORMAL havuzları factual aggregate kanıtı olan oyunculardan oluşturulur.
HARD havuzu legacy oyuncuları da korur.
Bu adım `assets/data` dosyalarını değiştirmez.
