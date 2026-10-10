"""Build answer-redacted mobile catalog from independently written historical facts."""
import copy
import hashlib
import json
from pathlib import Path
import random
ROOT = Path(__file__).resolve().parents[2]
SOURCES = {
'goz': ('Göztepe tarihçesi', 'https://goztepe.org.tr/Kulup/Tarihce'),
'fairs': ('RSSSF Avrupa kupaları 1968–69', 'https://www.rsssf.org/ec/ec196869.html'),
'dfb': ('DFB yarı final kaydı', 'https://datencenter.dfb.de/en/data-center/europa-league/1968-1969/semi-final/ujpest-fc-goztepe-sk-613732'),
'trab': ('Trabzonspor tarihçesi', 'https://www.trabzonspor.org.tr/tr/tarihce'),
'89': ('TFF 1988–89 sezonu', 'https://www.tff.org/Default.aspx?pageId=1213'),
'goals': ('TFF TamSaha 141', 'https://www.tff.org/Resources/Tamsaha/141/files/assets/common/downloads/publication.pdf'),
'bjk92': ('Beşiktaş 1991–92', 'https://bjk.com.tr/tr/haber/66467/1991_92_sezonu_sampiyonlugumuz.html'),
'front': ('Beşiktaş kulüp arşivi', 'https://bjk.com.tr/tr/mobil/haber?news_id=32039'),
'96': ('TFF Trabzonspor–Fenerbahçe tarihçesi', 'https://www.tff.org/Resources/TFF/Documents/02010DK/MacKitaplari/Trabzon-Fenerbahce-Final-2010.pdf'),
'gs00': ('UEFA 1999–2000', 'https://www.uefa.com/uefaeuropaleague/news/016e-0e6a3091ff2c-b6d02ad6a643-1000--1999-2000-galatasaray-the-pride-of-turkey/'),
'super': ('UEFA Süper Kupa 2000', 'https://www.uefa.com/uefasupercup/history/2000/'),
'mansiz': ('FIFA Senegal–Türkiye', 'https://ipt.fifa.com/tournaments/mens/worldcup/2002korea-japan/news/senegal-s-golden-game-2811871'),
'national': ('TFF millî takım arşivi', 'https://www.tff.org/Resources/Tamsaha/Turkiye-Ozbekistan-02-06-2019/14-15/'),
'zico': ('UEFA Zico ve Chelsea maçı', 'https://www.uefa.com/uefachampionsleague/news/01cc-0e6a2085bcb5-fe0fc7cb70a6-1000--zico-delights-in-chelsea-defeat/'),
'sevilla': ('UEFA Sevilla eşleşmesi', 'https://www.uefa.com/uefachampionsleague/news/0254-0d7bc1dafa46-1c521275404a-1000--fenerbahce-win-thriller-at-sevilla/'),
'euro': ('UEFA Türkiye–Çekya', 'https://www.uefa.com/uefaeuro/history/news/025b-0f0b1823034c-c2412c4fb4a6-1000--euro-classics-turkey-3-2-czech-republic/'),
'semih': ('UEFA EURO 2008 teknik raporu', 'https://www.uefa.com/MultimediaFiles/Download/Publications/uefa/UEFAMedia/75/74/69/757469_DOWNLOAD.pdf'),
'bursa': ('TFF 2009–10 şampiyonu', 'https://www.tff.org/default.aspx?ftxtID=9999&pageID=201'),
'saglam': ('Bursaspor şampiyonluk arşivi', 'https://www.bursaspor.org.tr/haber/tertemiz-sampiyon/2773'),
'gs13': ('UEFA Galatasaray 2012–13', 'https://www.uefa.com/uefachampionsleague/news/025a-0ea8e28b0d40-b4dd339b34fa-1000/'),
'sneijder': ('UEFA Sneijder transferi', 'https://www.uefa.com/uefachampionsleague/news/0205-0e82f5488bd6-736eb926ee25-1000--galatasaray-signal-intent-with-sneijder-signing/'),
'fb13': ('UEFA Fenerbahçe yarı finali', 'https://www.uefa.com/uefaeuropaleague/news/025a-0ea90abf4ce7-9518e05947a5-1000--patient-fenerbahce-find-reward-against-benfica/'),
'group': ('UEFA 2017–18 grup özeti', 'https://fr.uefa.com/uefachampionsleague/news/0240-0e981cb1b68f-5789407b528a-1000--video-tous-les-buts-de-la-6e-journee/'),
'cenk': ('Beşiktaş Porto maç merkezi', 'https://bjk.com.tr/en/mac_merkezi/canli/12657')}
CHAPTERS = [
('İzmir’den Avrupa’ya','1960’lar',['Avrupa','Anadolu'],'Körfezden yükselen tezahürat Avrupa tribünlerine taşınıyor. Sarı kırmızılı bir kuşağın izini sür.'),
('Karadeniz’den yükselen ses','1970’ler',['Şampiyonluk','Anadolu'],'Şehrin sokaklarından tribünlere uzanan bir inanç. Lig tarihindeki dengelerin değiştiği döneme dön.'),
('Kadıköy’ün gol hafızası','1988–89',['Şampiyonluk'],'Sarı lacivertli tribünlerde hücum futbolunun konuşulduğu bir sezon. Sayıların ve isimlerin peşine düş.'),
('İnönü’nün hücum hafızası','1991–92',['Şampiyonluk'],'Birbirini tamamlayan roller, yıllarca hatırlanan bir takım. Siyah beyazlı kuşağın hikâyesini aç.'),
('Avni Aker’de bir akşam','1995–96',['Şampiyonluk'],'Takvim mayısı gösteriyor. İki şehrin beklentisi aynı sahada buluşuyor; yarışın dönüm noktasını hatırla.'),
('Avrupa’da çifte iz','2000',['Avrupa'],'İstanbul’dan kıtanın büyük sahnelerine uzanan bir yol. Rakipleri ve dönemin takvimini yeniden birleştir.'),
('Uzak Doğu’da bir nesil','2002',['Millî Takım'],'Sabah saatlerinde ekran başında buluşan bir ülke. Ay yıldızlı kuşağın turnuva hafızasını canlandır.'),
('Kadıköy’den son sekize','2007–08',['Avrupa'],'Avrupa akşamlarında sarı lacivertli tribünler. Kulübün yolculuğunu yöneten ismi ve eleme yolunu hatırla.'),
('Son düdüğe kadar','2008',['Millî Takım'],'Bir yaz, bitmek bilmeyen heyecan ve son ana kadar süren umut. Ay yıldızlıların izlediği yolu keşfet.'),
('Anadolu’dan yeni bir sayfa','2009–10',['Şampiyonluk','Anadolu'],'Son haftaya taşınan bir yarış ve futbol haritasında yeni bir sayfa. Bu hikâyenin kahramanlarını sen bul.'),
('İstanbul’dan Avrupa’ya','2012–13',['Avrupa'],'İstanbul’un iki yakasında Avrupa heyecanı. Bu bölümde bir turun kapısını ve bir orta saha rolünü aç.'),
('Boğaz’dan Avrupa’ya','2017–18',['Avrupa'],'Siyah beyazlı tribünlerden Avrupa deplasmanlarına. Grup yolculuğunun sayıları ve bir forvetin izi seni bekliyor.')]
# type, question, answer labels, choices, basic hint, stronger context, explanation, sources, role/slots
ROWS = [
('season','Göztepe, Fuar Şehirleri Kupası’nda hangi sezonda yarı finale yükseldi?',['1968–69'],['1966–67','1967–68','1968–69','1969–70'],'1960’ların son bölümünü düşün.','Başarı, kulübün ilk Türkiye Kupası zaferiyle aynı sezon geldi.','Göztepe 1968–69 Fuar Şehirleri Kupası’nda yarı finale çıktı. Çeyrek finalde Hamburg çekildi; bu tur sahada kazanılmış bir eşleşme değildir.',['goz','fairs'],''),
('route','Göztepe’nin yarı finalde karşılaştığı Macar kulübünü seç.',['Újpest Dózsa'],['Újpest Dózsa','Ferencváros','Honvéd','MTK Budapest'],'Rakip, Macaristan’ın başkentindendi.','Budapeşte’nin mor beyazlı kulübünü düşün.','Yarı final rakibi Újpest Dózsa idi. Hamburg’un çeyrek finalden çekilmesi ile oynanan yarı final maçları ayrı olaylardır.',['dfb','fairs'],['Yarı final']),
('season','Trabzonspor ilk Türkiye 1. Futbol Ligi şampiyonluğunu hangi sezonda kazandı?',['1975–76'],['1973–74','1974–75','1975–76','1976–77'],'Kulübün üst ligdeki ilk yıllarını düşün.','Şampiyonluk, en üst lige yükseldikten sonraki ikinci sezonda geldi.','Trabzonspor 1975–76 sezonunda ilk lig şampiyonluğunu kazandı; İstanbul dışından şampiyon olan ilk kulüp oldu.',['trab'],''),
('squad','Trabzonspor’un ilk lig şampiyonluğunda takımın teknik direktörü kimdi?',['Ahmet Suat Özyazıcı'],['Ahmet Suat Özyazıcı','Özkan Sümer','Gündüz Kılıç','Turgay Şeren'],'Dönemin yerel futbol kültüründen yetişen bir antrenör.','Trabzonspor’a dört lig şampiyonluğu kazandıran teknik direktörü ara.','1975–76 şampiyonluğunun teknik direktörü Ahmet Suat Özyazıcı idi. Burada maç ilk 11’i değil, sezonun teknik ekibi soruluyor.',['trab'],'Teknik direktör'),
('season','Fenerbahçe’nin 1988–89 ligi resmî puan tablosundaki gol toplamı kaçtır?',['103'],['93','98','103','108'],'Toplam, üç basamaklı bir sayıdır.','Yüzlük eşiğin hemen üstündeki değeri seç.','Resmî sezon tablosunda Fenerbahçe’nin gol toplamı 103’tür. Bu toplam hükmen sonuçların etkisini de içerir; tamamı sahada atılmış goller olarak anlatılmaz.',['89','96'],''),
('legend','1988–89 liginde 29 golle gol kralı olan Fenerbahçeli kimdi?',['Aykut Kocaman'],['Aykut Kocaman','Rıdvan Dilmen','Hasan Vezir','Oğuz Çetin'],'Hücum hattının santrforunu düşün.','Daha sonra aynı kulüpte teknik direktörlük de yaptı.','Aykut Kocaman 29 golle 1988–89 sezonunun gol kralı oldu. Hücumdaki takım arkadaşlarının katkıları bu bireysel unvandan ayrıdır.',['goals'],''),
('squad','Hücum üçlüsündeki eksik rolü tamamla: Metin Tekin, Ali Gültiken ve…',['Feyyaz Uçar'],['Feyyaz Uçar','Mehmet Özdilek','Sergen Yalçın','Zeki Önatlı'],'Siyah beyazlıların dönemin golcüsünü ara.','Lakabı “Kibar” olan santrforu düşün.','Metin Tekin, Ali Gültiken ve Feyyaz Uçar, Beşiktaş’ın hafızalara kazınan hücum üçlüsüdür. Bu panel bir maçın ilk 11’i değildir.',['front'],'Santrfor'),
('season','Beşiktaş 1991–92 lig sezonunu kaç mağlubiyetle bitirdi?',['0'],['0','1','2','3'],'Sezonun en çok hatırlanan yönü istikrarıydı.','O sezonki unvanı, kaybetmeden tamamlanan bir maratonu anlatır.','Beşiktaş 1991–92 ligini 23 galibiyet ve 7 beraberlikle, hiç yenilmeden şampiyon tamamladı.',['bjk92'],''),
('legend','5 Mayıs 1996’da Avni Aker’de 84. dakikadaki Fenerbahçe galibiyet golünü kim attı?',['Aykut Kocaman'],['Aykut Kocaman','Oğuz Çetin','Elvir Bolić','Rıdvan Dilmen'],'Galibiyet golü bir Türk santrfordan geldi.','1988–89 sezonunda da gol krallığı yaşamıştı.','Aykut Kocaman’ın 84. dakikadaki golü Fenerbahçe’yi 2–1 öne geçirdi. Eski içerikteki Avdiç eşleştirmesi doğru değildir.',['96'],''),
('season','1995–96 Türkiye 1. Futbol Ligi şampiyonu hangi kulüp oldu?',['Fenerbahçe'],['Fenerbahçe','Trabzonspor','Beşiktaş','Galatasaray'],'Liderlik yarışı son haftalara kadar sürdü.','Sezonu 84 puanla bitiren İstanbul takımını düşün.','Fenerbahçe 84 puanla şampiyon oldu. Avni Aker’deki sonuç önemliydi; şampiyonluk ise sezonun tamamındaki puanlarla belirlendi.',['96'],''),
('route','Galatasaray’ın 2000 UEFA Kupası yarı final ve final rakiplerini turlara yerleştir.',['Leeds United','Arsenal'],['Leeds United','Arsenal','Borussia Dortmund','Mallorca'],'Son iki turda da İngiliz rakipler vardı.','Önce Yorkshire, ardından Londra merkezli bir kulüp.','Galatasaray yarı finalde Leeds United’ı geçti; 17 Mayıs 2000’de Arsenal’e karşı penaltılarla UEFA Kupası’nı kazandı.',['gs00'],['Yarı final','Final']),
('timeline','Galatasaray’ın 2000 yılındaki iki Avrupa kupasını kazanılma sırasına koy.',['UEFA Kupası','UEFA Süper Kupa'],['UEFA Kupası','UEFA Süper Kupa'],'Bir zafer sonraki kupa maçının kapısını açtı.','Baharın finali, yaz sonunda oynanan tek maçtan önce gelir.','UEFA Kupası 17 Mayıs’ta, UEFA Süper Kupa 25 Ağustos’ta kazanıldı. Süper Kupa’da rakip Real Madrid idi.',['gs00','super'],''),
('legend','2002 Dünya Kupası’nda Senegal karşısındaki altın golü hangi futbolcu attı?',['İlhan Mansız'],['İlhan Mansız','Hakan Şükür','Hasan Şaş','Ümit Davala'],'Oyuna sonradan giren bir forvet fark yarattı.','Kulüp kariyerinde Beşiktaş formasıyla da hatırlanır.','İlhan Mansız’ın altın golü Türkiye’yi yarı finale taşıdı. Altın gol kuralında uzatmada atılan gol maçı bitiriyordu.',['mansiz'],''),
('timeline','Türkiye’nin 2002 Dünya Kupası’ndaki çeyrek final, yarı final ve üçüncülük rakiplerini sırala.',['Senegal','Brezilya','Güney Kore'],['Senegal','Brezilya','Güney Kore'],'Üç kıtadan üç farklı rakip.','Afrika ekibini Güney Amerika temsilcisi, onu ev sahiplerinden biri izler.','Türkiye çeyrek finalde Senegal’i, yarı finalde Brezilya’yı, üçüncülük maçında Güney Kore’yi karşısında buldu ve turnuvayı üçüncü bitirdi.',['national','mansiz'],''),
('squad','Fenerbahçe’yi 2007–08 Şampiyonlar Ligi çeyrek finaline taşıyan teknik direktör kimdi?',['Zico'],['Zico','Christoph Daum','Luis Aragonés','Aykut Kocaman'],'Brezilya futbolunun önemli bir ismiydi.','Futbolculuğunda Flamengo ve Brezilya millî takımının oyun kurucusuydu.','Fenerbahçe, Brezilyalı teknik direktör Zico yönetiminde 2007–08 sezonunda Şampiyonlar Ligi çeyrek finaline yükseldi.',['zico'],'Teknik direktör'),
('route','Fenerbahçe’nin 2008 Şampiyonlar Ligi eleme rakiplerini turlara yerleştir.',['Sevilla','Chelsea'],['Sevilla','Chelsea','Inter','PSV'],'Bir İspanyol kulübünü bir İngiliz kulübü izler.','İlk tur penaltılara uzandı; sonraki rakip Londra’dan geldi.','Son 16’da Sevilla penaltılarla geçildi. Çeyrek finalde Chelsea ile karşılaşıldı. Grup rakipleri bu eleme sırasına dahil değildir.',['sevilla','zico'],['Son 16','Çeyrek final']),
('timeline','Türkiye’nin EURO 2008’de oynadığı son üç maçın rakiplerini sırala.',['Çekya','Hırvatistan','Almanya'],['Çekya','Hırvatistan','Almanya'],'Grup son maçı, çeyrek final ve yarı final sırasını düşün.','İlkinde geri dönüş, ikincisinde penaltılar, sonuncusunda finale bir adım vardı.','Sıra Çekya, Hırvatistan, Almanya’dır. Dönemin Çek Cumhuriyeti adı katalogda güncel Türkçe adı Çekya ile gösterilir.',['euro','semih'],''),
('legend','EURO 2008’de Hırvatistan karşısında uzatmanın son anlarında beraberliği kim getirdi?',['Semih Şentürk'],['Semih Şentürk','Nihat Kahveci','Arda Turan','Tuncay Şanlı'],'Yedekten gelip skor üreten bir santrfor.','“Nöbetçi golcü” lakabıyla hatırlanır.','Semih Şentürk eşitliği sağladı; Türkiye ardından penaltılarla turu geçti. UEFA teknik raporu golü 122. dakika olarak kaydeder.',['semih'],''),
('season','2009–10 sezonunda lig şampiyonluğunu kazanan Anadolu takımı hangisiydi?',['Bursaspor'],['Bursaspor','Sivasspor','Eskişehirspor','Kayserispor'],'Kulüp ilk lig şampiyonluğunu yaşadı.','Sezonu 75 puanla bitirerek şampiyonlar listesine yeni bir ad ekledi.','Bursaspor 2009–10 sezonunda ilk lig şampiyonluğunu kazandı. Son haftada Beşiktaş’ı yenerek sezonu zirvede tamamladı.',['bursa'],''),
('squad','2009–10 sezonunun şampiyon Anadolu takımını hangi teknik direktör çalıştırdı?',['Ertuğrul Sağlam'],['Ertuğrul Sağlam','Bülent Uygun','Hikmet Karaman','Tolunay Kafkas'],'Futbolculuk geçmişinde Beşiktaş da vardı.','Teknik direktörlük kariyerinde Kayserispor’dan sonra Beşiktaş’ta da görev aldı.','Bursaspor’un şampiyonluk sezonundaki teknik direktörü Ertuğrul Sağlam’dı. Sezonun teknik ekibi ile tek maçın kadrosu farklı veri türleridir.',['saglam'],'Teknik direktör'),
('route','Galatasaray’ın 2012–13 Şampiyonlar Ligi eleme rakiplerini turlara yerleştir.',['Schalke 04','Real Madrid'],['Schalke 04','Real Madrid','Manchester United','Cluj'],'Almanya’dan bir rakibi İspanya’dan bir rakip izler.','Önce Gelsenkirchen, ardından İspanya başkenti.','Galatasaray son 16’da Schalke 04’ü geçti; çeyrek finalde Real Madrid ile karşılaştı. Aynı sezon Fenerbahçe de UEFA Avrupa Ligi yarı finaline ulaştı.',['gs13','fb13'],['Son 16','Çeyrek final']),
('squad','2013’te Drogba ile aynı sezon Galatasaray’a katılan Hollandalı orta saha kimdi?',['Wesley Sneijder'],['Wesley Sneijder','Rafael van der Vaart','Ibrahim Afellay','Clarence Seedorf'],'Hücum organizasyonunda oyun kurucu rolündeydi.','Galatasaray’a Inter’den geldi; 2010’da Şampiyonlar Ligi’ni kazanmıştı.','Wesley Sneijder Ocak 2013’te Galatasaray’a katıldı. Soru transfer ve sezon rolünü konu alır; belirli bir maçın ilk 11’ini değil.',['sneijder'],'Orta saha'),
('season','Beşiktaş 2017–18 Şampiyonlar Ligi grubunu kaç puanla lider bitirdi?',['14'],['10','12','14','16'],'Altı maçta yenilgi yaşamadı.','Dört galibiyet ve iki beraberliğin puanlarını topla.','Beşiktaş dört galibiyet, iki beraberlikle 14 puan topladı ve grubunu lider tamamladı.',['group'],''),
('legend','2017 Porto deplasmanında Beşiktaş adına uzak mesafeden gol atan Türk forvet kimdi?',['Cenk Tosun'],['Cenk Tosun','Mustafa Pektemek','Burak Yılmaz','Umut Bulut'],'Dönemin siyah beyazlı santrforunu düşün.','Bu sezonun devre arasında Everton’a transfer oldu.','Porto deplasmanındaki uzak mesafeli golün sahibi Cenk Tosun’du. Beşiktaş karşılaşmayı 3–1 kazandı.',['cenk'],'')]
def build():
    chapters, tasks = [], []
    for i,(title,era,categories,intro) in enumerate(CHAPTERS,1):
        cid=f'nostalgia_{i:02d}'
        chapters.append(dict(id=cid,number=i,title=title,era=era,categories=categories,intro=intro,taskIds=[f'{cid}_1',f'{cid}_2'],album=dict(title=title,story=' '.join(ROWS[(i-1)*2+j][6] for j in range(2)))))
    for n,(kind,question,answers,choices,hint,strong,explanation,sources,role) in enumerate(ROWS):
        cid=f'nostalgia_{n//2+1:02d}'; tid=f'{cid}_{n%2+1}'
        key=lambda label: hashlib.sha256((tid+'|'+label).encode()).hexdigest()[:12]
        options=[dict(id=key(label),label=label) for label in choices]
        random.Random(tid).shuffle(options)
        if kind=='timeline' and [o['id'] for o in options]==list(map(key,answers)): options.reverse()
        tasks.append(dict(id=tid,chapterId=cid,type=kind,question=question,options=options,answerKeys=list(map(key,answers)),required=len(answers),hint=hint,strongHint=strong,role=role if isinstance(role,str) else '',slots=role if isinstance(role,list) else [],result=dict(answer=' → '.join(answers),explanation=explanation,sources=[dict(name=SOURCES[s][0],url=SOURCES[s][1],accessedAt='2026-10-10') for s in sources]),verification=dict(status='A',reviewedAt='2026-10-10',spoilerReviewed=True)))
    private=dict(version=1,contentRevision='2026-10-10',economy=dict(task=dict(coins=6,xp=15),chapter=dict(coins=15,xp=30),album=dict(coins=60,xp=120),hintCoins=6),chapters=chapters,tasks=tasks)
    public=copy.deepcopy(private)
    for c in public['chapters']: del c['album']
    for t in public['tasks']:
        for field in ['answerKeys','result','verification','strongHint']: del t[field]
    return private,public
if __name__=='__main__':
    for path,content in zip(['functions/config/nostalgia_catalog.json','assets/data/nostalgia_v2.json'],build()):
        (ROOT/path).write_text(json.dumps(content,ensure_ascii=False,indent=2)+'\n')
