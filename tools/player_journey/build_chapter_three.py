"""Reviewed third chapter from the user's eight-player presentation."""
import json
from pathlib import Path
from pack_helpers import P, club, mates, era, timeline
ROOT = Path(__file__).resolve().parents[2]
S = {
 'zlatan':'https://www.acmilan.com/en/news/articles/media/2019-12-27/zlatan-ibrahimovic-rejoins-ac-milan',
 'psg':'https://www.uefa.com/newsfiles/UCL/2015/2014403_FR.pdf',
 'kdb':'https://www.mancity.com/news/first-team/first-team-news/2016/april/chelsea-v-city-kdb-preview',
 'wolves':'https://www.bundesliga.com/de/bundesliga/news/supercup-historie-rekorde-alle-spiele-tore-meister-pokalsieger-5786',
 'city23':'https://www.uefa.com/uefachampionsleague/news/0281-18144ba42a0c-26670126d6b2-1000--champions-league-final-starting-line-ups/',
 'bayern20':'https://www.uefa.com/uefachampionsleague/news/0260-1033c96091a1-3d127374ef80-1000/',
 'haaland':'https://www.mancity.com/features/haaland/bryne/fk/',
 'bale':'https://www.lafc.com/news/lafc-signs-forward-gareth-bale',
 'spurs':'https://www.tottenhamhotspur.com/news/1009750/the-archive-arsenal-2-3-spurs-201110',
 'neymar':'https://players.fcbarcelona.com/en/player/603-neymar-neymar-da-silva-santos-junior',
 'bayern21':'https://fcbayern.com/en/club/honours/german-championship/season-2020-2021',
 'neuer':'https://fcbayern.com/en/teams/first-team/manuel-neuer/',
 'lewa':'https://www.fcbarcelona.com/en/news/4526738/robert-lewandowski/amp',
 'ramos':'https://www.realmadrid.com/es-ES/el-club/historia/leyendas-futbol/sergio-ramos-garcia/',
 'madrid':'https://www.realmadrid.com/StaticFiles/RealMadrid/img/pdf/Annual_Report_RealMadrid_2020-21.pdf',
 'sevilla':'https://sevillafc.es/es/actualidad/noticias/primera-entrevista-ramos-septiembre-2023',
}
journeys=[]
def add(id,key,tasks,sources):
 for i,t in enumerate(tasks):t['id']=f'{id}_v2_{i+1}'
 journeys.append(dict(id=id,name=P[key][1],playerId=P[key][0],tasks=tasks,sources=[S[s] for s in sources]))

add('ibrahimovic','Ibrahimovic',[
 club('İlk büyük adım','Ibrahimović, Malmö’den 2001’de ayrıldığında hangi Hollanda kulübüne katıldı?',['Ajax','PSV','Feyenoord','AZ Alkmaar'],'Malmö’de başlayan kariyerini 2001’de Ajax’a taşıdı. Hollanda’daki çıkışı, İtalya’daki uzun yolculuğunun önünü açtı.','İsveç dışındaki ilk kulübünü düşün.'),
 timeline('Ibrahimović’in 2004–2012 arasındaki bu dört kulübünü forma giyme sırasına koy.',['Juventus','Inter','FC Barcelona','AC Milan'],'Zlatan, Juventus’tan Inter’e, ardından Barcelona’ya geçti. 2010’da Milan’a kiralandı ve oradaki ilk dönemi 2012’ye kadar sürdü.'),
 mates('2012–2016 PSG döneminde Ibrahimović ile oynamış 2 futbolcuyu seç.',['Verratti','Cavani','Matuidi'],['Messi','Neymar','Bellingham'],'Marco Verratti, Edinson Cavani ve Blaise Matuidi bu dönemde Zlatan ile PSG forması giydi. Messi ve Neymar, Zlatan ayrıldıktan sonra geldi.'),
 club('Okyanusun ötesi','PSG → Manchester United → ? → AC Milan\n2018’deki transfer durağını seç. Rota 2020’deki dönüşte bitiyor.',['LA Galaxy','Los Angeles FC','Inter Miami','New York City FC'],'Ibrahimović 2018’de LA Galaxy’ye katıldı. Ardından 2020’de yeniden Milan forması giydi. LA Galaxy ve LAFC farklı kulüplerdir.','Los Angeles’taki iki farklı kulübü birbirine karıştırma.',True),
],['zlatan','psg'])

