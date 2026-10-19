# PDF kabul izleme — 105 madde

Otomatik kapsam bir yayın PASS kararı değildir. Her satır staging/iki hesap kabulünde ayrıca işaretlenmelidir.

| Kimlik | Öncelik | PDF beklentisi | Şu anki kanıt / kalan kabul |
|---|---|---|---|
| NAV01 | P0 | Kulüp × Ülke arkadaştan oda koduna, setup ve maça hep club_country taşınır. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| NAV02 | P0 | Kulüp × Kulüp girişinde club_club korunur; gizli varsayılan dönüş yok. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| NAV03 | P0 | Ranked desteği olmayan Club Manager yanlışlıkla ranked olarak açılmaz. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| NAV04 | P1 | İki menüde dokuz mod var; ekranda görünmeyen modlar bozulmadı. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| NAV05 | P1 | Kullanıcı farklı modeId oda koduna girerse net hata ve güvenli geri dönüş var. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| NAV06 | P1 | Oda kur/katıl, geri, çıkış ve arama iptali her mod için doğru route açar. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CORE01 | P0 | Aynı maçta iki farklı UID ve tek modeRuleVersion/dataRevision kullanılır. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| CORE02 | P0 | İki katılımcı aynı soru seed ve aynı izinli oyuncu havuzunu görür. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| CORE03 | P0 | Puanı etkileyen id/isim/ülke eşleştirmeleri V4 kanoniğine dayanır. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| CORE04 | P0 | Puzzle kapalı/eksik/verisiz olduğunda sahte soru veya skor üretilmez. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| CORE05 | P0 | Aynı ID için aynı maçta ikinci puan verilmez. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| CORE06 | P0 | İstemci aramasında cevap seti öne çıkarılarak spoiler verilmez. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| CORE07 | P0 | Sunucu maç statüsü bittiğinde hiçbir claim kabul etmez. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| CORE08 | P0 | Veri revizyonu değişince aktif maçın doğruluğu değişmez. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CORE09 | P1 | Süre ve sıra hakları iki oyuncu için adil dağıtılır. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CORE10 | P1 | Bitiş nedeni won/draw/forfeit/cancelled/expired ayrı raporlanır. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CORE11 | P1 | Eski sürüm maç açımı ve rollback kuralı geri uyumludur. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| SEC01 | P0 | A oyuncusu B oyuncusu kimliğiyle hamle gönderemez. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| SEC02 | P0 | RTDB doğrudan score artışı kabul etmez. | Üretim kuralı kapalı; gerçek emülatör testi eklendi |
| SEC03 | P0 | RTDB doğrudan winnerUid veya finished yazımını kabul etmez. | Üretim kuralı kapalı; gerçek emülatör testi eklendi |
| SEC04 | P0 | RTDB rank/Elo veya reward ledger istemci yazımına kapalıdır. | Üretim kuralı kapalı; gerçek emülatör testi eklendi |
| SEC05 | P0 | Server playerId ilişkisini ve seed hücre kriterini kendi doğrular. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| SEC06 | P0 | Server süre ve turnUid sahibini kontrol eder. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| SEC07 | P0 | Oynanmamış veya ikinci kez kullanılan actionId yeni skor yaratmaz. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| SEC08 | P0 | İstemcinin gönderdiği puan, hücre indeksi listesi, kulüp listesi kanıt değildir. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| SEC09 | P0 | Doğru cevap listesi oyun bitmeden halka açık RTDB payloadında yoktur. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| SEC10 | P0 | Aynı telefondan iki hesapla kendi kendine maç yapma/rate limit koruması işler. | Yayın kapısı: README kapsam/sınırları; PASS değil |
| SEC11 | P0 | Açık oda ve kuyruklar üçüncü tarafın maç durumunu değiştirmesine izin vermez. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| SEC12 | P0 | Her kesin sonuç sunucu kaydından yeniden üretilebilir. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| SEC13 | P0 | Cloud Function / RTDB izinleri hata olduğunda güvenli biçimde işlemi reddeder. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CL01 | P0 | Kulüp × Kulüp sorusunda tüm skor alan futbolcular gerçekten iki kulüpte oynamıştır. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CL02 | P0 | İki taraf aynı eşleşmede aynı doğru cevap evrenini kullanır. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CL03 | P0 | Cevap ID tekrarına ikinci skor verilmez. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CL04 | P1 | 90 sn bitiş, beraberlik ve maç sonu açıklama doğru. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CL05 | P1 | En az 8 doğrulanmış doğru cevap yoksa online maç güvenli şekilde üretilmez. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CC01 | P0 | Kulüp+ülke rolü baştan sona korunur. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CC02 | P0 | Ülke/uyruk normalizasyonu her iki cihazda aynıdır. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CC03 | P0 | Takım–ülke ortaklığında olmayan oyuncu skor alamaz. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CC04 | P1 | İki tarafın farklı seçim rolleri hazır ol aşamasında adil açıklanır. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CC05 | P1 | Kesişim boşsa tekrar seçim yapılır; otomatik sahte soru üretilmez. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| GC01 | P0 | Her Grid Klasik hücresi en az bir doğrulanmış futbolcuyla çözülebilir. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| GC02 | P0 | Yanlış playerId istemci transaction’ında hücre ele geçirmez. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| GC03 | P0 | Farklı Grid alt türü claimClassicCell tarafından reddedilir. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| GC04 | P0 | Aynı hücre iki kullanıcıya verilmez. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| GC05 | P1 | Üçlü tamamlanması, skor ve süre bitişi doğru. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| GC06 | P1 | 45 sn sıra limiti sunucu saatinde çalışır. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| GR01 | P0 | Grid Rastgele her iki oyuncuya aynı beş turu verir. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| GR02 | P0 | Her oyuncu beşer yanıt fırsatına sahiptir; 3/2 tur asimetrisi yoktur. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| GR03 | P0 | Turdaki doğrulanmamış oyuncu skor kazanmaz. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| GR04 | P0 | Rakibin cevabı her iki tur cevabı kapanmadan açıklanmaz. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| GR05 | P1 | Kişi başı tur süreleri eşittir. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| GR06 | P1 | Beş turun sonunda beraberlik/galibiyet doğru kapanır. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| GT01 | P0 | Grid Ters için her eksen doğru cevabı sunucuda kontrol edilir. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| GT02 | P0 | Yanlış axisKey veya yanlış ilişki skor üretmez. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| GT03 | P0 | Bir eksen iki kez ele geçirilmez. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| GT04 | P1 | Altı eksen bitişi ve 4 eksen anlık zafer kuralı çalışır. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| GT05 | P1 | 3–3 beraberlik doğru görüntülenir. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| RF01 | P0 | İki oyuncu aynı beş kulübü ve süreyi görür. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| RF02 | P0 | Sunucu bir futbolcunun 1-5 kulüp puanını V4 kanıtıyla hesaplar. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| RF03 | P0 | Aynı oyuncu ID’sine ikinci puan verilmez. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| RF04 | P0 | Gecikmeli yeniden gönderim idempotent makbuz döndürür. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| RF05 | P1 | 90 sn sonunda tam skor ve beraberlik doğru. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| RF06 | P1 | Kısa bağlantı kopmasında aynı maç oturumu geri yüklenir. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CI01 | P0 | Çinko 25 hücresinin kriterleri ve çözülebilirliği doğrulandı. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CI02 | P0 | İstemci yanlış indexes ekleyerek hücre boyayamaz. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CI03 | P0 | Sunucu oyuncunun uygun boş hücrelerini kendi hesaplar. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CI04 | P0 | Yanlış futbolcu yanlış kişiye bir kare devredemez. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CI05 | P1 | Satır/sütun/çapraz kazanma koşulları PASS. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CI06 | P1 | Tahta dolunca skor ve beraberlik PASS. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| LO01 | P0 | Loto 4×4 tahtası ve 16 oyuncu sunucu sürümüne sabittir. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| LO02 | P0 | Yalnızca doğru futbolcu/doğru hücre skor yaratır. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| LO03 | P0 | Aynı oyuncu ikinci kez yazılamaz. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| LO04 | P0 | İstemci saati değişikliği 180 sn maç süresini etkilemez. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| LO05 | P1 | Her iki oyuncuya uyumlu zorluk ve hamle süresi atanır. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| LO06 | P1 | Sonuç ve açıklanan boş hücreler iki telefonda eşittir. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CM01 | P0 | Her iki kullanıcı aynı bütçeyi ve havuz sürümünü alır. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CM02 | P0 | Her iki dizilişin 11 gerçek/tekrarsız oyuncu olduğu doğrulanır. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CM03 | P0 | Kadro/bütçe/kullanılabilir oyuncu sınırı sunucuda doğrulanır. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CM04 | P0 | Bir oyuncu rakibin henüz gizli takım/taktiğini göremez. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CM05 | P0 | Host kendi kazandığını söyleyen result yazamaz. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CM06 | P0 | Aynı seed ve snapshot aynı maç sonucunu üretir. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| CM07 | P1 | Ranked kapalıysa açık mesaj; oda maçları doğru çalışır. | Yayın kapısı: README kapsam/sınırları; PASS değil |
| EC01 | P0 | Sadece doğrulanmış ranked maçlar Elo hesaplamaya girer. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| EC02 | P0 | Arkadaş maçında Elo hiçbir durumda değişmez. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| EC03 | P0 | Günlük sadece üç eligible ranked sonuç temel ödül alır. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| EC04 | P0 | Ranked galibiyet 3 Coin +6XP; beraberlik 1+3; mağlubiyet 0+1 verir. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| EC05 | P0 | Bir maç için aynı UID’ye ikinci ödül yoktur. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| EC06 | P0 | İptal edilmiş / sunucu hatalı maç ödül üretmez. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| EC07 | P0 | Genel ekonomi tavanı bu mod özel ödül tablosunu kısıtlayabilir. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| EC08 | P0 | Guest hesap ranked ödül alamaz; iki kalıcı UID şartı doğrulanır. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| EC09 | P1 | Elo eski hesap geçmişini ve merkezi formülü bozmadan güncellenir. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| EC10 | P1 | Sonuç ekranındaki “beklemede/doğrulandı” ödül statüsü gerçeği gösterir. | Kod yolu mevcut; tam senaryo kabulü bekliyor |
| UX01 | P1 | Küçük Android ekranda Grid/Çinko/Loto taşma ve kesilme yok. | Flutter responsive/semantics testi ve ekran artifact incelemesi |
| UX02 | P1 | Kör kullanıcılar için seçilebilir alanlar anlamlı etiketli. | Flutter responsive/semantics testi ve ekran artifact incelemesi |
| UX03 | P1 | Ranked ve arkadaş etiketleri açık; Elo ikonları doğru yerde. | Flutter responsive/semantics testi ve ekran artifact incelemesi |
| UX04 | P1 | Davet, iptal, rövanş ve üç maçlık seri akışları net. | Flutter responsive/semantics testi ve ekran artifact incelemesi |
| UX05 | P1 | Hatalı soru / boş veri / kaybolan bağlantı için güvenli son durum. | Flutter responsive/semantics testi ve ekran artifact incelemesi |
| UX06 | P1 | Solo değişiklikleri temel oyuncu çözme mantığını bozmadı. | Flutter responsive/semantics testi ve ekran artifact incelemesi |
| NET01 | P0 | Bağlantı kesildiğinde sunucu geçerli maç saatini korur. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| NET02 | P0 | 30 sn yeniden bağlanma penceresi ve sunucu taraflı bitiş nedenleri doğru. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| NET03 | P0 | Sunucu hatasında tarafsız iptal; haksız Elo/ödül üretilmez. | Yayın kapısı: README kapsam/sınırları; PASS değil |
| NET04 | P0 | İki oyuncu aynı hamleyi aynı anda gönderdiğinde yalnızca bir kabul var. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| NET05 | P1 | Kuyruk iptal/timeout olunca artık eşleşme hayaleti yok. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
| NET06 | P1 | İki gerçek hesap Android APK ve emülatör eş zamanlı smoke PASS. | Yayın kapısı: README kapsam/sınırları; PASS değil |
| NET07 | P1 | En az bir eski istemci–yeni sunucu uyumsuzluğu güvenli fail üretir. | Callable/hizmet/route otomatik testi; cihaz kabulü bekliyor |
