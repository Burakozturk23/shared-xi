# Kadro Düellosu veri entegrasyonu — 15 Ekim 2026

**Veri okuma altyapısı entegre edildi; 24 kriterin hiçbirinin oyuncu kapsamı henüz yayına yeterli değil.**
Bu değişiklik bütün kariyer verilerinin tamamlandığı veya modun oynanabilir olduğu anlamına gelmez.
Kesim tarihi **2025-12-31**, paket sürümü `duel-2026-10-15.1`.

## Eklenen gerçek veri

| İçerik | Adet | Kullanımı |
| --- | ---: | --- |
| ESPN kaynak çıktısı | 17 | Güncel profil gözlemi; tarihli maç/aktiflik kanıtı değil |
| StatsBomb maç metaverisi çıktısı | 7 | Mevcut yedi finalin kadro kayıtlarıyla eşleşir |
| V4 kimliğine eşleşen ESPN futbolcusu | 456 | İsim/alias + doğum yılı + ülke kontrolü |
| Profil gözlemi | 1.342 | Doğum tarihi, inç cinsinden boy, vatandaşlık; puan alanından ayrı |
| Çözümlenemeyen profil satırı | 54 | Tahminî ID üretilmeden denetim raporunda tutulur |
| Mevki uyuşmazlığı | 13 | Mevcut ana mevki otomatik değiştirilmez |
| Sahaya çıkan futbolcu–maç kaydı | 189 | 137 satır mevcut V4 futbolcu kimliğine bağlı |
| Çıkarılan kullanılmamış yedek satırı | 53 | Maç veya menajer altında oynama sayılmaz |
| Kaynak menajer kimliği | 11 | Başantrenör rolü; V4 ID eşleştirmesi bekliyor |
| Benzersiz kaynak futbolcu–menajer çifti | 162 | Tam kariyer bağlantı toplamı değildir |
| Doğrulanan farklı futbolcu–kulüp bağı | 103 | Resmî A takım maçında oynama kanıtı |
| Puan sözleşmesine alınan kariyer metriği | 7 | Aşağıdaki üç futbolcu için |
| Yan paketteki mevcut V4 kimliği | 544 | Profil, maç veya doğrulanmış metrik kaydı olanlar |

54 ve 13 sayıları kaynak satırlarıdır; ayrı futbolcu sayısı olarak sunulmamalıdır.
193 StatsBomb futbolcu kimliği yedekler dahil kaynak kimlik dizinidir; 189 ise yalnızca oynayanların maç satırlarıdır.
Ana veritabanındaki **36.391 oyuncu** korunur. 544 yan paket kimliği veya 120 kabul eşiği bir oyuncu üst sınırı değildir.
Yeni doğrulanan her mevcut oyuncu kimliği aynı sözleşmeyle havuza katılabilir; 24 kişilik liste veya popülerlik sınırı yoktur.

| Oyuncu | F15: A millî maç | F16: A millî gol | F18: UCL gol, eleme hariç |
| --- | ---: | ---: | ---: |
| Gianluigi Buffon | 176 | Bilinmiyor | Bilinmiyor |
| Thierry Henry | 123 | 51 | 50 |
| Ruud van Nistelrooy | 70 | 34 | 56 |

“Bilinmiyor” burada bu pakette onaylanmış değer yok demektir; sıfır anlamına gelmez.
Buffon düzeltmesi yeni mod okuyucusundadır. Eski `Player` modelinin veya başka modların değerleri değiştirilmedi.
Henry ve Van Nistelrooy için kesim tarihinden önce emeklilik kanıtı var. 2026 UEFA tablosundan yalnızca bu iki emekli oyuncunun tamamlanmış UCL toplamı alındı; aktif oyuncuların 2026 değerleri 2025'e taşınmadı.
Van Nistelrooy'un emeklilik haberindeki **60** UCL golü eleme içerir; F18 için açıkça eleme hariç tablodaki **56** kullanılır.