add('de_bruyne','DeBruyne',[
 club('Kiralık durak','Chelsea → ? (2012/13 kiralık) → Chelsea’ye dönüş → Wolfsburg\nDe Bruyne’nin eksik kulübünü seç.',['Werder Bremen','Hamburger SV','Hannover 96','Bayer Leverkusen'],'Genk’ten Chelsea’ye transfer olan De Bruyne, 2012/13 sezonunda Werder Bremen’e kiralandı. Chelsea’ye döndükten sonra Ocak 2014’te Wolfsburg’a geçti.','İlk Almanya deneyimi ile daha sonraki kalıcı transferini ayır.',True),
 era('2014/15 sezonunda Wolfsburg’da De Bruyne ile oynamış futbolcuyu seç.','Perisic',['Haaland','Ramos','Bellingham'],'Ivan Perišić, De Bruyne ile Wolfsburg’un 2014/15 kadrosundaydı.'),
 mates('2015/16–2019/20 sezonlarında Manchester City’de De Bruyne ile oynamış 2 futbolcuyu seç.',['Aguero','DavidSilva','Sterling'],['Haaland','Kane','Bellingham'],'Sergio Agüero, David Silva ve Raheem Sterling bu sezonlarda De Bruyne ile City’de oynadı. Haaland 2022’de geldi.'),
 era('2022/23 sezonunda üç kupa kazanan Manchester City kadrosunda De Bruyne ile oynayan futbolcuyu seç.','Rodri',['Aguero','DavidSilva','Sane'],'Rodri, 2022/23 kadrosundaydı ve Şampiyonlar Ligi finalinin golünü attı. Diğer adaylar o sezondan önce City’den ayrılmıştı.'),
],['kdb','wolves','city23'])

add('lewandowski','Lewandowski',[
 club('Yeni lig','Lech Poznań → ?\nLewandowski’nin 2010’da katıldığı ilk Bundesliga kulübünü seç.',['Borussia Dortmund','Bayern Münih','VfL Wolfsburg','Schalke 04'],'Lewandowski, 2010’da Lech Poznań’dan Borussia Dortmund’a geçti. Bayern dönemi daha sonra başladı.','Almanya’daki ilk durağını düşün.',True),
 mates('2014–2020 arasında Bayern’de Lewandowski ile oynamış 2 futbolcuyu seç.',['Neuer','Muller','Robben'],['Kane','Mane','Bellingham'],'Manuel Neuer, Thomas Müller ve Arjen Robben bu aralıkta Lewandowski ile Bayern forması giydi.'),
 era('2020 Şampiyonlar Ligi şampiyonu Bayern kadrosunda Lewandowski ile oynamış futbolcuyu seç.','Coman',['Kane','Mane','Bellingham'],'Kingsley Coman, 2020 finalinde Bayern’in galibiyet golünü attı. Kane ve Mané sonraki yıllarda kulübe geldi.'),
 timeline('Lewandowski’nin bu dört kulübünü ilk katılma sırasına koy. Rota 2008’den 2022 yazındaki transfere kadar uzanıyor.',['Lech Poznań','Borussia Dortmund','Bayern Münih','FC Barcelona'],'Lech Poznań, Dortmund, Bayern ve Barcelona sırası bu dönemin rotasıdır. Daha önceki Polonya kulüpleri bu sorunun kapsamı dışındadır.'),
],['bayern20','lewa'])

