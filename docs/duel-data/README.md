# Tek kriterli mod: oyuncu ve menajer veri çalışması

Durum: **ilk denetim ve kaynaklı araştırma paketi tamamlandı; oyun verisi yayına hazır değil.**
İnceleme tarihi: 14 Ekim 2026. Temel: `a2133482` ve V4 `v4-2026-10-05.1`.
Bu paket yeni kriter açmaz, mevcut modları veya V4 SQLite dosyasını değiştirmez.

## Denetim sonucu

| Alan | Bulgular | Sonuç |
| --- | --- | --- |
| Oyuncular | 36.391 kayıt | Kimlik sayısı, istatistik kapsamı değildir. |
| Boy | 6.921 dolu | Kaynak doğruluğu ve uygun oyuncu havuzu ayrıca kontrol edilmeli. |
| Doğum yılı | 13.216 dolu | Tam yaş hesabı için yeterli değil. |
| Tam doğum tarihi | Ayrı ESPN kataloğunda 500 oyuncu | V4 kimlik eşleştirmesi henüz doğrulanmadı. |
| Piyasa değeri | 13.227 pozitif | Güncel değer olarak sunulamaz; ortak tarih gerekli. |
| Zirve piyasa değeri | 26.591 pozitif | Kaynak, para birimi, zirvenin kapsadığı dönem gerekli. |
| Kariyer golü | 25.434 pozitif | Kulüp/millî kapsamı ve kesim tarihi belirsiz. |
| Millî maç | 6.963 dolu, 3.102 sıfır | Sıfırları doğrulanmış yokluk saymak hatalı. |
| İstatistik özeti | 6.958 oyuncu | 3.715 kayıt `PARTIAL_OR_UNKNOWN_WINDOW`; kalan 3.243 kaydın `LIKELY_COMPLETE_MODERN_WINDOW` etiketi de doğrulama değildir. |
| Menajerler | 5.285 kayıt | Başarı/maç/galibiyet/sezon tablosu yok. |
| Menajer kulüp bağı | 48 menajerde dolu, 5.237 boş | Kulüp sayısı veya kariyer uzunluğu kriteri için hazır değil. |
| Menajer ülke | 3.627 dolu, 1.658 boş | Eksik ülkeyi tahmin ederek doldurmayacağız. |
| Menajer ad çakışması | Normalize edilmiş adlarda 263 grup | Bunlar olası mükerrer/adaş kayıtlar; otomatik birleştirilmedi. |

Tüm menajerlerde `rating` bulunması gerçek maç, kupa veya galibiyet istatistiği sağlamaz.
48 menajerin kulüp bağlantıları referans olarak geçerli; görev tarihleri ve rol kanıtı ayrıca gerekli.
SQLite menajer payload'ları ile `coaches_min.json` bu sürümde eşit.
Sayısal rapor: `audit.json`. Denetim canlı internet erişimi istemez.

## Eklenen araştırma verisi

`tools/duel_data/reviewed_facts.json` içinde **31 rol bazlı kimlik, 31 doğrulanmış istatistik kaydı ve 66 sezon/ödül olayı** var:

- 19 teknik direktörün Avrupa Şampiyon Kulüpler Kupası / Şampiyonlar Ligi şampiyonluk sezonları. Kapsam 1956–2025; 2026 başarıları bu tarihli pakete dahil değil.
- 10 futbolcunun erkekler Ballon d'Or kazanma yılları; 2025 sonuna kadar. FIFA Ballon d'Or dönemi tek sayılır; The Best ve adaylıklar dahil değil.
- Buffon için FIGC'den doğrulanmış 176 A millî maç; son maç 23 Mart 2018. Mevcut V4'teki sıfırla çelişki işaretlendi. Doğru değer araştırma paketinde; runtime düzeltmesi henüz uygulanmadı.
- Fatih Terim'in Galatasaray ile sekiz lig şampiyonluğu, sezonlarıyla ve **19 Mayıs 2019** kesim tarihiyle. Bu tarihli kayıt güncel tüm kariyer kupası gibi kullanılamaz.

