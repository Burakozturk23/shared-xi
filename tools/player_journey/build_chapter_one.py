"""Reviewed Chapter 1 pack. Regenerate, then run verify.py before publication."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
from pack_helpers import P, club, mates, era, timeline
S={
 'barca09':'https://www.uefa.com/newsfiles/UCL/2009/302813_LU.pdf',
 'psg':'https://en.psg.fr/teams/club/content/50-legendary-matches-paris-dance-at-marseille-in-le-classique',
 'spurs':'https://www.tottenhamhotspur.com/news/1009750/the-archive-arsenal-2-3-spurs-201110',
 'juve':'https://www.uefa.com/uefachampionsleague/news/0243-0e988f44c7ca-2cac9bed2ed7-1000--last-eight-reunion-for-juventus-and-real-madrid/',
 'milan07':'https://www.acmilan.com/en/roster-archive/men-first-team-archive/acmilan-2006-roster',
 'milan89':'https://www.acmilan.com/en/club/palmares/1988-89-champions-league',
 'zidane':'https://www.realmadrid.com/en-US/the-club/history/football-legends/zinedine-zidane',
 'kaka':'https://www.acmilan.com/en/hall-of-fame/inductees/ricardo-kaka',
 'ronaldinho':'https://players.fcbarcelona.com/en/player/763-ronaldinho-ronaldo-assis-moreira',
}
journeys=[]
def add(id,key,tasks,sources):
 for i,t in enumerate(tasks):t['id']=f'{id}_v2_{i+1}'
 journeys.append(dict(id=id,name=P[key][1],playerId=P[key][0],tasks=tasks,sources=sources))
add('messi','Messi',[
 club('İlk adım','Messi ilk resmi A takım lig maçına hangi kulüpte çıktı?',['FC Barcelona','Newell’s Old Boys','Paris Saint-Germain','River Plate'],'Altyapıda Newell’s Old Boys forması giydi. Resmi A takım lig başlangıcını 2004 yılında Barcelona ile yaptı.','Altyapı ile resmi A takım başlangıcını ayır.'),
 mates('2008–2015 arasında Barcelona A takımında Messi ile birlikte oynamış 2 futbolcuyu seç.',['Xavi','Iniesta','Puyol'],['Haaland','Kroos','Bellingham'],'Xavi, Andrés Iniesta ve Carles Puyol bu aralıkta Messi ile Barcelona forması giydi.'),
 era('2017–2021 arasında Barcelona A takımında Messi ile birlikte OYNAMAMIŞ futbolcuyu seç.','Lewandowski',['Griezmann','Dembele','Pedri'],'Lewandowski 2022’de Barcelona’ya geldi. Messi ise 2021’de ayrıldı. Diğer üç isim bu aralıkta Messi ile aynı takımdaydı.'),
 timeline('A takımında oynadığı bu üç kulübü ilkinden sonuncusuna sırala.',['FC Barcelona','Paris Saint-Germain','Inter Miami'],'Messi, Barcelona’dan 2021’de PSG’ye, 2023’te Inter Miami’ye geçti.'),
],[S['barca09']])
add('ronaldo','Ronaldo',[
 club('Eksik durak','Sporting CP → ? → Real Madrid\nBoş bırakılan kulübü seç.',['Manchester United','Manchester City','Benfica','Chelsea'],'Ronaldo, Sporting’den 2003’te Manchester United’a, 2009’da Real Madrid’e transfer oldu.','İlk yurt dışı deneyiminin ülkesini düşün.',True),
 mates('2003–2009 Manchester United döneminde Ronaldo ile aynı takımda oynamış 2 futbolcuyu seç.',['Rooney','Scholes','Rio'],['Kroos','Haaland','Bellingham'],'Wayne Rooney, Paul Scholes ve Rio Ferdinand bu dönemde Ronaldo’nun Manchester United takım arkadaşlarıydı.'),
 era('2009–2018 Real Madrid döneminde Ronaldo ile aynı takımda oynamış futbolcuyu seç.','Ramos',['Beckham','Zidane','Bellingham'],'Sergio Ramos, Ronaldo’nun Real Madrid yıllarında takım arkadaşıydı. Beckham ve Zidane daha önce ayrılmıştı; Bellingham daha sonra geldi.'),
 timeline('İlk A takımından 2021’deki dönüşüne kadar bu durakları sırala. Aynı kulüp iki kez yer alıyor.',['Sporting CP','Manchester United','Real Madrid','Juventus','Manchester United'],'Sıra: Sporting, Manchester United, Real Madrid, Juventus, Manchester United. Bu rota 2021’deki dönüşte sona eriyor.'),
],[S['barca09']])
add('ronaldinho','Ronaldinho',[
 club('Yeni kıta','Ronaldinho Avrupa’daki ilk A takım deneyimini hangi kulüpte yaşadı?',['Paris Saint-Germain','FC Barcelona','AC Milan','Olympique Lyon'],'Ronaldinho, Grêmio’dan ayrılıp 2001’de Paris Saint-Germain’e katıldı.','Fransa’daki ilk yıllarını düşün.'),
 mates('2001–2003 PSG döneminde Ronaldinho ile birlikte oynamış 2 futbolcuyu seç.',['Heinze','Okocha','Arteta'],['Haaland','Bellingham','Kroos'],'Gabriel Heinze, Jay-Jay Okocha ve Mikel Arteta, Ronaldinho’nun PSG yıllarında takım arkadaşlarıydı.'),
 era('2003–2008 Barcelona döneminde Ronaldinho ile birlikte oynamış futbolcuyu seç.','Xavi',['Griezmann','Pedri','Lewandowski'],'Xavi bu dönemde Ronaldinho ile aynı takımdaydı. Diğer adaylar daha sonraki kuşaklara ait.'),
 timeline('Avrupa’ya ilk transferinden Brezilya’ya ilk dönüşüne kadar bu durakları sırala.',['Paris Saint-Germain','FC Barcelona','AC Milan','Flamengo'],'Ronaldinho’nun bu rotası PSG, Barcelona, Milan ve 2011’de Flamengo şeklindedir. Burada Brezilya’daki ilk dönüş kulübü soruluyor.'),
],[S['psg'],S['ronaldinho']])
add('modric','Modric',[
 club('Yola çıkmadan','Modrić, Tottenham’a transfer olmadan hemen önce Hırvatistan’da hangi kulübün A takımında oynuyordu?',['Dinamo Zagreb','Hajduk Split','HNK Rijeka','NK Osijek'],'Modrić, Dinamo Zagreb’den 2008’de Tottenham’a transfer oldu. Daha önceki kiralık dönemleri bu sorunun dışında.','İngiltere’ye taşınmadan hemen önceki kulübünü düşün.'),
 mates('2008–2012 Tottenham döneminde Modrić ile birlikte oynamış 2 futbolcuyu seç.',['Bale','Lennon','Defoe'],['Son','Casemiro','Bellingham'],'Gareth Bale, Aaron Lennon ve Jermain Defoe bu aralıkta Modrić ile Tottenham forması giydi.'),
 era('Modrić’in Real Madrid yıllarında aynı takımda oynadığı futbolcuyu seç.','Casemiro',['Beckham','Zidane','RobertoCarlos'],'Casemiro, Modrić ile Real Madrid orta sahasında birlikte oynadı. Diğer üç isim Modrić gelmeden önce ayrıldı.'),
 club('Üçüncü durak','Dinamo Zagreb → Tottenham → ?\n2012’deki transferle oluşan rotayı tamamla.',['Real Madrid','AC Milan','Chelsea','Manchester United'],'Modrić, Tottenham’dan 2012’de Real Madrid’e katıldı. Bu soru 2012’deki transferde sona eriyor.','2012 yazındaki transferini hatırla.',True),
],[S['spurs']])
add('zidane','Zidane',[
 club('Eksik durak','Cannes → ? → Juventus\nEksik kulübü seç.',['Bordeaux','Olympique Marseille','AS Monaco','Paris Saint-Germain'],'Zidane, Cannes sonrası Bordeaux’da oynadı ve 1996’da Juventus’a geçti.','Fransa’daki ikinci profesyonel kulübünü düşün.',True),
 mates('1996–2001 Juventus döneminde Zidane ile aynı takımda oynamış 2 futbolcuyu seç.',['DelPiero','Deschamps','Inzaghi'],['Kroos','Bellingham','Vinicius'],'Alessandro Del Piero, Didier Deschamps ve Filippo Inzaghi, Zidane ile Juventus’ta aynı dönemde oynadı.'),
 era('2001–2006 Real Madrid döneminde Zidane’ın takım arkadaşı olan futbolcuyu seç.','RobertoCarlos',['Kroos','Vinicius','Bellingham'],'Roberto Carlos, Zidane’ın Real Madrid takım arkadaşıydı. Diğer adaylar sonraki yıllarda kulübe katıldı.'),
 timeline('Zidane’ın profesyonel A takım kariyerini ilk kulübünden son kulübüne sırala.',['Cannes','Bordeaux','Juventus','Real Madrid'],'Zidane’ın oyunculuk kariyeri Cannes, Bordeaux, Juventus ve Real Madrid sırasını izledi.'),
],[S['zidane'],S['juve']])
add('kaka','Kaka',[
 club('Okyanusun ötesi','Kaká Avrupa’daki ilk kulüp deneyimini nerede yaşadı?',['AC Milan','Real Madrid','Inter','Juventus'],'Kaká, São Paulo’dan 2003’te Milan’a transfer oldu.','İtalya’daki ilk yıllarını düşün.'),
 mates('2005–2007 Milan döneminde Kaká ile aynı takımda oynamış 2 futbolcuyu seç.',['Pirlo','Seedorf','Gattuso'],['Haaland','Kroos','Bellingham'],'Andrea Pirlo, Clarence Seedorf ve Gennaro Gattuso bu dönemde Kaká ile Milan forması giydi.'),
 era('2009–2013 Real Madrid döneminde Kaká ile aynı takımda oynamış futbolcuyu seç.','Ramos',['Kroos','Vinicius','Bellingham'],'Sergio Ramos, Kaká’nın Real Madrid takım arkadaşıydı. Diğer üç isim Kaká ayrıldıktan sonra geldi.'),
 timeline('Kaká’nın A takımda forma giydiği durakları sırala. 2014’teki kısa kiralık dönüşü de dahil.',['São Paulo','AC Milan','Real Madrid','AC Milan','São Paulo','Orlando City'],'Kaká 2014’te Orlando ile anlaştıktan sonra São Paulo’ya kiralandı. Orlando formasıyla oynamaya 2015’te başladı. Rota, sözleşme tarihini değil forma giyme sırasını izliyor.'),
],[S['kaka'],S['milan07']])
add('benzema','Benzema',[
 club('İlk forma','Benzema altyapısından yetişip ilk profesyonel A takım maçlarına hangi kulüpte çıktı?',['Olympique Lyon','Olympique Marseille','AS Monaco','Paris Saint-Germain'],'Benzema, Lyon altyapısından A takıma yükseldi. 2009’da Real Madrid’e transfer oldu.','Doğduğu şehirdeki futbol başlangıcını düşün.'),
 mates('2009–2018 Real Madrid döneminde Benzema ile birlikte oynamış 2 futbolcuyu seç.',['Ronaldo','Bale','Ramos'],['Haaland','Bellingham','Son'],'Cristiano Ronaldo, Gareth Bale ve Sergio Ramos bu dönemde Benzema ile Real Madrid forması giydi.'),
 era('2018/19–2022/23 sezonlarında Real Madrid’de Benzema ile aynı takımda oynayan futbolcuyu seç.','Vinicius',['Ronaldo','Zidane','Beckham'],'Vinicius Junior, Ronaldo’nun 2018’de ayrılmasından sonraki yıllarda Benzema ile oynadı. Bu soruda 2018/19 ve sonrası esas alınıyor.'),
 club('Yeni sayfa','Lyon → Real Madrid → ?\n2023 yazındaki transferle oluşan rotayı tamamla.',['Al-Ittihad','Al-Nassr','Al-Hilal','Al-Ahli'],'Benzema, 2023 yazında Real Madrid’den Al-Ittihad’a geçti. Bu sorunun zaman sınırı bu transferdir.','2023 yazındaki Suudi Arabistan transferini düşün.',True),
],[S['barca09']])
add('maldini','Maldini',[
 mates('1988–1991 arasında Milan A takımında Maldini ile oynamış 2 futbolcuyu seç.',['Gullit','Rijkaard','VanBasten'],['Kaka','Pirlo','Nesta'],'Ruud Gullit, Frank Rijkaard ve Marco van Basten, bu yıllarda Maldini ile Milan forması giydi.'),
 era('1990–1999 arasında Milan’da Maldini ile aynı takımda oynamış futbolcuyu seç.','Costacurta',['Kaka','Ronaldinho','Benzema'],'Alessandro Costacurta bu dönemin Milan savunmasındaydı. Kaká ve Ronaldinho daha sonra geldi; Benzema Milan’da oynamadı.'),
 mates('2003–2007 Milan döneminde Maldini ile birlikte oynamış 2 futbolcuyu seç.',['Pirlo','Seedorf','Nesta'],['Gullit','Rijkaard','Haaland'],'Andrea Pirlo, Clarence Seedorf ve Alessandro Nesta bu yıllarda Maldini’nin Milan takım arkadaşlarıydı.'),
 era('2007–2009 arasında Milan’da Maldini ile aynı takımda OYNAMAMIŞ futbolcuyu seç.','Ibrahimovic',['Kaka','Ronaldinho','Nesta'],'Maldini 2009’da futbolu bıraktı. Ibrahimović Milan’a 2010’da geldi. Kaká, Ronaldinho ve Nesta ise Maldini’nin son yıllarında onunla oynadı.'),
],[S['milan89'],S['milan07']])
extra_sources = {
 'messi': ['https://es.intermiamicf.com/noticias/inter-miami-cf-ficha-al-siete-veces-ganador-del-balon-de-oro-y-campeon-de-la-cop', 'https://players.fcbarcelona.com/en/player/2927-robert-lewandowski-robert-lewandowski'],
 'ronaldo': ['https://www.realmadrid.com/en-US/the-club/history/football-legends/cristiano-ronaldo-dos-santos-aveiro/'],
 'ronaldinho': ['https://www.psg.fr/content/la-photo-du-jour-4-aout-2001', 'https://en.psg.fr/teams/first-team/content/paris-saint-germain-players-at-the-world-cup-act-3-the-2000s'],
 'modric': ['https://www.realmadrid.com/en-US/football/squad/luka-modric'],
 'kaka': ['https://www.mlssoccer.com/competitions/mls-regular-season/news/orlando-city-sc-confirm-lawsuit-against-sao-paulo-over-missed-payments-closes'],
 'benzema': ['https://www.realmadrid.com/StaticFiles/RealMadrid/pretemporada/preseason_press_kit_0910_en.pdf', 'https://www.uefa.com/uefachampionsleague/news/0283-1888126c5b78-5c4e6a7fd9b5-1000--uefa-champions-league-transfers-ins-and-outs/'],
 'maldini': ['https://www.acmilan.com/en/roster-archive/men-first-team-archive/acmilan-1989-roster'],
}
for j in journeys:
 j['sources'] += extra_sources.get(j['id'], [])
out=ROOT/'assets/data/player_journey_chapter_one.json'
out.write_text(json.dumps(dict(version=2,chapterId='chapter_1_goat',journeys=journeys),ensure_ascii=False,indent=2)+'\n')
print(f'Wrote {len(journeys)} journeys / {sum(len(j["tasks"]) for j in journeys)} tasks')