Kaynak URL'leri, kısa bulgular ve eşleştirme kontrolleri `tools/duel_data/approved_metrics.json` ve `reviewed_facts.json` içindedir.
Ham makale metni veya görseli paketlenmez. ESPN/StatsBomb çıktıları seçilmiş olgusal alanları, erişim zamanını ve asıl yanıt SHA-256 izini saklar.
StatsBomb verisinin kaynağı [StatsBomb Open Data / hudl](https://github.com/hudl/open-data)'dır; kullanımda upstream lisans ve atıf koşulları korunmalıdır.
Palmarès keşif kaynağı olarak önceki araştırmada kalır; onaylanmamış kupa toplamları puana dönüştürülmez.

## Kriterlerin eksik tarafı

| Kriterler | Tamamlanması gereken veri |
| --- | --- |
| F01, F02 | Tüm resmî A takım kulüp/lig katılımları; ulusal lig sistemi eşlemesi |
| F06 | Kesim tarihiyle uyumlu kesin santimetre boy; yuvarlanmış ESPN inç değeri yeterli değil |
| F07 | Kesin doğum tarihi + 2025-12-31'de aktiflik kanıtı |
| F08 | Tek sağlayıcıdan tarihli, EUR cinsinden zirve değer geçmişi |
| F10, F12 | Bütün resmî kulüp maçlarının eksiksiz maç/gol toplamları |
| F13, F14 | Tek sağlayıcıdan bütün kulüp asistleri; golle birebir aynı maç kapsamı |
| F15, F16 | Eksiksiz A millî maç/gol kapsamı; mevcut 3/2 oyuncu yeterli değil |
| F17, F18 | 1992 sonrası ana UCL turnuvası, elemeler hariç; F18'de 2 oyuncu yeterli değil |
| F20 | Beş büyük ligdeki bütün lig maçları |
| F21, F22 | Her kariyer kulübü için eksiksiz maç/gol toplamları |
| F24, F25, F29 | Onaylı lig/ana kupa listesi ve oyuncunun sezonluk kupa hak sahipliği |
| T01, T02, T09 | Eksiksiz oyuncu–başantrenör maç bağlantıları; T09 için ayrıca adı açıklanan menajer bağlamı |
| T07 | Oyuncu ve başantrenörün aynı takım/sezonda ortak kupa hak sahipliği |
| T10 | Eksiksiz birlikte oynama bağlantısı + kesim tarihine kadar EC/UCL kazanan başantrenörler |

V4'teki 6.958 istatistik satırı silinmedi. Kısmi veya kapsamı belirsiz sayılar tam kariyer toplamı sayılmadı.
Yedi finalden bütün kariyer maçları, en çok birlikte oynanan menajer veya kazanılmış bütün kupalar hesaplanamaz.
F12/F13/F14/F16/F18/F22 korunur; kaleci için kaynakla doğrulanmış sıfır geçerlidir ve bu kriterleri kapatma gerekçesi değildir.

## Uygulama sözleşmesi

- `GameDataV4QueryService.duelData()` yeni `DuelDataCatalog` okuyucusuna erişir.
- Paket ilk ihtiyaçta yüklenir; hatalı SHA-256, sürüm veya temel DB izi varsa `null` döner, `lastError` tutulur.
- `verifiedMetric()` yalnızca kanıtlı sayıyı verir; bulunamayan sayı `null` kalır. Bu çağrı kriterin oynanabilir olduğunu göstermez.
- `availableCriteria` yalnızca veri ve kabul kapıları geçen kriterleri döndürür. Mevcut pakette boştur.
- Her kriterde en az 120 doğrulanmış oyuncu, GK 10 / DEF 20 / MID 20 / FWD 10 asgari kapsamı ve onaylı koşul/oynanış kontrolleri gerekir.
- `eligiblePlayerIds()` kriter + mevki + **ülke veya kariyer kulübü** + iki tarafta seçilmiş oyuncuların dışlanmasını uygular. Kulüp filtresi toplam puanı o kulübün gollerine daraltmaz.
- Tur sırası `GK → DEF → MID → DEF → MID → FWD`; kadro 1 GK, 2 DEF, 2 MID, 1 FWD'dir. Menajer slotu yoktur.
- `candidateConditions()` sadece mevcut turda en az altı aday olduğunu gösterir. Çekiliş için tek başına kullanılmaz.
- `safeConditions()` kalan aynı mevki turları için her turda iki seçim düşülse bile altı aday bırakacak yedek koşul arar. Bu yeterli ama muhafazakâr bir devam garantisidir; bazı oynanabilir koşulları reddedebilir. Başka güvenli koşul yoksa aynı koşulun tekrarına izin verilmelidir.
- Sunucudaki `functions/lib/duel_data.js` aynı kontrol ve paketle çalışır; `score()` altı ayrı oyuncu, mevki ve tur koşulunu doğrular. Yeni callable veya eşleştirme endpoint'i açılmaz.
- Gelecekte maç sunucusu iki tarafın seçimlerini birlikte yetkilendirmeli; 25 saniye, AB/BA sırası, turda ortak koşul, maç başına tek kriter ve eşzamanlı seçim kuralları burada uygulanan veri API'sinin kapsamı dışındadır.
- T09 menajer bağlamı ve düşük/yüksek yönüne göre kazanan belirleme ileride maç sözleşmesinde uygulanmalı; yalnızca toplam hesaplayan mevcut yardımcı bunları tamamlanmış saymaz.

## Tekrarlanabilir üretim ve test

Kaynak toplama ayrı ve isteğe bağlıdır: `python tools/duel_data/collect_sources.py`.
Bu komut internetteki **güncel** çıktıları yeniler; yeniden inceleme olmadan üretilen paketi yayınlamayın.
Paket üretimi internet kullanmaz. Kaynak, kapsam veya eşleştirme değişince sürümü artırıp denetim raporunu yeniden inceleyin.

```powershell
# Proje klasöründe; mevcut yerel değişikliklerinizi önce kaydedin.
git fetch origin codex/duel-criteria-integration
git switch codex/duel-criteria-integration

python tools/duel_data/build_runtime.py --check
python -m unittest discover -s tools/duel_data -p "test_*.py"
node --test functions/test/duel_data.test.js

flutter pub get
flutter test test/duel_data_test.dart
```

İlk kez dalı açarken `git switch` uzak dalı otomatik bulamazsa:
`git switch --track -c codex/duel-criteria-integration origin/codex/duel-criteria-integration`.
Bu dal `codex/duel-data-audit` üzerine kuruludur; ana dala tek başına veri dosyaları kopyalanmamalı.

Yerel doğrulama: 18 Python testi, yeni mod için 11 test dahil 324 Node testi ve Functions ESLint denetimi geçti. Flutter SDK bu çalışma ortamında yok; 10 Dart testi yerelde çalıştırılmadı. Mevcut Flutter CI analizi/testleri yeni testi de kapsar. Ayrı `Duel data contract` CI, paket üretiminin tekrarlanabilirliğini Python/Node ile denetler. Byte düzeyindeki kaynak/paket kontrolleri için UTF-8 ve LF satır sonları Windows'ta da sabittir.
