# Club Manager — 38 haftalık kariyer

Kadro & Yönetim grubunda beş oyun doğrudan listelenir; bu grubun arama alanı kaldırıldı. Genel oyun araması korunur. Club Manager, Ortak Saha tasarımını kullanır ve kariyer/lig ekranlarını açarken oyuncu veritabanını beklemez. Oyuncu verileri kadro veya transfer ekranında yüklenir.

## Lig ve maçlar

- Kullanıcı dahil 20 takım, 19 farklı rakip ve 38 hafta vardır.
- İlk 19 haftada her rakiple bir kez oynanır; ikinci devrede aynı sıra ev sahibi/deplasman ters çevrilerek tekrarlanır. Her takım 19 iç saha ve 19 deplasman maçı yapar.
- Her hafta gerçek fikstüre bağlı 10 sonuç üretilir. Kullanıcının sonucu ile diğer dokuz maç tek kariyer kaydında saklanır. Tam sezon 380 karşılaşmadır.
- Galibiyet 3, beraberlik 1 puandır. Eşit puanda averaj, atılan gol ve kararlı takım kimliği sırası kullanılır.
- Ev sahibine +3 güç eklenir. Kadro gücü, ortak kulüp/ülke/lig bağları, taktik, rakibin oyun tarzı ve rastlantı sonucu etkiler. Rakipler kurmaca kulüplerdir.
- Zorluk rakip gücünü, başlangıç bütçesini ve galibiyet primini değiştirir. Maç sonucundaki isimler, istatistikler ve galibiyet hesabı deplasmanda da doğru tarafı gösterir.

## Kadro ve ekonomi

- Başlangıç kasaları kolay/orta/zor için 165/120/80 LINK; galibiyet primleri 12/18/28 LINK'tir. LINK bu modun oyun içi bütçesidir.
- İlk 11, dizilişin mevkilerine uygun 11 farklı oyuncudan oluşur. Kadro sınırı yedeklerle birlikte 25'tir.
- Yeni oyuncu seçimi önce taslakta tutulur; ödeme yalnızca kadro kaydedildiğinde alınır. Geri çıkışta kaydetme, vazgeçme ve düzenlemeye devam etme seçenekleri vardır.
- Sahip olunan oyuncu ilk 11 ve yedekler arasında ücretsiz taşınır. Diziliş değiştirildiğinde yer bulamayan oyuncu yedeklerde kalır. Maç başına tekrar oyuncu ücreti alınmaz.
- Uygun 11'i tamamlama, eldeki oyunculara öncelik verir ve kalan mevkilerde en ucuz uygun seçenekleri kullanır.
- Transfer teklifleri hafta başına kaydedilir; ekranı yeniden açmak teklifleri değiştirmez. Alımlar yedeklere eklenir, yedekler temel değerinin aşağı yuvarlanmış %70'ine satılabilir. İlk 11 oyuncusu doğrudan satılamaz.
- Aynı satın alma veya maç sonucu tekrar geldiğinde para/prim ikinci kez işlenmez. Çakışan sonuç ve eskimiş hafta/sezon işlemleri reddedilir.

## Kayıt ve sezon geçişi

Mevcut `club_manager_career_v8_<difficulty>` anahtarı korunur. Eski lig düzenindeki sezon silinmeden arşivlenir; kasa, ilk 11, yedekler ve kariyer toplamları korunarak 38 haftalık yeni sezon açılır. Kullanıcıya bu geçiş ekranda açıklanır. Bozuk bir kayıt sessizce yeni kariyerle değiştirilmez.

38. maçtan sonra sezon tamamlanır. Yeni sezona geçiş mevcut kadroyu, parayı ve kariyer toplamlarını taşır; biten sezon arşive eklenir, yeni lig tablosu sıfırdan başlar. Kariyeri sıfırlama ayrıca onay ister.

Kayıtlar cihazdaki SharedPreferences içindedir; bu değişiklik bulut senkronizasyonu eklemez. Aynı zorluktaki yazmalar uygulamanın kullandığı store üzerinde sıraya alınır. Maç kaydı hata verirse aynı skorla yeniden denenir.

## Doğrulama

- `manager_season_test.dart`: farklı rastgele tohumlarla tam fikstür, ev/deplasman dengesi, 380 sonuç ile puan tablosunun tutarlılığı ve eski/yanlış hafta reddi.
- `manager_career_test.dart`: eski kayıt geçişi, bozuk kayıt koruması, dizilişler, alım/satım, eşzamanlı işlem, tam 38 hafta ve sonraki sezon.
- `manager_match_test.dart`: ev/deplasman skorları, prim, şut/gol tutarlılığı, olay sırası ve ortak maç servisinin çevrimiçi modla uyumlu varsayılanları.
- `manager_pages_test.dart`: kariyerden maça ve sezona dönüş, fikstür/puan tablosu, taslak iptali, transfer ve kayıt hatasını yeniden deneme. Akış 390×844, 320×568 ve 700×400 ekranlarda; açık/koyu tema ve %200 yazı boyutunda çalıştırılır.
- `app_shell_navigation_test.dart`: Kadro & Yönetim grubunda arama olmaması, beş modun bulunması ve genel aramanın çalışmaya devam etmesi.

CI analiz, Flutter testleri ve Android debug APK derlemesini çalıştırır. Fiziksel cihazda yeni kariyer ve mevcut kayıtla ilk açılış ayrıca denenmelidir.
