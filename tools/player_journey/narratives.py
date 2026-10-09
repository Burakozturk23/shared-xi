"""Spoiler-free, stage-specific editorial layer. No new career claims or answer names."""
NARRATIVES = {
'messi': [
'Arjantin’den Avrupa’ya uzanan yolculukta genç bir yetenek, altyapıdan profesyonel sahneye geçmeye hazırlanıyordu. Büyük kariyerin ilk resmi adımının izini sür.',
'Tek başına yetenek, bir takımın bütün hikâyesini anlatmaz. Messi’nin yükseliş yıllarına bu kez yanında forma giyen futbolcuların gözünden bak.',
'Uzun bir kariyerde takımın yüzü değişir; kimi isimler vedalaşırken yenileri gelir. Şimdi aynı formayı giymekle aynı dönemi paylaşmak arasındaki farkı hatırla.',
'Bir kulüple özdeşleşen kariyer, yeni ülkelerde başka sayfalar açabilir. Messi’nin A takım yolculuğuna uzaktan bak ve duraklar arasındaki bağlantıyı kur.'],
'ronaldo': [
'Genç bir kanat oyuncusunun yükselişinde ilk büyük transfer önemli bir eşikti. Yıldızlığa uzanan bu yolda iki bilinen durak arasındaki boşluğu tamamla.',
'Ronaldo’nun ilk İngiltere yılları, yeteneğinin takım oyunu içinde geliştiği dönemdi. O günlerin soyunma odasını düşün; yanında kimler vardı?',
'Yeni bir ülke, yeni beklentiler ve daha büyük bir sahne… Ronaldo’nun İspanya yıllarındaki kadroyu, kulübün başka dönemleriyle karıştırmadan hatırla.',
'Yolculuk bazen geriye dönmeyi de içerir. Ronaldo’nun ilk adımlarından tanıdık bir formaya dönüşüne uzanan bu kesitte, her durağın yerini bul.'],
'ronaldinho': [
'Brezilya’da dikkat çeken oyun neşesi artık başka bir kıtanın tribünleriyle buluşacaktı. Ronaldinho’nun Avrupa macerasını başlatan ilk adımı hatırla.',
'Yeni bir ülkedeki ilk yıllar, yeni takım arkadaşları demektir. Ronaldinho’nun Avrupa’ya alıştığı dönemin kadrosunda birlikte sahaya çıkan isimleri ara.',
'Topla kurduğu ilişki bir dönemin futbol hafızasına kazındı. Şimdi o parlak yılları düşün ve farklı kuşaklardan isimler arasında doğru bağı kur.',
'Yeni şehirler, farklı oyun kültürleri ve eve dönüş… Ronaldinho’nun bu yolculuğunda anılar birbirine karışmadan, durakları yeniden bir araya getir.'],
'modric': [
'Büyük liglere uzanan yolculuk, önce kendi ülkesinde kazanılan deneyimle şekillendi. Modrić’in İngiltere’ye çıkmadan hemen önceki basamağını hatırla.',
'Orta sahada oyunun ritmini değiştiren bir futbolcu, çevresindeki oyuncularla da iz bırakır. Modrić’in İngiltere yıllarındaki ortak formaların peşine düş.',
'Orta sahadaki denge, birbirini tamamlayan oyuncularla kurulur. Modrić’in İspanya kariyerinde aynı sahayı paylaştığı isimle daha eski kuşakları ayır.',
'Bir sonraki transfer, yıllarca sürecek bir kariyer sayfasının başlangıcı olabilir. Modrić’in İngiltere’den ayrıldığı eşikteki yeni adresini hatırla.'],
'zidane': [
'Büyük Avrupa sahnesinden önce, Fransa’da olgunlaşan bir oyun vardı. Zidane’ın ilk kulübü ile İtalya macerası arasındaki köprüyü bul.',
'İtalya yıllarında teknik beceri, güçlü bir takımın içinde yeni bir anlam kazandı. Zidane’ın o dönemde aynı formayı paylaştığı iki ismi hatırla.',
'Yıldızlarla dolu bir takımın da kendi kuşağı ve zamanı vardır. Zidane’ın İspanya’daki oyunculuk yıllarını, daha sonra gelen isimlerden ayır.',
'Zidane’ın oyunculuk hikâyesine baştan sona bakma zamanı. İlk profesyonel adım ile son kulüp arasındaki durakları, yılların akışı içinde birleştir.'],
'kaka': [
'Brezilya’dan yola çıkan genç bir hücum oyuncusu, Avrupa’da kendine yer arıyordu. Kaká’nın okyanusu aştıktan sonra giydiği ilk kulüp formasını hatırla.',
'Akıcı hücumların arkasında, birbirini tanıyan bir orta saha vardı. Kaká’nın İtalya yıllarında oyunu birlikte kurduğu futbolcuların izini sür.',
'Yeni bir forma, yeni bir takım çevresi demekti. Kaká’nın İspanya’daki yıllarını düşünürken kulübe sonradan gelen isimlere dikkat et.',
'Kariyer çizgisi her zaman dümdüz ilerlemez; dönüşler ve kiralık dönemler de vardır. Kaká’nın sözleşmelerinden çok, sahaya çıktığı formaların sırasını düşün.'],
'benzema': [
'Uzun bir golcülük hikâyesinin başlangıcında, altyapıdan gelen genç bir forvet vardı. Benzema’nın profesyonel sahneye ilk çıktığı kulübü hatırla.',
'Bir hücum hattı yalnızca bitiricilerden oluşmaz; paslar, koşular ve ortak alışkanlıklar da önemlidir. Benzema’nın uzun İspanya dönemindeki takım arkadaşlarını seç.',
'Takımın kadrosu değişirken forvetteki sorumluluklar da değişti. Benzema’nın daha sonraki sezonlarına odaklan ve o yıllarda yanında oynayan ismi hatırla.',
'Yıllarca aynı kulüpte geçen bir dönemin ardından yeni bir sayfa açıldı. Benzema’nın bu ayrılık sonrasındaki ilk transfer adresini bul.'],
'maldini': [
'Tek kulüpte uzayan bir kariyer, birden fazla futbol kuşağını bir araya getirir. Maldini’nin gençlik yıllarındaki takım fotoğrafını zihninde canlandır.',
'Uzun süreli başarıda savunmadaki ortaklıkların da payı vardır. Maldini’nin doksanlı yıllarında yanında bulunan isimleri, sonraki dönemlerden ayır.',
'Yıllar ilerledi, takımın yüzleri değişti; Maldini aynı formanın içindeydi. Bu kez kariyerinin daha ileri dönemindeki soyunma odasına dön.',
'Bir efsanenin vedası ile yeni bir yıldızın gelişi aynı zamana denk gelmeyebilir. Maldini’nin son sezonlarını düşünürken bu zaman farkını gözden kaçırma.'],
'vardy': [
'En üst seviyeye çıkan her yol, büyük bir akademiden başlamaz. Vardy’nin alt liglerdeki yükselişinde son büyük sıçramadan önceki durağı bul.',
'Beklentilerin değiştiği o sezonda başarı, aynı hedefe inanan bir kadroyla geldi. Vardy’nin şampiyonluk yolculuğunu kimlerle paylaştığını hatırla.',
'Unutulmaz bir sezonun ardından kulübün hikâyesi devam etti. Vardy sahadayken kadroya katılan yeni kuşağı, daha önce ayrılan oyunculardan ayır.',
'Alt liglerde biriken deneyim, adım adım daha büyük sahnelere taşındı. Vardy’nin erken kariyerindeki basamakları doğru sırayla yeniden kur.'],
'kante': [
'Sahanın her köşesine yetişen bir orta saha oyuncusunun çıkışı, Fransa’daki yıllarında şekillendi. İngiltere’ye geçişten hemen önceki durağı hatırla.',
'Kanté’nin ilk İngiltere sezonu, takım halinde yazılan sıra dışı bir hikâyenin parçasıydı. O sezonun kadrosunda birlikte oynadığı isimleri bul.',
'Yeni kulübünde de oyunun dengesini sağlayan isimlerden biri oldu. Kanté’nin Londra’daki ilk sezonlarını düşün ve doğru dönemin oyuncusunu seç.',
'Uzun bir İngiltere döneminin ardından yolculuk başka bir lige uzandı. Kanté’nin bu yeni başlangıcının adresi, rotanın son boşluğunda seni bekliyor.'],
'drogba': [
'Drogba’nın yükselişi tek bir transferden ibaret değildi. Fransa’daki ilk basamaklar arasında golcülüğünü geliştirdiği, kolayca atlanan bir dönem var.',
'Büyük bir transferin öncesinde, kendini gösterdiği bir sezon bulunur. Drogba’nın İngiltere’ye taşınmadan hemen önce hangi formayla dikkat çektiğini hatırla.',
'Kritik anların golcüsü, sahada güçlü ortaklıkların da içindeydi. Drogba’nın Londra’daki uzun döneminde aynı kadroyu paylaştığı iki ismi ara.',
'Farklı kıtalara uzanan bu rota, Türkiye’de yeni bir sayfaya bağlandı. Drogba’nın yolculuğunda aradaki kısa durakları da unutmadan sıralamayı kur.'],
'arda_turan': [
'Altyapıda başlayan bağ, yıllar içinde A takımda sorumluluğa dönüştü. Arda’nın genç bir oyuncudan kaptanlığa uzanan ilk büyük kulüp hikâyesini hatırla.',
'İspanya’daki yeni hayat, farklı bir oyun düzenine uyum sağlamayı gerektiriyordu. Arda’nın bu dönemde birlikte mücadele ettiği takım arkadaşlarını seç.',
'Aynı kulübün tarihindeki bütün yıldızlar aynı anda oynamaz. Arda’nın sahaya çıktığı sezonlara odaklanarak doğru kuşağın içinden bir isim bul.',
'Yurt dışına çıkış, yeni formalar ve tanıdık bir yere dönüş… Arda’nın bu kariyer kesitinde kiralık dönemin ve dönüşün yerini dikkatle belirle.'],
'ozil': [
'Oyunu görüşüyle öne çıkan genç bir futbolcu, büyük transferin eşiğindeydi. Özil’in Almanya’dan İspanya’ya geçmeden önceki kulübünü hatırla.',
'Pas yollarını açan oyuncunun çevresinde koşular yapan, mücadele eden bir takım vardı. Özil’in İspanya yıllarında aynı formayı giydiği isimleri seç.',
'İngiltere’de yeni bir takımın oyununa yön verirken çevresindeki isimler de değişti. Özil’in soruda belirtilen sezonlarını dikkatle ayırt et.',
'Farklı ülkelerde açılan kariyer sayfaları sonunda Türkiye’ye uzandı. Özil’in bu ilk Türkiye transferine kadar olan yolunu, başlangıcından itibaren birleştir.'],
'eriksen': [
'Genç bir oyun kurucunun Avrupa’da kendini göstermesi, büyük lig transferinden önce başladı. Eriksen’in Hollanda’daki gelişim döneminin kulübünü hatırla.',
'Orta sahadan kurulan bağlantılar, uzun sezonlar boyunca ortaklıklara dönüştü. Eriksen’in İngiltere’deki bu döneminde beraber oynadığı iki futbolcuyu bul.',
'İtalya’da geçen kariyer sayfası bir şampiyonluk kadrosuna bağlandı. Eriksen’in o tek sezonunu düşünerek farklı dönemlerden gelen adayları ayır.',
'Sahaya dönüşün ardından yeni bir başlangıç daha geldi. Eriksen’in bu kariyer kesitinde, kısa İngiltere döneminden sonraki transfer durağını tamamla.'],
'salah': [
'Mısır’dan Avrupa’ya açılan yol, ilk büyük lig deneyiminden önce başlamıştı. Salah’ın yeni bir futbol ortamıyla tanıştığı ilk Avrupa durağını bul.',
'Kariyerde yükseliş bazen farklı bir ülkede yeniden şekillenir. Salah’ın İngiltere’ye dönüşünden önceki İtalya döneminde eksik kalan kulübü hatırla.',
'Birbirini tamamlayan hücum oyuncuları, takımın hafızasında birlikte yer edinir. Salah’ın bu İngiltere sezonlarında aynı formayı paylaştığı isimleri seç.',
'İlk Avrupa adımı, kiralık dönemler ve yeniden yükseliş… Salah’ın farklı formalar arasında ilerleyen yolculuğunun sırasını, belirtilen zaman aralığında kur.'],
'falcao': [
'Güney Amerika’da gelişen bir golcü, Avrupa’da kendini kanıtlamaya hazırlanıyordu. Falcao’nun kıta değiştirdiğinde katıldığı ilk kulübü hatırla.',
'İspanya yılları, golcünün çevresindeki takım düzeniyle birlikte hatırlanır. Falcao’nun o dönemde birlikte sahaya çıktığı iki ismi seç.',
'Kiralık transferler, kariyer haritalarında kolayca birbirine karışabilir. Falcao’nun İngiltere’deki iki ayrı sezonundan hangisinin önce geldiğini hatırla.',
'Her kariyer özeti bütün durakları içermez. Falcao’nun burada seçilmiş kulüplerini düşün; dönüşleri değil, bu formalara ilk katılma sırasını izle.'],
'ibrahimovic': [
'İsveç’te başlayan yolculuk, genç bir forveti yeni bir futbol okuluna taşıdı. Ibrahimović’in ülkesinden ayrıldıktan sonraki ilk kulübünü hatırla.',
'Büyük kulüpler arasında ilerleyen bu dönemde her forma yeni bir rol getirdi. Ibrahimović’in İtalya ve İspanya arasında uzanan rotasını birleştir.',
'Bir golcünün iz bıraktığı yıllar, çevresindeki takım arkadaşlarıyla da anılır. Ibrahimović’in Fransa dönemini, daha sonraki yıldız kuşağından ayır.',
'Kariyerin ileri yıllarında yeni bir kıta, ardından tanıdık bir lige dönüş vardı. Ibrahimović’in bu iki dönem arasındaki durağını tamamla.'],
'de_bruyne': [
'Büyük bir transfere imza atmak, her zaman hemen kalıcı bir yer bulmak demek değildir. De Bruyne’nin gelişiminde önemli olan kiralık sezonu hatırla.',
'Almanya’da oyuna daha fazla yön verdiği dönemde çevresinde başka yetenekler vardı. De Bruyne’nin sorulan sezonda birlikte oynadığı futbolcuyu seç.',
'İngiltere’de kurulan uzun soluklu ortaklıklar, oyun kurucunun paslarına hareket kattı. De Bruyne’nin bu ilk sezonlarındaki takım arkadaşlarını hatırla.',
'Bir sezona birden çok kupanın sığdığı yolculukta kadronun zamanı önemlidir. De Bruyne’nin o başarı yılına odaklan; eski takım arkadaşlarıyla karıştırma.'],
'lewandowski': [
'Polonya’da gelişen golcülük, yeni bir ligde sınanacaktı. Lewandowski’nin Almanya’ya ilk geldiğinde giydiği formayı, sonraki yıllarından ayır.',
'Gol sayılarının arkasında yıllarca birlikte oynayan bir takım vardı. Lewandowski’nin bu Almanya döneminde aynı kadroyu paylaştığı iki ismi hatırla.',
'Avrupa’nın en büyük kulüp kupasına uzanan yol, belli bir sezonun kadrosuyla yazıldı. Lewandowski’nin o dönemine ait oyuncuyu seç.',
'Bir ülkeden diğerine uzanan golcülük hikâyesini yeniden kur. Lewandowski’nin burada seçilen dört kulübüne ilk katıldığı sırayı takip et.'],
'haaland': [
'Büyük sahnelerdeki gollerden önce, genç bir forvetin adım adım yükselişi vardı. Haaland’ın ilk A takım yıllarındaki duraklarını bir araya getir.',
'Almanya’daki hızlı yükseliş, onu besleyen takım arkadaşlarıyla birlikte gelişti. Haaland’ın o dönemde aynı formayla sahaya çıktığı iki ismi seç.',
'İngiltere’deki ilk sezonu, yeni ortaklıkların da başlangıcıydı. Haaland’ın gelişinden önce ayrılan oyuncularla, onu sahada karşılayan kuşağı ayır.',
'Bir sonraki transfer, genç golcünün önüne başka bir mücadele açtı. Haaland’ın Almanya’dan ayrıldığı yazdaki yeni kulübünü hatırla.'],
'bale': [
'Genç bir sol kanat oyuncusunun gelişimi, yeni bir kulüpte farklı bir role uzanacaktı. Bale’in ilk büyük İngiltere transferinin adresini bul.',
'Bale hücumda daha fazla öne çıkarken çevresinde tanıdık ortaklıklar oluştu. İngiltere’deki bu yıllarda yanında oynayan iki futbolcuyu seç.',
'İspanya’daki yeni sahnede hücum hattının bağlantıları değişti. Bale’in bu dönemini hatırla ve aynı formayı paylaştığı oyuncuyu bul.',
'Kiralık dönüşler, bir rotayı olduğundan uzun gösterebilir. Bale’in burada seçilen kulüplerine ilk gelişlerini düşünerek kariyer haritasını tamamla.'],
'neymar': [
'Brezilya’da genç bir yetenek, altyapıdan A takım sahnesine çıkıyordu. Neymar’ın Avrupa’dan önce başlayan profesyonel hikâyesinin ilk kulübünü hatırla.',
'Avrupa’daki ilk yıllarda hücum oyunu, yeni takım arkadaşlarıyla başka bir boyut kazandı. Neymar’ın bu dönemde birlikte oynadığı isimleri bul.',
'Büyük bir transfer, bir kariyerin yönünü bir anda değiştirebilir. Neymar’ın İspanya’dan ayrıldığı yazda açılan yeni sayfanın adresini tamamla.',
'Farklı futbol ortamları arasında geçen bu kariyer kesitine geri bak. Neymar’ın belirtilen tarihe kadar olan duraklarını, sonraki gelişmelerle karıştırmadan sırala.'],
'neuer': [
'Bir kalecinin büyük kariyeri, genç yaşta emanet edilen ilk A takım kalesiyle başlar. Neuer’in Almanya’daki o başlangıç kulübünü hatırla.',
'Kaleden başlayan oyun, önündeki oyuncularla kurulan güvene dayanır. Neuer’in yeni takımındaki ilk yıllarda birlikte oynadığı iki ismi seç.',
'Savunma ile kaleci arasındaki ortaklık, sezonlar boyunca gelişir. Neuer’in bu dönemde önünde oynayan futbolcuyu, başka kulüplerin isimlerinden ayır.',
'Uzun bir kalecilik kariyerinde aynı forma farklı kuşaklarla paylaşılır. Neuer’in daha yakın dönemine geç; eski kadro anılarını bu sezonlarla karıştırma.'],
'ramos': [
'Genç bir savunmacı, yetiştiği kulüpten ayrılıp daha büyük bir sorumluluğa hazırlanıyordu. Ramos’un ilk büyük transferinin adresini hatırla.',
'Savunmadan başlayıp bütün takıma uzanan bağlar, uzun yıllar içinde kurulur. Ramos’un bu dönemde aynı kadroyu paylaştığı iki futbolcuyu seç.',
'Avrupa’da art arda gelen başarıların arkasında belirli bir oyuncu kuşağı vardı. Ramos’un o yıllarını düşün; saha içindeki isimlerle kulübedekileri ayır.',
'Yıllar süren bir ayrılığın ardından başlangıç noktasına dönmek mümkün. Ramos’un bu kariyer kesitindeki gidiş ve dönüş duraklarını doğru yere yerleştir.'],
'pirlo': [
'Oyunun temposunu belirleyen usta olmadan önce, genç bir futbolcunun ilk lig maçı vardı. Pirlo’nun İtalya’daki o başlangıç formasını hatırla.',
'Orta sahada farklı özellikler birbirini tamamladığında güçlü ortaklıklar doğar. Pirlo’nun uzun kulüp döneminde yanında oynayan iki ismi seç.',
'Bir formayla özdeşleşen oyuncu, başka bir takımda yeniden merkezde olabilir. Pirlo’nun İtalya içinde açtığı bu yeni kariyer sayfasını hatırla.',
'Kiralık dönemleri ve geri dönüşleri olan kariyerler dikkat ister. Pirlo’nun burada verilen kulüplerine ilk katılma sırasını izleyerek kısa rotayı tamamla.'],
'henry': [
'Hızlı bir genç oyuncunun hikâyesi, henüz büyük golcü kimliği oluşmadan başladı. Henry’nin Fransa’da profesyonel sahneye çıktığı kulübü hatırla.',
'İngiltere yıllarındaki hücum oyunu, akılda kalan ortaklıklarla büyüdü. Henry’nin o uzun dönemde aynı formayı paylaştığı iki futbolcuyu seç.',
'Yeni bir ülkeye geçen oyuncu, bu kez farklı bir takımın parçasıydı. Henry’nin İspanya sezonlarında yanında bulunan ismi, sonraki kuşaktan ayır.',
'Fransa’da başlayan rota, farklı liglerin ardından okyanusun ötesine uzandı. Henry’nin bu kesitteki ilk katılma sırasını, sonraki dönüşünü eklemeden kur.'],
'gerrard': [
'Altyapıdan A takıma geçiş, yıllarca sürecek güçlü bir bağın ilk adımıydı. Gerrard’ın gençlikten kaptanlığa uzanan kulüp hikâyesini hatırla.',
'Unutulmaz maçlar yalnızca kaptanlarıyla değil, bütün kadrolarıyla hatırlanır. Gerrard’ın bu Avrupa yolculuğunda aynı formayla yanında olan isimleri ara.',
'Uzun bir kariyerde hücum hattı ve takımın dengeleri değişebilir. Gerrard’ın bu yıllarda birlikte oynadığı futbolcuyu, ondan sonra gelenlerden ayır.',
'Tanıdık bir formayla geçen uzun yıllardan sonra, farklı bir ülkede son bir sayfa açıldı. Gerrard’ın okyanus ötesindeki yeni kulübünü bul.'],
'rooney': [
'Genç yaşta A takıma çıkmak, büyük beklentilerin de başlangıcıdır. Rooney’nin İngiltere’de ilk profesyonel maçına çıktığı kulübü hatırla.',
'Yeni kulübünde deneyimli oyuncularla genç yeteneklerin yolları kesişti. Rooney’nin bu ilk yıllarda birlikte sahaya çıktığı iki ismi seç.',
'Bazı transferler yeni bir yer keşfetmekten çok, eski bir bağı yeniden kurar. Rooney’nin uzun bir dönemin ardından döndüğü kulübü hatırla.',
'İlk forma, uzun bir dönem, geri dönüş ve yeni ülkeler… Rooney’nin oyunculuk yolculuğunu, teknik direktörlük yıllarını eklemeden yeniden sırala.'],
'kroos': [
'Genç bir orta saha oyuncusunun gelişimi için başka bir takımda süre bulması gerekebilir. Kroos’un ana kulübüne dönmeden önceki kiralık durağını bul.',
'Kiralık dönüşünün ardından orta sahadaki rolü büyüdü. Kroos’un Almanya’daki bu sezonlarında aynı kadroyu paylaştığı iki futbolcuyu hatırla.',
'İspanya’da yıllar süren pas ortaklıkları kuruldu. Kroos’un oyunculuk dönemini düşünürken daha eski isimlerle daha sonra gelen futbolcuları ayır.',
'Bir kiralık dönem, aynı kulübü kariyer haritasında iki kez gösterebilir. Kroos’un A takım yolculuğunda dönüşü de doğru yere yerleştir.'],
'hazard': [
'Büyük transferlerden önce, Fransa’da kendini gösteren genç bir hücum oyuncusu vardı. Hazard’ın profesyonel A takım hikâyesinin başladığı kulübü hatırla.',
'İngiltere’de geçen yıllarda takımın kadrosu birkaç kez değişti. Hazard’ın bu geniş dönem içinde aynı formayı paylaştığı iki futbolcuyu seç.',
'Yeni bir kulübe geliş, herkesle aynı dönemi paylaşmak anlamına gelmez. Hazard’ın İspanya’daki sezonlarını doğru zaman aralığıyla hatırla.',
'Kısa bir kulüp listesi, uzun ve farklı dönemler barındırabilir. Hazard’ın profesyonel kariyerindeki ana takım duraklarını ilkinden sonuncusuna bağla.'],
'adriano': [
'Brezilya’dan ayrılan genç bir forvet, gücünü yeni bir kıtada sınayacaktı. Adriano’nun Avrupa’ya ilk adımını attığı kulübü hatırla.',
'Genç bir golcünün gelişimi, başka formalarda bulduğu süreyle hızlanabilir. Adriano’nun ilk İtalya yıllarında, dönüşünden önceki eksik basamağı tamamla.',
'İtalya’daki uzun döneminde golcünün çevresinde farklı özelliklere sahip oyuncular vardı. Adriano’nun bu yıllarda birlikte oynadığı iki ismi seç.',
'Dönüşlerin yer aldığı bu yolculuk, başlangıçtaki ülkeye yeniden uzanır. Adriano’nun seçilmiş duraklarını sıralarken kısa rotanın kapsamını dikkatle izle.'],
'mbappe': [
'Genç bir yeteneğin ilk A takım maçı, büyük bir kariyerin henüz açılmamış ilk sayfasıydı. Mbappé’nin Fransa’daki profesyonel başlangıcını hatırla.',
'Hızlı yükselişin ardından yeni bir takımda uzun bir dönem başladı. Mbappé’nin bu yıllar içinde aynı formayı paylaştığı iki futbolcuyu seç.',
'Aynı takımda yıllarca oynamış isimlerin yolları her sezonda kesişmez. Mbappé’nin soruda verilen iki sezonuna odaklan ve doğru ortaklığı hatırla.',
'Uzun bir dönemin sonunda başka bir ülkede yeni beklentiler başladı. Mbappé’nin bu büyük transferini bul ve dört aşamalı yolculuğunu tamamla.'],
}

def enrich(journeys):
    for journey in journeys:
        texts = NARRATIVES[journey['id']]
        assert len(texts) == len(journey['tasks']) == 4
        for task, text in zip(journey['tasks'], texts):
            task['introNarrative'] = text