add('haaland','Haaland',[
 timeline('Haaland’ın ilk üç A takım durağını sırala. Rota 2019’da bitiyor.',['Bryne','Molde','Red Bull Salzburg'],'Haaland, Bryne’den Molde’ye geçti. Sonraki basamağı 2019’da Red Bull Salzburg oldu.'),
 mates('2020–2022 Dortmund döneminde Haaland ile oynamış 2 futbolcuyu seç.',['Reus','Brandt','Sancho'],['Lewandowski','DeBruyne','Rodri'],'Marco Reus, Julian Brandt ve Jadon Sancho bu aralıkta Haaland ile Dortmund’da oynadı. Lewandowski 2014’te ayrılmıştı.'),
 era('2022/23 Manchester City kadrosunda Haaland ile oynayan futbolcuyu seç.','DeBruyne',['Aguero','DavidSilva','Sane'],'Kevin De Bruyne, Haaland’ın ilk City sezonunda takım arkadaşıydı. Diğer adaylar Haaland gelmeden önce ayrılmıştı.'),
 club('Bir sonraki adım','Molde → Salzburg → Dortmund → ?\nHaaland’ın 2022 yazındaki transferini tamamla.',['Manchester City','Manchester United','Real Madrid','Chelsea'],'Haaland, 2022 yazında Manchester City’ye katıldı. İlk sezonunda lig, FA Cup ve Şampiyonlar Ligi şampiyonluğu yaşadı.','2022 yazında katıldığı İngiliz kulübünü düşün.',True),
],['haaland','city23'])

add('bale','Bale',[
 club('Yükseliş','Bale, Southampton’dan 2007’de ayrılıp Premier League’de hangi kulübe katıldı?',['Tottenham','Arsenal','Chelsea','Manchester United'],'Bale, Southampton’dan Tottenham’a geçti. Sol bekten hücumun önemli isimlerinden birine dönüşerek yıldızlaştı.','Madrid’den önceki Londra yıllarını düşün.'),
 mates('2010–2013 Tottenham döneminde Bale ile oynamış 2 futbolcuyu seç.',['Modric','Lennon','Defoe'],['Son','DeBruyne','Rodri'],'Luka Modrić, Aaron Lennon ve Jermain Defoe bu aralıkta Bale ile Tottenham’da oynadı. Son 2015’te geldi.'),
 era('2013–2018 Real Madrid döneminde Bale ile oynamış futbolcuyu seç.','Benzema',['Beckham','Zidane','Bellingham'],'Karim Benzema, Bale’in Madrid takım arkadaşıydı. Birlikte Avrupa kupalarında başarılar yaşadılar.'),
 timeline('Bu dört kulübü Bale’in İLK KATILMA sırasına koy. Kiralık dönüşleri tekrar ekleme; rota 2022’de sona eriyor.',['Southampton','Tottenham','Real Madrid','Los Angeles FC'],'İlk katılma sırası Southampton, Tottenham, Real Madrid ve LAFC’dir. Bale 2020/21’de Tottenham’a kiralandı, Madrid’e döndü ve 2022’de LAFC’ye geçti. Bu görev ilk katılmaları soruyor.'),
],['bale','spurs'])

add('neymar','Neymar',[
 club('İlk forma','Neymar, profesyonel A takım kariyerine 2009’da hangi kulüpte başladı?',['Santos','Flamengo','Palmeiras','São Paulo'],'Neymar, Santos altyapısından A takıma yükseldi. 2009’daki başlangıcından sonra Brezilya’da dikkatleri üzerine çekti.','Avrupa’ya gitmeden önceki Brezilya kulübünü düşün.'),
 mates('2013–2017 Barcelona döneminde Neymar ile oynamış 2 futbolcuyu seç.',['Messi','Suarez','Iniesta'],['Pedri','Lewandowski','Bellingham'],'Lionel Messi, Luis Suárez ve Andrés Iniesta bu aralıkta Neymar’ın Barcelona takım arkadaşlarıydı.'),
 club('Rekor transfer','Santos → Barcelona → ?\nNeymar’ın 2017 yazındaki transferini tamamla.',['Paris Saint-Germain','Manchester City','Real Madrid','Bayern Münih'],'Neymar, 2017’de Barcelona’dan Paris Saint-Germain’e transfer oldu.','2017’deki Fransa transferini düşün.',True),
 timeline('Neymar’ın 2009’dan 2023 yazındaki transferine kadar bu dört durağını sırala.',['Santos','FC Barcelona','Paris Saint-Germain','Al-Hilal'],'Neymar’ın 2023’e kadarki rotası Santos, Barcelona, PSG ve Al-Hilal şeklindedir. Bu görev 2023’te sona erer; sonraki transferleri kapsamaz.'),
],['neymar'])