31 kayıt, bütün alanları tamamlanmış 31 kişi demek değildir. Örneğin menajer için doğrulanan Avrupa kupası sayısı, toplam kariyer kupalarının tamamlandığı anlamına gelmez.

Palmarès listesindeki 26 menajerin 18'i isim/alias üzerinden mevcut katalogda aday eşleşme veriyor. Bu eşleşmeler otomatik onaylanmaz. Bulunamayan sekiz isim için UEFA kaynaklı başarı kayıtları ayrı araştırma kimlikleriyle hazırlandı: Bob Paisley, Ottmar Hitzfeld, Jupp Heynckes, Arrigo Sacchi, Louis van Gaal, Marcello Lippi, Fabio Capello, Rinus Michels.
Pavel Nedvěd için de resmî ödül kaydı var, mevcut V4 kimliği bulunamadı.
Bu dokuz kimliğe sahte SQLite ID atamadık; ana kataloğa ekleme ve tam biyografik bilgiler bekliyor.

Ronaldo Nazário'nun V4 kimliği **3140**. Veritabanındaki aynı adlı diğer Ronaldo kayıtları kullanılmadı.
Zidane'ın oyuncu kimliği **3111**, menajer SQLite kimliği **-5284**; menajer payload kimliği de ayrı saklanır. Oyuncu ödülü ve menajer kupası toplanmaz.

## Kaynak ve sayım sözleşmesi

- Palmarès **keşif kaynağıdır**; Wikipedia başarı tablolarını kullanır. Bu iki site birbirinin bağımsız doğrulaması değildir.
- Başarı başına turnuva/ödül, sezon, takım, rol, kaynak ve tarih tutulur. Ad değiştiren turnuvalar açık kapsam altında birleştirilir.
- `null`/eksik kayıt sıfır değildir. Bilinen sıfır ancak tamamı kontrol edilmiş ilgili kapsam için yazılabilir.
- `primary_checked`, yalnızca kayıt için belirtilen tarih ve kapsamı doğrular; tüm oyuncu/menajer evrenini doğrulamaz.
- Sezonlar `YYYY-YYYY` biçimindedir; ödüller takvim yılıdır. Aynı kişi/rol/ödül/sezon iki kez sayılamaz.
- Oyunculuk, başantrenörlük ve yardımcı antrenörlük ayrı tutulmalıdır. Bu paket yalnızca oyuncu ve başantrenör rollerini içerir.
- Kazanan kadroda bulunmak, finalde oynamak ve finali kazanmak ayrı ölçülerdir. Birbirine dönüştürülmez.
- Lig kupası, süper kupa, hazırlık kupası, genç takım ve iptal edilen şampiyonluklar için kapsam tanımlanmadan toplam kupa hesaplanmaz.
- Bir kulüpte bulunmak, o kulübün o sezonki kupasına hak kazanmayı tek başına kanıtlamaz.
- Mevcut `Player.fromJson` eksikleri sıfıra çevirebildiği ve bazı değerlerde rating fallback kullandığı için yeni modun puanı bu uyumluluk modelinden doğrudan hesaplanmamalı. Kaynaklı, nullable ve kapsamlı yeni veri okuma katmanı gerekir.

## Sıradaki tamamlama işleri ve kabul koşulları

