"""Editorial catalog: regenerate both runtimes from reviewed task definitions."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
S={
'goz':('Göztepe tarihçe','https://goztepe.org.tr/Kulup/Tarihce'),
'fairs':('RSSSF 1968–69','https://www.rsssf.org/ec/ec196869det.html'),
'dfb':('DFB Fuar Kupası yarı finali','https://datencenter.dfb.de/en/data-center/europa-league/1968-1969/semi-final/ujpest-fc-goztepe-sk-613732'),
'lig':('TFF lig tarihi','https://www.tff.org/Default.aspx?pageId=545'),
'trab':('Trabzonspor tarihçe','https://www.trabzonspor.org.tr/tr/kulup/history'),
'coach':('Anadolu Ajansı / Özyazıcı','https://www.aa.com.tr/tr/futbol/trabzonsporun-efsanevi-teknik-direktoru-ahmet-suat-ozyazici/3140878'),
'103':('UEFA / 1988–89 sezonu','https://www.uefa.com/womensunder19/news/01fc-0e13851e6809-1395764f13b4-1000--turkey-team-guide/'),
'king':('TFF gol krallığı','https://www.tff.org/Resources/Tamsaha/141/files/assets/basic-html/page5.html'),
'bes':('Beşiktaş tarihçe','https://www.bjk.com.tr/tr/cms/tarihce/2/82/'),
'maf':('Beşiktaş / Metin Tekin','https://bjk.com.tr/tr/oyuncu/366/item?fromMobile=true'),
'1996':('Habertürk maç kaydı','https://www.haberturk.com/spor/futbol/haber/584097-ilk-gol-1996da-atilmisti'),
'1996b':('Fenerbahçe sezon arşivi','https://fenerbahcestats.blogspot.com/2013/03/1995-96da-lig.html'),
'leeds':('UEFA yarı final','https://www.uefa.com/uefaeuropaleague/match/63644--leeds-vs-galatasaray/'),
'arsenal':('UEFA final','https://www.uefa.com/uefaeuropaleague/match/64414--galatasaray-vs-arsenal/'),
'super':('UEFA Süper Kupa 2000','https://www.uefa.com/uefasupercup/history/2000/'),
'2002':('FIFA / 2002 Türkiye','https://www.plus.fifa.com/en/showcase/turkey-at-the-2002-fifa-world-cup/3a2b3c0a-51ee-49d4-9280-68be0126edba'),
'ilhan':('FIFA / İlhan Mansız golü','https://www.fifa.com/en/tournaments/mens/worldcup/canadamexicousa2026/teams/turkiye'),
'zico':('UEFA / Zico ve Chelsea','https://www.uefa.com/uefachampionsleague/news/01cc-0e6a2085bcb5-fe0fc7cb70a6-1000--zico-delights-in-chelsea-defeat/'),
'sevilla':('UEFA son 16 raporu','https://www.uefa.com/newsfiles/UCL/2008/301894_FR.pdf'),
'euro':('UEFA / EURO 2008 Türkiye','https://www.uefa.com/uefaeuro/history/news/025b-0f0b1823034c-c2412c4fb4a6-1000--euro-classics-turkey-3-2-czech-republic/'),
'bursa':('TFF şampiyonluk kaydı','https://www.tff.org/default.aspx?ftxtID=9999&pageID=201'),
'saglam':('TFF lig tarihi / Ertuğrul Sağlam','https://www.tff.org/default.aspx?ftxtID=20962&pageID=201'),
'schalke':('UEFA / Schalke–Galatasaray','https://www.uefa.com/uefachampionsleague/match/2009594--schalke-vs-galatasaray/'),
'fb13':('UEFA / Fenerbahçe yarı finali','https://www.uefa.com/uefaeuropaleague/match/2010093/'),
'real':('UEFA çeyrek final raporu','https://www.uefa.com/newsfiles/UCL/2013/2009607_FR.pdf'),
'sneijder':('Galatasaray transfer duyurusu','https://www.galatasaray.org/haber/galatasaray-haberleri/wesley-sneijder-hakkinda-aciklama/2706'),
'14':('UEFA grup sonu raporu','https://fr.uefa.com/uefachampionsleague/news/0240-0e981cb1b68f-5789407b528a-1000--video-tous-les-buts-de-la-6e-journee/'),
'cenk':('Beşiktaş / Porto maç merkezi','https://bjk.com.tr/en/mac_merkezi/canli/12657'),
}
chapters=[]
def chapter(title,era,card,categories,intro):
    c=dict(id=f'tn2_c{len(chapters)+1:02}',title=title,era=era,card=card,categories=categories.split('|'),intro=intro,tasks=[])
    chapters.append(c)
def task(kind,q,options,answers,hint,strong,explanation,sources,role='',slots=None):
    c=chapters[-1]; labels=options.split('|'); keys=[f'o{i+1}' for i in range(len(labels))]
    t=dict(id=f"{c['id']}_t{len(c['tasks'])+1}",chapterId=c['id'],mechanic=kind,question=q,
        options=[dict(id=k,label=v) for k,v in zip(keys,labels)],answerKeys=[keys[labels.index(a)] for a in answers.split('|')],
        hint=hint,strongHint=strong,explanation=explanation,role=role,slots=slots or [],contentVersion=2,
        verification='A',spoilerReviewed=True,sources=[dict(label=S[s][0],url=S[s][1],accessed='2026-10-10') for s in sources.split('|')])
    c['tasks'].append(t)
chapter('İzmir’den Avrupa’ya','1960’lar','1968–69 · Göztepe','Avrupa|Anadolu','İzmir’in sarı-kırmızılı ekibi Avrupa sahnesinde iz bırakıyor. Bir sezonun takvimini ve karşılaşmalarını hatırla.')
task('season','Göztepe, Fuar Şehirleri Kupası’nda hangi sezonda yarı finale yükseldi?','1966–67|1967–68|1968–69|1969–70','1968–69','Altmışlı yılların sonundaki yolculuğu düşün.','On yıl değişmeden önce tamamlanan son sezonu ara.','Göztepe 1968–69 Fuar Şehirleri Kupası’nda yarı finale ulaştı.','goz|fairs')
task('route','Yarı finaldeki Macar rakibini doğru tura yerleştir.','Ferencváros|Újpest Dózsa|Vasas|MTK Budapest','Újpest Dózsa','Aranan takım Budapeşte’den.','Kulübün dönem adında Dózsa bulunur.','Yarı final rakibi Újpest Dózsa idi. Çeyrek finalde Hamburg çekildi; bu tur sahada kazanılan maçlar olarak sayılmaz.','fairs|dfb',slots=['Yarı final'])
chapter('Karadeniz’den Gelen Ses','1970’ler','1975–76 · Trabzonspor','Şampiyonluk|Anadolu','Bir şehrin takımı ligdeki güç dengesini değiştiriyor. Bu dönüşümün sezonunu ve kulübedeki ismini bul.')
task('season','Trabzonspor’un ilk Türkiye 1. Futbol Ligi şampiyonluğu hangi sezonda geldi?','1973–74|1974–75|1975–76|1976–77','1975–76','İlk kupayı, onu izleyen şampiyonluklardan ayır.','Yetmişli yılların ortasında başlayan sezon.','Trabzonspor ilk lig şampiyonluğunu 1975–76 sezonunda kazandı.','lig|trab')
task('squad','İlk şampiyonlukta takımı yöneten teknik direktörü seç.','Özkan Sümer|Gündüz Kılıç|Ahmet Suat Özyazıcı|Şenol Güneş','Ahmet Suat Özyazıcı','Aranan isim sahadaki oyuncu değil, takımın teknik sorumlusu.','Kulübe dört birinci lig şampiyonluğu kazandıran teknik adam.','Şampiyonluğu getiren teknik direktör Ahmet Suat Özyazıcı idi. Bu rol, maç ilk 11’inden ayrıdır.','coach|trab',role='Teknik direktör')
chapter('Sarı Lacivert Bir Sezon','1988–89','1988–89 · Fenerbahçe','Şampiyonluk','Hücum gücüyle hafızalara kazınan bir lig sezonu. Takımın toplamını ve gol yarışındaki ismini keşfet.')
task('season','Fenerbahçe 1988–89 lig sezonunda toplam kaç gol attı?','93|100|103|110','103','Lig toplamını, tüm kupalardaki toplamdan ayır.','Toplam, yüzün biraz üzerinde.','Fenerbahçe ligde 103 gol attı; bu sayı yalnızca lig maçlarını kapsar.','103')
task('legend','Bu sezon 29 golle ligin gol kralı olan Fenerbahçeli kimdi?','Rıdvan Dilmen|Hasan Vezir|Aykut Kocaman|Oğuz Çetin','Aykut Kocaman','İleri uçtaki bitirici ismi düşün.','Sakaryaspor’dan gelen ve ileride teknik direktörlük de yapan isim.','1988–89 gol kralı 29 gol atan Aykut Kocaman’dı.','king')
chapter('İnönü’nün Sesi','1991–92','1991–92 · Beşiktaş','Şampiyonluk','Tribünlerin hafızasında yaşayan bir hücum hattı ve sezon boyunca süren mücadele. İsimleri ve puan tablosunu hatırla.')
task('squad','Metin Tekin ve Ali Gültiken’le anılan hücum üçlüsünün üçüncü ismini seç.','Feyyaz Uçar|Mehmet Özdilek|Sergen Yalçın|Rıza Çalımbay','Feyyaz Uçar','Üçlünün adını tribünlerden hatırla.','Soyadı bir hareket fiilini çağrıştırır.','Üçlü, Metin Tekin, Ali Gültiken ve Feyyaz Uçar’dan oluşur. Bir dönem birlikteliğidir; belirli bir maçın ilk 11’i değildir.','maf|bes',role='Hücum üçlüsü')
task('season','Beşiktaş 1991–92 lig sezonunu kaç mağlubiyetle bitirdi?','0|1|2|3','0','Puan tablosunun mağlubiyet sütununu düşün.','Bu sütunda herhangi bir yenilgi kaydı oluşmadı.','Beşiktaş 1991–92 sezonunu yenilgisiz tamamladı.','bes')
chapter('Yarışın Kırılma Anı','1995–96','1995–96 · Şampiyonluk yarışı','Şampiyonluk','Ligin son haftalarına yaklaşırken Trabzon’da bir karşılaşma yarışın yönünü etkiliyor. Golü ve sezonun sonunu hatırla.')
task('legend','5 Mayıs 1996’da Avni Aker’de Fenerbahçe’nin galibiyet golünü atan kimdi?','Oğuz Çetin|Elvir Bolić|Aykut Kocaman|Tayfun Korkut','Aykut Kocaman','Eşitlik golüyle galibiyet golünü birbirinden ayır.','Seksenli yılların sonunda sarı-lacivertli formayı giymeye başlayan forvet.','Aykut Kocaman’ın son bölümdeki golü skoru 2–1 yaptı. Oğuz Çetin eşitlik golünü atmıştı.','1996|1996b')
task('season','1995–96 Türkiye 1. Futbol Ligi şampiyonu hangi takımdı?','Trabzonspor|Galatasaray|Beşiktaş|Fenerbahçe','Fenerbahçe','Tek bir maçın liderini değil, sezon sonunu düşün.','Şampiyon İstanbul’dan çıktı; bordo-mavili ekip ikinci kaldı.','Sezonu Fenerbahçe şampiyon tamamladı.','lig')
chapter('Avrupa’da Bir Yaz','2000','2000 · Galatasaray’ın iki kupası','Avrupa','Avrupa yolculuğu bir yaz boyunca yeni sayfalar açıyor. Son turları ve iki organizasyonun sırasını tamamla.')
task('route','UEFA Kupası yarı final ve final rakiplerini turlara yerleştir.','Arsenal|Leeds United|Real Madrid|Mallorca','Leeds United|Arsenal','İki rakip de İngiltere’den.','Yorkshire ekibi, Londra ekibinden önce gelir.','Galatasaray yarı finalde Leeds United’ı geçti; finalde Arsenal karşısında kupayı aldı.','leeds|arsenal',slots=['Yarı final','Final'])
task('timeline','Galatasaray’ın aynı yıl kazandığı iki Avrupa kupasını tarihe göre sırala.','UEFA Süper Kupa|UEFA Kupası','UEFA Kupası|UEFA Süper Kupa','İlk başarı sonraki karşılaşmaya katılma hakkı verdi.','Avrupa kupalarının kazananlarını buluşturan organizasyon daha sonra oynandı.','Önce UEFA Kupası, ardından UEFA Süper Kupa kazanıldı.','arsenal|super')
chapter('Bir Neslin Uzak Yolculuğu','2002','2002 · Dünya üçüncülüğü','Millî Takım','Uzak Doğu’da birlikte izlenen maçlar, bir neslin ortak anısına dönüşüyor. Turnuva yolunu iki görevle yeniden kur.')
task('legend','Türkiye’yi Senegal karşısında altın golle yarı finale taşıyan kimdi?','Hasan Şaş|İlhan Mansız|Hakan Şükür|Ümit Davala','İlhan Mansız','Sonradan oyuna giren forveti hatırla.','Beşiktaş forması giyen hücum oyuncusu.','Senegal karşısındaki altın gol İlhan Mansız’dan geldi.','ilhan')
task('timeline','Çeyrek final, yarı final ve üçüncülük maçındaki rakipleri sırala.','Güney Kore|Senegal|Brezilya','Senegal|Brezilya|Güney Kore','Grup maçlarını bu sıralamaya katma.','Afrika temsilcisinden sonra Güney Amerika temsilcisi; en sonda ev sahiplerinden biri.','Sıra Senegal, Brezilya ve Güney Kore idi. Son maç final değil, üçüncülük karşılaşmasıydı.','2002')
chapter('Kadıköy’den Avrupa’ya','2007–08','2007–08 · Fenerbahçe son sekizde','Avrupa','Bir teknik adam ve takımı eleme turlarında yeni bir sayfa açıyor. Kulübedeki ismi ve rakiplerin sırasını bul.')
task('squad','Fenerbahçe’yi bu sezon Şampiyonlar Ligi çeyrek finaline taşıyan teknik direktör kimdi?','Christoph Daum|Zico|Luis Aragonés|Aykut Kocaman','Zico','Futbolculuk kariyeriyle de tanınan bir teknik adam.','Brezilyalı bir futbol efsanesi.','Takımın teknik direktörü Zico idi.','zico|sevilla',role='Teknik direktör')
task('route','2008 eleme turu rakiplerini eşleştir.','Chelsea|Sevilla|Inter|PSV','Sevilla|Chelsea','Grup aşaması rakiplerini eleme turlarından ayır.','Önce İspanya, ardından İngiltere temsilcisi.','Son 16’da Sevilla, çeyrek finalde Chelsea ile karşılaşıldı.','sevilla|zico',slots=['Son 16','Çeyrek final'])
chapter('Son Düdüğe Kadar','2008','EURO 2008 · Türkiye','Millî Takım','Son anlara kadar süren mücadeleler turnuvanın hafızasında yer ediyor. Takvimi ve bir geri dönüşün ismini hatırla.')
task('timeline','Türkiye’nin EURO 2008’deki son üç maçının rakiplerini sırala.','Almanya|Çekya|Hırvatistan','Çekya|Hırvatistan|Almanya','Son grup maçı, çeyrek final ve yarı final sırasını izle.','Orta Avrupa temsilcisiyle başlayan yol Balkanlar üzerinden yarı finale gider.','Son grup maçında Çekya, çeyrek finalde Hırvatistan, yarı finalde Almanya ile oynandı.','euro')
task('legend','Hırvatistan’a karşı uzatmanın son anlarında beraberliği sağlayan kimdi?','Nihat Kahveci|Arda Turan|Semih Şentürk|Tuncay Şanlı','Semih Şentürk','Oyuna sonradan giren hücum oyuncusunu düşün.','O sezon ligde gol krallığı yaşayan sarı-lacivertli forvet.','Beraberlik golünü Semih Şentürk attı; Türkiye penaltı serisinde turu geçti.','euro')
chapter('Anadolu’da Yeni Bir Sayfa','2009–10','2009–10 · Bursaspor','Şampiyonluk|Anadolu','Alışılmış yarışa başka bir şehir katılıyor. Sezonun şampiyonunu ve bu başarıdaki teknik adamı bul.')
task('season','2009–10 sezonunda ilk lig şampiyonluğunu kazanan Anadolu takımı hangisiydi?','Sivasspor|Bursaspor|Eskişehirspor|Kayserispor','Bursaspor','Şampiyonluk tarihinde yeni bir kulüp adı belirdi.','Marmara Bölgesi’nden bir ekip.','Bursaspor 2009–10 sezonunda ilk lig şampiyonluğuna ulaştı.','bursa')
task('squad','Bu şampiyonluğu kazanan takımın teknik direktörü kimdi?','Ertuğrul Sağlam|Bülent Uygun|Aykut Kocaman|Şenol Güneş','Ertuğrul Sağlam','Bu görevde sahadaki kaptanı değil kulübedeki sorumluyu seç.','Futbolculuk döneminde Samsunspor ve Beşiktaş formalarını giydi.','Bursaspor şampiyonluğu Ertuğrul Sağlam yönetiminde kazandı.','saglam',role='Teknik direktör')
chapter('İki Renk, Avrupa Takvimi','2012–13','2012–13 · Avrupa yolculukları','Avrupa','İstanbul’un iki yakası Avrupa takviminde ilerliyor. Sarı-kırmızılı ekibin rakiplerini ve ara transferdeki ismini hatırla.')
task('route','Galatasaray’ın son 16 ve çeyrek final rakiplerini eşleştir.','Real Madrid|Juventus|Schalke 04|Manchester United','Schalke 04|Real Madrid','Almanya ve İspanya temsilcilerini düşün.','Gelsenkirchen’den sonra Madrid durağı gelir.','Son 16’da Schalke 04, çeyrek finalde Real Madrid ile oynandı. Aynı sezon Fenerbahçe Avrupa Ligi’nde yarı finale ulaştı.','schalke|real|fb13',slots=['Son 16','Çeyrek final'])
task('squad','2013’te Drogba ile aynı sezon Galatasaray’a gelen Hollandalı yıldızı seç.','Dirk Kuyt|Wesley Sneijder|Rafael van der Vaart|Robin van Persie','Wesley Sneijder','Orta sahadaki oyun kurucuyu düşün.','İtalya’dan transfer edilen Hollandalı.','Wesley Sneijder transferi Ocak 2013’te duyuruldu. Bu bir sezon kadrosu bilgisidir.','sneijder',role='Oyun kurucu')
chapter('Boğaz’dan Avrupa’ya','2017–18','2017–18 · Beşiktaş grup liderliği','Avrupa','Grup aşamasında farklı şehirler, farklı sınavlar. Toplanan puanı ve Porto’daki uzak şutu hatırla.')
task('season','Beşiktaş, Şampiyonlar Ligi grubunu kaç puanla lider bitirdi?','12|13|14|16','14','Altı grup maçının puan toplamını düşün.','Dört galibiyet ve iki beraberliğin toplamını hesapla.','Beşiktaş dört galibiyet ve iki beraberlikle 14 puan topladı.','14')
task('legend','2017 Porto deplasmanında uzak mesafeden gol atan Türk forvet kimdi?','Cenk Tosun|Burak Yılmaz|Mustafa Pektemek|Ömer Şişmanoğlu','Cenk Tosun','Takımın o dönemdeki santrforunu düşün.','Daha sonra Everton’a transfer olan forvet.','Cenk Tosun, Porto deplasmanında ceza alanı dışından gol attı.','cenk')
catalog=dict(version=2,chapters=chapters,economy=dict(task=dict(coins=6,xp=15),chapter=dict(coins=15,xp=30),final=dict(coins=60,xp=120),hintPrice=6))
def main():
    data=json.dumps(catalog,ensure_ascii=False,indent=2)+'\n'
    for file in ['assets/data/turkish_nostalgia_v2.json','functions/config/nostalgia_catalog.json']:
        (ROOT/file).write_text(data)
if __name__=='__main__':main()