add('neuer','Neuer',[
 club('Kaleye ilk adım','Neuer, altyapısından yetişip 2006’da Bundesliga’da kaleye geçtiği hangi kulüpte oynadı?',['Schalke 04','Bayern Münih','Borussia Dortmund','Bayer Leverkusen'],'Neuer, Schalke altyapısından yetişti ve Bundesliga’daki ilk maçına 2006’da çıktı. 2011’de Bayern’e geçti.','Bayern’e gelmeden önceki kulübünü düşün.'),
 mates('2011–2014 Bayern döneminde Neuer ile oynamış 2 futbolcuyu seç.',['Lahm','Muller','Ribery'],['Kane','Mane','Bellingham'],'Philipp Lahm, Thomas Müller ve Franck Ribéry bu dönemde Neuer ile Bayern’de oynadı.'),
 era('2014–2020 arasında Bayern savunmasında Neuer ile birlikte oynamış futbolcuyu seç.','Boateng',['Ramos','Godin','Terry'],'Jérôme Boateng bu dönemde Neuer’in önünde Bayern savunmasında görev yaptı. Diğer üç aday Bayern’de oynamadı.'),
 mates('2020/21–2021/22 sezonlarında Bayern’de Neuer ile oynamış 2 futbolcuyu seç.',['Kimmich','Goretzka','Musiala'],['Lahm','Robben','Ribery'],'Joshua Kimmich, Leon Goretzka ve Jamal Musiala bu sezonlarda Neuer ile oynadı. Lahm, Robben ve Ribéry önceki yıllarda Bayern’den ayrılmıştı.'),
],['bayern20','bayern21','neuer'])

add('ramos','Ramos',[
 club('Yeni sorumluluk','Sevilla → ?\nRamos’un 2005’te transfer olduğu kulübü seç.',['Real Madrid','FC Barcelona','Atlético Madrid','Valencia'],'Ramos, Sevilla’dan 2005’te Real Madrid’e geçti. Burada yıllar içinde savunmanın ve takımın liderlerinden biri oldu.','2005’teki büyük transferini düşün.',True),
 mates('2005–2014 arasında Real Madrid’de Ramos ile oynamış 2 futbolcuyu seç.',['Ronaldo','Benzema','Modric'],['Bellingham','Haaland','Pedri'],'Cristiano Ronaldo, Karim Benzema ve Luka Modrić bu aralıkta Ramos ile Real Madrid’de oynadı.'),
 era('2015/16, 2016/17 ve 2017/18 sezonlarında üst üste üç Şampiyonlar Ligi kazanan Madrid kadrosunda Ramos ile oynayan futbolcuyu seç.','Kroos',['Beckham','Zidane','Bellingham'],'Toni Kroos, Ramos ile bu üç şampiyonluğu kazandı. Zidane bu dönemde teknik direktördü; soruda futbolcu olarak aynı kadroda bulunan isim aranıyor.'),
 timeline('Ramos’un ilk A takımından 2023’teki dönüşüne kadar bu durakları sırala. Aynı kulüp iki kez yer alıyor.',['Sevilla','Real Madrid','Paris Saint-Germain','Sevilla'],'Ramos, Sevilla’dan Madrid’e, 2021’de PSG’ye ve 2023’te yeniden Sevilla’ya geçti. Bu rota 2023 dönüşünde biter.'),
],['ramos','madrid','sevilla'])

out=ROOT/'assets/data/player_journey_chapter_three.json'
out.write_text(json.dumps(dict(version=2,chapterId='chapter_3_architects',journeys=journeys),ensure_ascii=False,indent=2)+'\n')
print(f'Wrote {len(journeys)} journeys / {sum(len(j["tasks"]) for j in journeys)} tasks')
