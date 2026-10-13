"""Editorial Dynasties V2 catalog. Private evidence/answers never enter app assets."""
import copy, hashlib, json, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
U='https://www.uefa.com/uefachampionsleague/'
S={
'barca':U+'match/302813/',
'six':'https://www.fcbarcelona.com/en/football/first-team/noticies/1650113/todays-special-2009-the-year-of-six-trophies',
'finals':'https://editorial.uefa.com/resources/0282-18407a7a3056-fed61d05639b-1000/ucl_202223_finals_md13.pdf',
'isco':U+'match/2019641/',
'arsenal':'https://www.premierleague.com/en/tables/premier-league/2003-04/all-matchweeks',
'lehmann':'https://www.arsenal.com/men/jens-lehmann-aiWrt9g2Yxah',
'sacchi':'https://www.uefa.com/news/0253-0d81cb410c87-4115a0f26160-1000--arrigo-sacchi-s-case-for-greatness/',
'milan':'https://it.uefa.com/uefachampionsleague/news/023a-0e973c61b04c-9fdf234c6fd0-1000--madrid-1957-cardiff-2017-60-anni-di-finali-italiane/',
'ajax':U+'news/0253-0d7ff54908f6-5927d0a16600-1000--the-greatest-teams-of-all-time-ajax-1971-73/',
'ajax_tactics':'https://www.uefa.com/news-media/news/0218-0e9b869a861e-556622f75175-1000--european-football-in-the-1970s/',
'madrid':U+'news/0253-0d7ff5480c22-d63d36f4632d-1000--the-greatest-teams-of-all-time-real-madrid-1956-60/',
'bbc':'https://www.uefa.com/uefaeuro/history/news/0253-0d8162a5d698-6892fce36d5b-1000--italy-s-bbc-spell-out-programme-for-solidity/',
'bayern11':'https://www.bundesliga.com/en/bundesliga/news/story-of-bayern-munich-record-breaking-11-year-reign-as-bundesliga-champions-27081',
'united':'https://www.manutd.com/en/club/history/history-by-decade/1990-1999',
'class92':'https://www.manutd.com/en/academy/academy-history',
'tff':'https://www.tff.org/Default.aspx?pageID=545',
'benfica':U+'news/0219-0e8c04f35082-a8df3b001065-1000--eusebio-stars-in-benfica-s-second-triumph/',
'coluna':U+'news/0258-0e6a045944ea-75ee25be6a88-1000--1961-62-eusebio-strikes-gold-for-benfica/',
'lyon':'https://www.uefa.com/news-media/news/01cd-0f84dbf85eeb-49ca26254d04-1000--game-sept-and-match-to-lyon/',
'stones':U+'news/0282-183fa8a707c0-4056c043e3d1-1000--in-the-zone-city-s-win-analysed/',
'city':'https://www.mancity.com/news/mens/man-city-champions-league-winners-treble-premier-league-fa-cup-63822026',
'hungary':'https://www.uefa.com/uefaeuro/history/news/0253-0d8026b8531a-6be6e23436d1-1000--the-greatest-teams-of-all-time-hungary-1950-56/',
'wc54':'https://inside.fifa.com/en/tournaments/mens/worldcup/qatar2022/news/the-finals-that-made-history',
'bayernroles':'https://fcbayern.com/de/club/historie/meilensteine-seit-1900/1966-bis-1979-goldene-jahre',
'bayernfinals':U+'news/0253-0d7ff546eab3-5cb419e6b81a-1000--the-greatest-teams-of-all-time-bayern-1973-76/',
'liverpool':'https://www.uefa.com/news/0275-15201acb75e7-c57250f46a12-1000--liverpool-and-real-madrid-s-finals/',
'grobbelaar':U+'news/0244-0e98ae2983be-b3a08537e2b8-1000--liverpool-and-roma-relish-semi-final-opportunity/',
}
# No answer-bearing record counts in pre-completion dynasty titles.
D=[
('Barcelona','2008–2012','Pasın mimarisi','Sahadaki rollerden kupa yarışına uzanan bir oyun fikrinin izini sür.','2009 başarısı altı kupanın kazanıldığı takvim yılına aittir; tek sezona değil.'),
('Real Madrid','2016–2018','Avrupa geceleri','Final yolculuklarını ve dönemin hücum düzenini keşfet.','2016, 2017 ve 2018 finalleri kazanıldı. 2018 finalindeki röveşata Gareth Bale’e aittir.'),
('Arsenal','2003–2004','Altın sezon','Bir lig sezonunun dayanıklılığını sayılar ve kadro üzerinden incele.','38 maçlık lig sezonu 26 galibiyet ve 12 beraberlikle yenilgisiz tamamlandı.'),
('AC Milan','1988–1994','Birlikte savunmak','Bir savunma fikrinin Avrupa başarılarına dönüşmesini keşfet.','Sacchi’nin alan savunmasını Capello dönemi izledi. Maldini’nin kulüpteki oyunculuk süresi kaptanlık süresiyle aynı değildir.'),
('Ajax','1971–1973','Hareketin düzeni','Oyuncuların rollerini ve Avrupa yolculuğunun rakiplerini keşfet.','Kolektif pozisyon değişimi düzeni koruma sorumluluğuyla birleşti. 1971–1973 Avrupa finalleri kazanıldı.'),
('Real Madrid','1956–1960','Avrupa’nın ilk yılları','Yeni bir kupanın başlangıcını final şehirleri ve süreklilikle incele.','İlk beş Avrupa Kupası kazanıldı. Reims iki kez rakipti: 1956 Paris, 1959 Stuttgart.'),
('Juventus','2011–2020','Torino’nun omurgası','Avrupa finalleri ve savunma ortaklıkları üzerinden dönemi keşfet.','Lig serisi 2011/12–2019/20 arasında dokuz şampiyonluktur. Buffon 2018/19’da PSG’deydi.'),
('Bayern Münih','2013–2023','Sürekliliğin gücü','Lig serisini ve Avrupa zaferlerinin teknik ekiplerini keşfet.','Lig serisi 2012/13–2022/23 arasında 11 sezondu. 2019/20 başarısına bağlı altıncı kupa Şubat 2021’de kazanıldı.'),
('Manchester United','1992–2013','Bir neslin yükselişi','Kupaların birleştiği bir sezonu ve altyapıdan doğan kuşağı araştır.','1998/99’da lig, FA Cup ve Şampiyonlar Ligi kazanıldı. Rooney Class of ’92 kuşağına dahil değildir.'),
('Trabzonspor','1975–1984','Karadeniz’in izi','Anadolu’dan yükselen takımın şampiyonluk takvimini keşfet.','Altı lig şampiyonluğu içinde en uzun kesintisiz seri 1978/79, 1979/80 ve 1980/81 sezonlarıdır.'),
('Benfica','1960–1968','Lizbon’dan Avrupa’ya','Avrupa finallerinin ve bir geri dönüşün izlerini birleştir.','1961’de Barcelona, 1962’de Real Madrid yenildi. Coluna ikinci finalde skoru 3-3 yaptı.'),
('Olympique Lyonnais','2002–2008','Gerland’ın yılları','Fransa’daki sürekliliği ve kadronun değişmeyen isimlerini keşfet.','2001/02–2007/08 arasındaki yedi şampiyonlukta Juninho, Govou ve Coupet takımdaydı.'),
('Manchester City','2017–2024','Yeni roller, yeni ufuklar','Savunmadan başlayan bir fikri ve sezonun kupa tablosunu çöz.','2022/23’te Stones topa sahipken orta sahaya çıktı. Üçleme lig, FA Cup ve Şampiyonlar Ligi’yle tamamlandı.'),
('Macaristan','1950–1956','Sınırları değiştiren takım','Bir millî takımın yeniliğini ve tarihsel karşılaşmalarını keşfet.','1953 Wembley zaferini 1954’teki Batı Almanya grup galibiyeti izledi; finalde Macaristan yenildi.'),
('Bayern Münih','1974–1976','Avrupa’ya açılan kuşak','Sahadaki omurgayı kur, final rakiplerini yıllarıyla buluştur.','1974 finali Atlético Madrid’e karşı tekrar maçında kazanıldı. Sonraki rakipler Leeds ve Saint-Étienne’di.'),
('Liverpool','1977–1984','Kırmızı miras','Avrupa yolculuklarını ve unutulmaz bir final kadrosunun son hattını keşfet.','1977, 1978, 1981 ve 1984 Avrupa Kupaları kazanıldı. Roma finalinin kalecisi Bruce Grobbelaar’dı.'),
]
# Each row: mechanic, interaction, prompt, hint, correct labels, distractors, ordered/matching periods, sources.
R=[
('tactics','single','2009 Şampiyonlar Ligi finalinde Xavi ve Iniesta’nın arkasında, savunma önündeki merkez orta saha rolünü kim üstlendi?','Barcelona altyapısından gelen, oyun kurulumunu savunmayla birleştiren oyuncuyu düşün.',['Sergio Busquets'],['Yaya Touré','Seydou Keita','Xabi Alonso'],[],['barca']),
('trophies','multi','Barcelona’nın 2009 takvim yılında kazandığı altı kupadan Avrupa ve dünya düzeyindeki üç kupayı seç.','İspanya içindeki organizasyonlarla uluslararası organizasyonları ayır.',['UEFA Şampiyonlar Ligi','UEFA Süper Kupa','FIFA Kulüpler Dünya Kupası'],['La Liga','Copa del Rey','İspanya Süper Kupası'],[],['six']),
('timeline','order','2016, 2017 ve 2018 Şampiyonlar Ligi finallerinde Real Madrid’in rakiplerini yıl sırasına koy.','Final şehirleri Milano, Cardiff ve Kiev’di.',['Atlético Madrid','Juventus','Liverpool'],[],['2016','2017','2018'],['finals']),
('squad','single','2017 Juventus finalinde Real Madrid’in ilk 11’inde başlayıp Gareth Bale’in yedek kaldığı hücum orta sahası kimdi?','İspanyol oyuncu, Benzema ve Cristiano Ronaldo’nun arkasındaydı.',['Isco'],['Gareth Bale','James Rodríguez','Marco Asensio'],[],['isco']),
('records','single','Arsenal namağlup tamamladığı 2003/04 Premier League sezonunda kaç galibiyet ve beraberlik aldı?','38 lig maçının hiçbirini kaybetmedi.',['26 galibiyet · 12 beraberlik'],['28 galibiyet · 10 beraberlik','25 galibiyet · 13 beraberlik','24 galibiyet · 14 beraberlik'],[],['arsenal']),
('squad','single','Arsenal’in 2003/04 sezonundaki 38 lig maçının tamamında forma giyen kalecisi kimdi?','Alman kaleci ilk Arsenal sezonunu yaşıyordu.',['Jens Lehmann'],['David Seaman','Manuel Almunia','Stuart Taylor'],[],['lehmann']),
('tactics','single','Arrigo Sacchi, Milan’da klasik adam adama savunma yerine hangi anlayışı öne çıkardı?','Toplu pres ve birlikte hareket eden savunma çizgisine odaklan.',['Alan savunması ve önde konumlanan savunma hattı'],['Derinde bire bir markaj ve sabit libero','Birbirinden kopuk savunma ve orta saha','Yalnızca uzun toplarla kurulan oyun'],[],['sacchi']),
('timeline','order','Milan’ın 1989, 1990 ve 1994 Avrupa kupası zaferlerindeki final rakiplerini kronolojik sırala.','Farklı ülkelerden rakipleri bu üç final gecesiyle eşleştir.',['Steaua Bükreş','Benfica','Barcelona'],[],['1989','1990','1994'],['milan','finals']),
('tactics','single','Total Futbol sisteminin temel özelliğini seç.','Sabit pozisyonlardan çok kolektif hareketi düşün.',['Pozisyon değiştirirken takımın alan ve görev düzenini korumak'],['Herkesi maç boyunca aynı noktada tutmak','Orta sahayı pas oyunundan çıkarmak','Savunma ve hücumu bağımsız bırakmak'],[],['ajax_tactics']),
('trophies','multi','Ajax’ın 1971, 1972 ve 1973 Avrupa şampiyonluğu finallerindeki üç rakibini seç.','İki rakip İtalya’dan, biri Yunanistan’dan.',['Panathinaikos','Inter','Juventus'],['Benfica','Milan','Bayern Münih'],[],['ajax']),
('timeline','order','Real Madrid’in 1956–1960 Avrupa Kupası finallerindeki rakipleri sırala. Reims kartlarında final şehirlerine dikkat et.','Aynı Fransız rakiple iki farklı şehirde karşılaşıldı.',['Reims · Paris finali','Fiorentina','Milan','Reims · Stuttgart finali','Eintracht Frankfurt'],[],['1956','1957','1958','1959','1960'],['madrid']),
('records','single','Real Madrid, Avrupa Şampiyon Kulüpler Kupası’nın ilk beş organizasyonunun kaçını kazandı?','1956 ile 1960 arasındaki turnuvaları, iki uç yılı da dahil ederek düşün.',['5'],['3','4','6'],[],['madrid']),
('trophies','multi','Juventus’un dokuz lig şampiyonluğu serisinde Şampiyonlar Ligi finaline çıkıp kupayı alamadığı iki sezonu seç.','Her iki finali de İspanyol takımları kazandı.',['2014/15','2016/17'],['2012/13','2013/14','2015/16','2018/19'],[],['finals']),
('squad','multi','Juventus’un BBC savunma üçlüsündeki futbolcuları seç.','Kısaltma üç savunmacının soyadlarının baş harfleridir.',['Andrea Barzagli','Leonardo Bonucci','Giorgio Chiellini'],['Medhi Benatia','Daniele Rugani','Stephan Lichtsteiner'],[],['bbc']),
('records','single','Bayern Münih, 2012/13’ten 2022/23’e kadar Bundesliga’yı art arda kaç kez kazandı?','İlk ve son sezonu da hesaba kat.',['11'],['9','10','12'],[],['bayern11']),
('timeline','match','Bayern’in 2013 ve 2020 Şampiyonlar Ligi zaferlerini teknik direktörleriyle eşleştir.','2013’ün başındaki isim daha sonra yeniden Bayern’i çalıştırdı.',['Jupp Heynckes','Hansi Flick'],['Pep Guardiola','Ottmar Hitzfeld'],['2013','2020'],['finals']),
('trophies','multi','Manchester United’ın 1998/99 sezonundaki üçlemesini oluşturan kupaları seç.','Lig, ülke kupası ve Avrupa’nın ana kulüp turnuvasını düşün.',['Premier League','FA Cup','UEFA Şampiyonlar Ligi'],['Lig Kupası','UEFA Kupası','UEFA Süper Kupa'],[],['united']),
('squad','single','Bu dört isimden hangisi Manchester United’ın Class of ’92 kuşağına dahil değildir?','Altyapı kuşağından sonra başka bir kulüpten gelen oyuncuyu ara.',['Wayne Rooney'],['David Beckham','Paul Scholes','Ryan Giggs'],[],['class92']),
('timeline','order','Trabzonspor’un 1975/76–1983/84 dönemindeki altı lig şampiyonluğunu sezon sırasına koy.','Sezonların başlangıç yıllarını karşılaştır.',['1975/76','1976/77','1978/79','1979/80','1980/81','1983/84'],[],[],['tff']),
('records','single','Trabzonspor’un 1975/76–1983/84 dönemindeki en uzun üst üste lig şampiyonluğu serisi kaç sezondu?','Toplam kupa sayısıyla kesintisiz serinin uzunluğu aynı değildir.',['3 sezon'],['2 sezon','4 sezon','5 sezon'],[],['tff']),
('trophies','match','Benfica’nın 1961 ve 1962 Avrupa şampiyonluğu finallerinde yendiği kulüpleri yıllarıyla eşleştir.','İki rakip de İspanya’dan.',['Barcelona','Real Madrid'],['Milan','Inter'],['1961','1962'],['benfica']),
('squad','single','Benfica’nın 1962 Real Madrid finalinde skoru 3-3 yapan orta saha oyuncusu kimdi?','Eusébio’nun iki golünden önceki beraberlik golünü düşün.',['Mário Coluna'],['Eusébio','José Águas','Domiciano Cavém'],[],['coluna']),
('records','single','Lyon 2001/02’den 2007/08’e kadar Ligue 1’i aralıksız kaç sezon kazandı?','Sezon aralığının başını ve sonunu da dahil et.',['7 sezon'],['5 sezon','6 sezon','8 sezon'],[],['lyon']),
('squad','multi','Lyon’un 2002–2008 arasındaki tüm lig şampiyonluklarında takımda bulunan üç futbolcuyu seç.','Orta saha, kanat ve kaleci üçlüsüne odaklan.',['Juninho Pernambucano','Sidney Govou','Grégory Coupet'],['Karim Benzema','Florent Malouda','Michael Essien'],[],['lyon']),
('tactics','single','Guardiola’nın 2022/23 takımında savunmadan orta sahaya çıkarak Rodri’ye destek veren futbolcu kimdi?','Topa sahip olma evresinde merkez orta sahaya geçen İngiliz savunmacıyı düşün.',['John Stones'],['Kyle Walker','Rúben Dias','Nathan Aké'],[],['stones']),
('trophies','multi','Manchester City’nin 2022/23 sezonundaki üçlemesini oluşturan kupaları seç.','Sezon üçlemesiyle sonraki takvim aylarında kazanılan kupaları ayır.',['Premier League','FA Cup','UEFA Şampiyonlar Ligi'],['Lig Kupası','UEFA Avrupa Ligi','UEFA Süper Kupa'],[],['city']),
('tactics','single','1953 Wembley maçında geriye gelerek İngiliz savunmasının markaj düzenini bozan Macar santrfor kimdi?','Modern sahte dokuz rolünün öncülerindendi.',['Nándor Hidegkuti'],['Ferenc Puskás','Sándor Kocsis','József Bozsik'],[],['hungary']),
('timeline','order','Macaristan’ın İngiltere maçını, 1954 Batı Almanya grup maçını ve 1954 finalini kronolojik sırala.','İngiltere maçı Dünya Kupası’ndan önceydi; grup aşaması finalden önce gelir.',['İngiltere’ye karşı 6-3 galibiyet','Batı Almanya’ya karşı grupta 8-3 galibiyet','Batı Almanya’ya karşı finalde 3-2 yenilgi'],[],['25 Kasım 1953','20 Haziran 1954','4 Temmuz 1954'],['hungary','wc54']),
('squad','match','Bayern’in 1974–1976 kadrosundaki libero, kaleci ve santrfor rollerini futbolcularla eşleştir.','Der Kaiser savunmada, Der Bomber ileri uçtaydı.',['Franz Beckenbauer','Sepp Maier','Gerd Müller'],['Uli Hoeneß','Franz Roth'],['Libero','Kaleci','Santrfor'],['bayernroles']),
('trophies','match','Bayern’in 1974, 1975 ve 1976 Avrupa Kupası final rakiplerini yıllarıyla eşleştir.','Rakiplerin ülkeleri İspanya, İngiltere ve Fransa.',['Atlético Madrid','Leeds United','Saint-Étienne'],['Benfica','Inter'],['1974','1975','1976'],['bayernfinals']),
('timeline','order','Liverpool’un 1977, 1978, 1981 ve 1984 Avrupa şampiyonluğu final rakiplerini sırala.','Son final rakibin kendi şehrinde oynandı.',['Borussia Mönchengladbach','Club Brugge','Real Madrid','Roma'],[],['1977','1978','1981','1984'],['liverpool']),
('squad','single','Liverpool’un 1984 Roma finalindeki başlangıç kalecisi kimdi?','Penaltı serisindeki sıra dışı hareketleriyle hatırlanır.',['Bruce Grobbelaar'],['Ray Clemence','David James','Pepe Reina'],[],['grobbelaar']),
]
def build():
 ds=[];ts=[]
 for i,(club,period,title,intro,story) in enumerate(D,1):
  ds.append(dict(id=f'DY-{i:02}',number=i,chapterId=1 if i<=8 else 2,club=club,period=period,title=title,intro=intro,story=story,taskIds=[f'DY-{i:02}-01',f'DY-{i:02}-02']))
 for n,(mechanic,interaction,prompt,hint,correct,wrong,slots,sources) in enumerate(R,1):
  era=(n+1)//2;stage=1 if n%2 else 2;tid=f'DY-{era:02}-{stage:02}'
  def key(label):return 'c'+hashlib.sha256((tid+'|'+label).encode()).hexdigest()[:12]
  opts=[dict(id=key(label),label=label) for label in correct+wrong];random.Random(tid).shuffle(opts)
  answers=[key(x) for x in correct]
  if interaction=='order' and [o['id'] for o in opts]==answers:opts=opts[1:]+opts[:1]
  explanation=' → '.join(correct) if interaction=='order' else '; '.join(correct)
  if slots:explanation='; '.join(f'{s}: {a}' for s,a in zip(slots,correct))
  refs=[dict(name=k,url=S[k]) for k in sources]
  ts.append(dict(id=tid,number=n,dynastyId=f'DY-{era:02}',stage=stage,contentVersion=2,mechanic=mechanic,interaction=interaction,title='Yükseliş' if stage==1 else 'Zirve',prompt=prompt,hint=hint,options=opts,requiredCount=len(correct),slots=slots if interaction=='match' else [],answerKeys=answers,result=dict(answer=explanation,story=explanation+'.',sources=refs,contentVersion=2),verification=dict(reviewedAt='2026-10-11',periods=slots,sources=refs)))
 private=dict(version=2,storageVersion=1,chapters=['İmparatorlukların Doğuşu','Hanedanlıkların Mirası'],dynasties=ds,tasks=ts,economy=dict(task=dict(coins=8,xp=20),hintCoins=6,milestones=[dict(count=n,coins=c,xp=x) for n,c,x in [(4,20,50),(8,40,75),(12,60,100),(16,80,150)]]))
 public=copy.deepcopy(private)
 for d in public['dynasties']:del d['story']
 for t in public['tasks']:
  for k in ['answerKeys','result','verification']:del t[k]
 return private,public
if __name__=='__main__':
 private,public=build()
 for path,data in [('functions/config/dynasties_catalog.json',private),('assets/data/dynasties_v2.json',public),('tools/dynasties/sources.json',{t['id']:t['verification'] for t in private['tasks']})]:
  (ROOT/path).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 print('16 dynasties / 32 tasks / public answers redacted')