| Öncelik | İş | Tamamlanma koşulu |
| --- | --- | --- |
| P0 | Menajer mükerrer/adaş kontrolü, dokuz yeni kimliğin ana kataloğa eklenmesi | Rol, ülke, biyografik kimlik ve takım geçmişi kaynakla uyuşur; gerçek ID eşlemesi ve alias kontrolü geçer. |
| P0 | Buffon düzeltmesi ve diğer sıfır millî maç kayıtlarının incelenmesi | Oyuncu başına A millî kapsam ve kesim tarihi doğrulanır; inceleme yapılmayan sıfırlar bilinmiyor kalır. |
| P0 | Boy ve doğum tarihi kaynaklarının kontrolü | Seçilen oyuncu havuzunun tamamında veri ve kimlik doğrulanır; ESPN–V4 eşlemesi tamamlanır. |
| P1 | Menajer başarılarını genişletme | Önce Avrupa kupaları ve üst lig şampiyonlukları; sonra ulusal kupa/süper kupa ve millî başarılar. Her olayın rol ve sezon kanıtı bulunur. |
| P1 | Menajer kariyer ve maç verileri | Başlangıç/bitiş, başantrenör/yardımcı rolü, lig/turnuva ve maç kapsamı ayrılır. Galibiyet oranı yalnızca aynı kapsamın pay/paydasından hesaplanır. |
| P1 | Oyuncu kariyer ve değer istatistikleri | Eksik kariyer pencereleri tamamlanır veya açık tarihli dar kapsam seçilir; güncel ve tarihsel değer karışmaz. |
| P2 | Mod için uygunluk ölçümü | Her zorunlu mevki/rol için yeterli doğrulanmış alternatif, anlamlı puan dağılımı ve oynanabilirlik testi bulunur. |
| P2 | Uygulama aktarımı | V4 manifest/hash, istemci/sunucu veri sürümü ve eski mod regresyonları birlikte doğrulanır. |

İlk havuz hedefi olarak 300–500 tanınır oyuncu ve 30–50 menajer değerlendirilebilir; bunlar **doğrulanmış mevcut kapsam değil, önerilen çalışma hedefleridir**. Hedefi tutturmak için bilinmeyen değer doldurulmaz. Tüm 36 bin oyuncuyu silmek veya daraltmak gerekmez; sadece yeni modun onaylı havuzu ayrılır.

Menajerlerin ayrı düello havuzu mu yoksa uyumlu hedeflerde ayrı bir menajer slotu mu kullanacağı henüz kararlaştırılmadı. Boy veya futbolcu golü gibi hedeflere menajer eklenmez. Önce veri kapsamı tamamlanacak, sonra oyun kuralı kesinleşecek.

## Tekrar çalıştırma — PowerShell

Proje kökünde Python 3.10+ ile, ek paket kurmadan:

```powershell
python tools/duel_data/validate.py
python tools/duel_data/audit.py
python -m unittest discover -s tools/duel_data -p "test_*.py" -v
```

`validate.py` kaynak, rol, gerçek yerel kimlik, DB hash'i, mükerrer sezon, tarih sınırı ve toplam/olay eşitliğini denetler. Bilginin futboldaki doğruluğunu program tek başına kanıtlayamaz; kaynak incelemesi ayrıca yapılmıştır. Farklı V4 hash'inde otomatik aktarım engellenir. Testler yeni kriter açılmasını da reddeder. APK derlemesi veya Firebase deploy bu çalışma için gerekmez.

## İncelenen kaynaklar

- [Palmarès menajer dizini](https://palmares.fyi/managers/) ve [kaynak/kapsam açıklaması](https://palmares.fyi/about/).
- [UEFA: Avrupa Kupası kazanan teknik direktörler](https://www.uefa.com/uefachampionsleague/news/0275-15407684c988-5b733e851bf5-1000--champions-league-winning-coaches-carlo-ancelotti-leads-th/).
- [UEFA: Ballon d'Or kazananları](https://www.uefa.com/ballondor/news/0292-1c27056169a7-bc88d1fdba43-1000--ballon-d-or-laureates-who-has-won-football-s-most-prestig/).
- [FIGC: Buffon A millî kariyer kaydı](https://www.figc.it/en/national-teams/news/gigi-buffon-a-record-breaking-head-of-delegation-igxto0vw).
- [Galatasaray: Fatih Terim'in sekiz şampiyonluk sezonu](https://www.galatasaray.org/haber/futbol/fatih-terim-in-8-sampiyonlugu/44201).

Kaynak URL'leri, yayın/erişim tarihleri ve kullanım kapsamları makine tarafından okunabilir pakette de bulunur. Site metinleri veya görselleri topluca kopyalanmadı; seçili olgular ve kaynak referansları kaydedildi.
