# Grid'de teknik direktör kriteri: tasarım

Tarih: 2026-11-08 · Durum: onay bekliyor. Yazarın kararları **[yazar kararı]** olarak işaretli.

## 1. Amaç
Grid tahtalarına kulüp, ülke ve ligin yanında **teknik direktör** kriteri eklemek. Örnekler (sahibinin):
- "Fatih Terim × Barcelona" → Hagi (Terim'in Galatasaray'ında oynadı, Barcelona'da da oynadı).
- "Şenol Güneş × Benfica" → Talisca (Güneş'in Beşiktaş'ında oynadı, Benfica'da da oynadı).

Hoca ile diğer kriter arasında bağ gerekmez; futbolcunun ikisini de sağlaması yeter.

## 2. Kapsam (sahibinin kararları)
- Bütün Grid modları: bot Klasik / Tersten / Rastgele, arkadaşla ve online (dereceli dahil).
- Yalnız **tanınmış** teknik direktörler; çok zor isimler yok. **50 hoca**: ~25 Türkiye'de tanınan (ör. Fatih Terim, Şenol Güneş, Mustafa Denizli, Abdullah Avcı, Ersun Yanal, Okan Buruk, Jorge Jesus, Mircea Lucescu) + ~25 dünya çapında (ör. Mourinho, Guardiola, Ancelotti, Klopp, Ferguson).
- Ücretli veri planı yok.
- Bir tahtada **genelde 1, en fazla 2** teknik direktör kriteri.

Hedef dışı: Loto, Çinko, Rastgele Beşler, Takım Yarışı (sonra ayrıca konuşulur); tasarım/görsel yenileme (ayrı iş).
Karşı hedef: Doğru cevabı reddeden kutu (veri eksik diye bilinen bir cevabın "yanlış" sayılması), çok az cevabı olan teknik direktörlü kutu.

## 3. Kural
"X ile çalışmış" = futbolcunun bir kulüp dönemi, X'in **aynı kulüpteki görev süresiyle tarih olarak çakışıyor** **[yazar kararı]**. Kiralık dönemler de sayılır. En az 1 gün çakışma yeterli; görev başlangıcından önce biten ya da bitişinden sonra başlayan dönem sayılmaz.

## 4. Veri
Bugün: 5.285 hoca adı (`coaches` tablosu, `assets/data/coaches_min.json`); yalnız 48'inde kulüp listesi, hiçbirinde tarih yok. Futbolcuların tarihli kulüp dönemleri `career_spells` tablosunda (~7.000 futbolcu, 38.166 dönem) — `assets/runtime/linkball_game_data_v4.sqlite`.

Eklenecek **[yazar kararı]**:
1. **Hoca listesi (50):** §2'deki dağılımla; elle gözden geçirilebilir JSON dosyası `tools/pvp/coach_pool.json` (ad, veritabanı `coach_*` kimliği, Wikidata kimliği).
2. **Görev geçmişi (sahibinin kararı: ücretsiz kaynak):** Her hoca için kulüp + başlangıç/bitiş tarihleri **Wikidata**'dan (anahtar gerektirmez) **bir kez** çekilir ve depoya `tools/pvp/coach_tenures.json` olarak yazılır; oyun sırasında dışarıya bağlanılmaz. Kulüpler veritabanı kulüp kimliklerine eşlenir; eşlenemeyen ya da tarihi eksik dönem atılır ve rapora yazılır. Liste sahibine dosya olarak sunulur, elle düzeltilebilir; bilinen örneklerle (Terim–Hagi, Güneş–Talisca) karşılaştırılır.
3. **Eşleme çıktısı:** `coach:<id>` kriteri → üye futbolcu kimlikleri, `tools/pvp/build_catalog.py` içinde mevcut `club:`/`country:`/`league:` kriterlerinin yanında üretilir ve `functions/config/pvp_catalog.json.gz`'ye girer. Kriter etiketi hocanın adı, `type: "coach"`.
4. **Uygunluk:** Bir hoca kriteri ancak en az **15** futbolcuya ve en az **5** "tanınmış" (popüler sıralı) futbolcuya sahipse tahtaya girebilir **[yazar kararı]**; aksi hâlde katalogda kalır ama seçilmez.

Bilinen sınır: Tarihli kariyeri olmayan futbolcular hoca kriterini hiç sağlamaz. Bu yüzden hoca kutusunun cevap kümesi yalnız tarihli futbolculardan oluşur; tahta üretimi yalnız yeterli cevabı olan hoca × kriter çiftlerini seçer (§5), böylece "doğru ama veride yok" riski düşük tutulur.

## 5. Tahta üretimi
- **Klasik ve online Grid:** Tahta oluşturulurken satır/sütun kümesine en fazla 2 hoca kriteri girer; varsayılan olasılık "tahtaların ~%60'ında 1 hoca, ~%15'inde 2, gerisinde 0" **[yazar kararı]**. Her hoca kesişimi mevcut adil tahta kuralına uyar (her kutuda en az `FAIR_MIN_ANSWERS` cevap, iyi bilinen cevap şartı). İki hoca aynı tahtada satır×sütun olarak kesişmez (iki hocalı kutu yok) **[yazar kararı]**.
- **Rastgele Grid:** Rastgele üretilen çiftlere hoca kriteri aynı kotayla girer.
- **Tersten Grid:** Üç futbolcunun ortak kriteri hoca da olabilir; `common()` hoca kriterlerini de döndürür, kabul edilen cevaplar listesinde görünür.
- **Online/dereceli:** Tahtalar mevcut `pvp_engine` katalog tahtalarından gelir; katalog yeniden üretilir, `RULE` sürümü artırılır (eski odalar eski kuralla biter).

## 6. Oyun içi
- Hoca kriteri kartı hocanın adını ve mevcut `CoachAvatar` görselini (varsa) gösterir; yoksa adı.
- Cevap doğrulaması sunucuda, kriter üye kümesiyle (diğer kriterlerle aynı yol).
- Bot: hoca kutularında da mevcut zorluk/isabet kurallarıyla cevap verir (üye kümesinden).
- İpucu v2: Grid ipuçları (milliyet, mevki, lig, başka kulüp, ilk harf) hoca kutusunda da çalışır; "Başka bir kulübü" ipucu hocanın kulübünü dışlamaz (gerek yok) **[yazar kararı]**.
- Tersten Grid "Kriter türü" ipucuna "Teknik direktör" türü eklenir.

## 7. Uygulayıcıya bırakılanlar
- Wikidata kulüp → veritabanı kulüp kimliği eşleme yöntemi (ad + ülke; belirsizler rapora).
- Hoca listesinin ilk taslağı ve görev tabloları, katalog üretilmeden önce sahibine gözden geçirmek için sunulur.
- Katalog boyutu ve bellek: hoca kriterleri katalogu birkaç MB büyütebilir; PvP fonksiyonları 512MiB'ta, ölçülüp gerekirse ayarlanır.

## 8. Doğrulama
- Örnekler testte: Fatih Terim × Barcelona kümesinde Hagi; Şenol Güneş × Benfica kümesinde Talisca (veride varsa).
- Hiçbir tahtada 2'den fazla hoca kriteri yok; hoca×hoca kutusu yok; her hoca kutusu adil tahta şartını sağlıyor.
- Tersten Grid'de hoca ortak kriteri kabul ediliyor.
- Online: yeni kural sürümüyle eski odalar bozulmuyor.
