"""Final eight-player chapter, reviewed against the user's presentation."""
from narratives import enrich
import json
from pathlib import Path
from pack_helpers import P, club, mates, era, timeline
ROOT = Path(__file__).resolve().parents[2]
S = {
 'pirlo':'https://www.uefa.com/uefachampionsleague/news/0223-0e912cea1ac7-fc6df35643d3-1000--new-york-bound-pirlo-s-champions-league-highs/',
 'pirlo_start':'https://www.mlssoccer.com/news/andrea-pirlo-101-everything-you-need-know-about-new-york-city-fcs-new-star',
 'final05':'https://www.uefa.com/newsfiles/UCL/2004/1086988_LU.pdf',
 'henry':'https://www.newyorkredbulls.com/news/new-york-red-bulls-sign-international-star-thierry-henry',
 'arsenal':'https://www.arsenal.com/history/the-wenger-years/the-2004-invincibles?ts=dn',
 'henry_return':'https://www.uefa.com/uefachampionsleague/news/0254-0d7db9c63165-e5b8966aa34e-1000--arsenal-bring-back-henry-on-short-term-loan/',
 'gerrard':'https://www.lagalaxy.com/news/la-galaxy-sign-midfielder-steven-gerrard',
 'rooney':'https://www.dcunited.com/players/wayne-rooney/',
 'rooney_derby':'https://www.dcunited.com/news/dc-united-forward-wayne-rooney-depart-following-2019-mls-season',
 'kroos_loan':'https://fcbayern.com/en/news/2025/01/fc-bayern-players-on-loan-who-have-made-a-career-for-themselves',
 'kroos_madrid':'https://www.realmadrid.com/en-US/news/club/announcements/comunicado-oficial-toni-kroos-21-05-2024',
 'hazard':'https://www.chelseafc.com/en/news/article/eden-hazard-s-career-at-chelsea',
 'adriano':'https://www.uefa.com/uefaeuropaleague/news/019a-0e6c0cfa0be3-88feffbe3df2-1000--adriano-welcome-at-inter/',
 'adriano_return':'https://www.uefa.com/news-media/news/01d8-0f85b8be6bbd-51168ca0c124-1000--adriano-parts-company-with-inter/',
 'inter09':'https://www.inter.it/en/match_center/3758',
 'flamengo09':'https://www.flamengo.com.br/noticias/futebol/adriano-da-show-e-fla-goleia',
 'mbappe':'https://www.asmonaco.com/fr/news/kylian-mbappe-fete-ses-cinq-ans-en-pro',
 'psg18':'https://en.psg.fr/teams/first-team/content/season-2017-2018-in-numbers-5-of-5',
 'psg22':'https://www.psg.fr/equipes/equipe-premiere/content/2022-paris-puissance-10',
 'madrid24':'https://www.realmadrid.com/en-US/news/football/first-team/latest-news/comunicado-oficial-mbappe-03-06-2024',
}
journeys=[]
def add(id,key,tasks,sources):
 for i,t in enumerate(tasks):t['id']=f'{id}_v2_{i+1}'
 journeys.append(dict(id=id,name=P[key][1],playerId=P[key][0],tasks=tasks,sources=[S[s] for s in sources]))

add('pirlo','Pirlo',[
 club('İlk dokunuş','Pirlo, 1995’te Serie A’daki ilk maçına hangi kulübün A takımında çıktı?',['Brescia','Atalanta','Parma','Torino'],'Andrea Pirlo, profesyonel kariyerine Brescia’da başladı. Inter ve Milan dönemleri daha sonra geldi.','Altyapısından yetiştiği İtalyan kulübünü düşün.'),
 mates('2001–2011 Milan döneminde Pirlo ile oynamış 2 futbolcuyu seç.',['Kaka','Seedorf','Gattuso'],['Gullit','Rijkaard','VanBasten'],'Kaká, Clarence Seedorf ve Gennaro Gattuso bu dönemde Pirlo ile Milan forması giydi. Diğer üç isim kulübün daha önceki kuşağındandı.'),
 club('Yeni bir sayfa','Milan → ?\nPirlo’nun 2011 yazında katıldığı kulübü seç.',['Juventus','Inter','Roma','Napoli'],'Pirlo, 2011’de Milan’dan Juventus’a geçti. Torino’da dört sezon oynadıktan sonra 2015’te ABD’ye gitti.','2011 yazındaki transferini düşün.',True),
 timeline('Bu beş kulübü Pirlo’nun İLK KATILMA sırasına koy. Rota 2015’e kadar seçili durakları kapsar; kiralık dönüşleri ekleme.',['Brescia','Inter','AC Milan','Juventus','New York City FC'],'Seçili kulüplere ilk katılma sırası Brescia, Inter, Milan, Juventus ve NYCFC’dir. Inter dönemindeki Reggina kiralaması ve Brescia’ya kiralık dönüş bu kısa rotaya dahil değildir.'),
],['pirlo','pirlo_start','final05'])

add('henry','Henry',[
 club('İlk adım','Henry, profesyonel A takım kariyerine 1994’te hangi Fransız kulübünde başladı?',['Monaco','Lyon','Marseille','Paris Saint-Germain'],'Thierry Henry, Monaco A takımında profesyonel oldu. Juventus’taki kısa döneminin ardından Arsenal’e geçti.','İtalya ve İngiltere’den önceki kulübünü düşün.'),
 mates('1999–2007 Arsenal döneminde Henry ile oynamış 2 futbolcuyu seç.',['Bergkamp','Vieira','Ljungberg'],['Ozil','Alexis','Kane'],'Dennis Bergkamp, Patrick Vieira ve Freddie Ljungberg, Henry ile Arsenal’de oynadı. Özil ve Alexis Sánchez bu dönemden sonra geldi.'),
 era('2007–2010 Barcelona döneminde Henry ile oynamış futbolcuyu seç.','Iniesta',['Neymar','Suarez','Griezmann'],'Andrés Iniesta, Henry’nin Barcelona takım arkadaşıydı. Diğer üç isim Henry ayrıldıktan sonra kulübe katıldı.'),
 timeline('Henry’nin bu beş kulübünü İLK KATILMA sırasına koy. Rota 2010 yazında sona eriyor.',['Monaco','Juventus','Arsenal','FC Barcelona','New York Red Bulls'],'Henry önce Monaco, Juventus, Arsenal ve Barcelona’da oynadı; 2010’da New York Red Bulls’a katıldı. 2012’deki kısa Arsenal kiralaması bu sorunun tarih aralığı dışındadır.'),
],['henry','arsenal','henry_return'])

add('gerrard','Gerrard',[
 club('Evindeki ilk maç','Gerrard, 1998’de A takımına yükseldiği ve 2015’e kadar oynadığı hangi İngiliz kulübünün altyapısından yetişti?',['Liverpool','Everton','Manchester United','Aston Villa'],'Steven Gerrard, Liverpool altyapısından A takıma yükseldi. Kulüpteki uzun oyunculuk dönemi 2015’te sona erdi.','Kaptan olarak uzun yıllar forma giydiği kulübü düşün.'),
 mates('2004–2006 Liverpool döneminde Gerrard ile oynamış 2 futbolcuyu seç.',['XabiAlonso','Dudek','Kewell'],['Suarez','Salah','Mane'],'Xabi Alonso, Jerzy Dudek ve Harry Kewell bu dönemde Gerrard’ın takım arkadaşlarıydı. Üçü de 2005 İstanbul finalinin ilk 11’inde yer aldı.'),
 era('2008–2014 aralığında Liverpool’da Gerrard ile oynamış futbolcuyu seç.','Suarez',['Salah','Mane','Firmino'],'Luis Suárez, 2011–2014 arasında Gerrard ile Liverpool’da oynadı. Diğer adaylar Gerrard kulüpten ayrıldıktan sonra geldi.'),
 club('Okyanusun ötesi','Liverpool → ?\nGerrard’ın 2015 yazında forma giymeye başladığı ABD kulübünü seç.',['LA Galaxy','Los Angeles FC','New York City FC','New York Red Bulls'],'Gerrard, 2015 yazında LA Galaxy’ye katıldı ve 2016’ya kadar oynadı. LA Galaxy ile LAFC farklı kulüplerdir.','Los Angeles’taki iki kulübü karıştırma.',True),
],['gerrard','final05'])

add('rooney','Rooney',[
 club('Genç yetenek','Rooney’nin 2002’de ilk A takım maçına çıktığı profesyonel kulübünü seç.',['Everton','Manchester United','Liverpool','Newcastle United'],'Wayne Rooney, Everton’da A takıma yükseldi. 2004’te Manchester United’a transfer oldu.','Manchester yıllarından önceki kulübünü düşün.'),
 mates('2004–2009 Manchester United döneminde Rooney ile oynamış 2 futbolcuyu seç.',['Ronaldo','Scholes','Rio'],['Ibrahimovic','Casemiro','Sancho'],'Cristiano Ronaldo, Paul Scholes ve Rio Ferdinand bu dönemde Rooney ile Manchester United’da oynadı. Diğer adaylar kulübe daha sonra katıldı.'),
 club('Geri dönüş','Manchester United → ? (2017) → D.C. United\nRooney’nin bir sezon oynadığı dönüş kulübünü seç.',['Everton','Derby County','Liverpool','Tottenham'],'Rooney 2017’de Everton’a döndü. Bir sezon sonra D.C. United’a transfer oldu. Derby County dönemi daha sonradır.','2017’de çocukluk kulübüne döndü.',True),
 timeline('Rooney’nin 2002–2021 arasındaki oyunculuk duraklarını sırala. Bir kulüp iki kez yer alıyor.',['Everton','Manchester United','Everton','D.C. United','Derby County'],'Rooney, Everton’dan Manchester United’a geçti, Everton’a döndü ve ardından D.C. United ile Derby County’de oynadı. Bu rota teknik direktörlük görevlerini kapsamaz.'),
],['rooney','rooney_derby'])

add('kroos','Kroos',[
 club('Kiralık basamak','Bayern Münih → ? (2009–2010 kiralık) → Bayern Münih\nKroos’un eksik kulübünü seç.',['Bayer Leverkusen','Borussia Dortmund','Schalke 04','VfL Wolfsburg'],'Kroos, Ocak 2009’da Bayer Leverkusen’e kiralandı. 2010 yazında Bayern’e döndü.','Bayern’e dönmeden önce Bundesliga’da forma giydiği kulübü düşün.',True),
 mates('2010–2014 Bayern döneminde Kroos ile oynamış 2 futbolcuyu seç.',['Muller','Lahm','Ribery'],['Kimmich','Goretzka','Musiala'],'Thomas Müller, Philipp Lahm ve Franck Ribéry bu dönemde Kroos ile Bayern’de oynadı. Diğer adaylar Bayern A takımına daha sonra katıldı.'),
 era('2014–2024 Real Madrid döneminde Kroos ile oynamış futbolcuyu seç.','Modric',['Zidane','Beckham','Mbappe'],'Luka Modrić uzun yıllar Kroos ile Madrid orta sahasında oynadı. Zidane bu dönemde teknik direktördü; Mbappé, Kroos’un son kulüp sezonundan sonra geldi.'),
 timeline('Kroos’un A takım kariyerini 2007’den 2024’e kadar sırala. Kiralık dönemden dönüşü de dahil et.',['Bayern Münih','Bayer Leverkusen','Bayern Münih','Real Madrid'],'Kroos, Bayern’den Leverkusen’e kiralandı ve Bayern’e döndü. 2014’te Real Madrid’e geçti. Oyunculuk kariyerini 2024’te tamamladı.'),
],['kroos_loan','kroos_madrid'])

add('hazard','Hazard',[
 club('İlk sahne','Hazard, 2007’de profesyonel A takım kariyerine hangi Fransız kulübünde başladı?',['Lille','Monaco','Lyon','Marseille'],'Eden Hazard, Lille’de A takıma yükseldi. Fransa’daki çıkışının ardından 2012’de Chelsea’ye katıldı.','İngiltere’ye gitmeden önceki Fransa yıllarını düşün.'),
 mates('2012–2019 Chelsea döneminde Hazard ile oynamış 2 futbolcuyu seç.',['Lampard','Terry','Kante'],['Mane','Haaland','Bellingham'],'Frank Lampard, John Terry ve N’Golo Kanté bu dönemin farklı sezonlarında Hazard ile Chelsea’de oynadı.'),
 era('2019–2023 Real Madrid döneminde Hazard ile oynamış futbolcuyu seç.','Benzema',['Ronaldo','Mbappe','Beckham'],'Karim Benzema, Hazard’ın Madrid takım arkadaşıydı. Cristiano Ronaldo 2018’de ayrılmış, Mbappé ise 2024’te gelmişti.'),
 timeline('Hazard’ın üç profesyonel A takım kulübünü ilk katılma sırasına koy.',['Lille','Chelsea','Real Madrid'],'Hazard, Lille’den Chelsea’ye, 2019’da da Real Madrid’e geçti. Bu üç kulüp oyunculuk kariyerinin ana takım duraklarıdır.'),
],['hazard'])

add('adriano','Adriano',[
 club('Yeni kıta','Adriano, Flamengo’dan ayrılıp 2001’de hangi Avrupa kulübüne transfer oldu?',['Inter','AC Milan','Juventus','Roma'],'Adriano’nun Avrupa’daki ilk kulübü Inter’di. Sonrasında Fiorentina ve Parma’da oynayıp Inter’e döndü.','2001 yazındaki İtalya transferini düşün.'),
 club('Eksik basamak','Inter → Fiorentina → ? → Inter (2004)\nAdriano’nun 2002–2004 döneminde forma giydiği kulübü seç.',['Parma','Roma','Lazio','Napoli'],'Adriano, Fiorentina döneminden sonra Parma’da oynadı. Ocak 2004’te Inter’e döndü.','Fiorentina sonrasındaki İtalya durağını düşün.',True),
 mates('2004–2009 arasında Inter’de Adriano ile oynamış 2 futbolcuyu seç.',['Zanetti','Cambiasso','Ibrahimovic'],['Lukaku','Eriksen','Haaland'],'Javier Zanetti, Esteban Cambiasso ve Zlatan Ibrahimović bu aralıkta Adriano ile Inter’de oynadı. Lukaku ve Eriksen daha sonraki yıllarda geldi.'),
 timeline('Adriano’nun 2000–2009 arasından seçilmiş bu beş durağını sırala. Kısa rota tüm kiralık dönemleri içermez.',['Flamengo','Inter','Parma','Inter','Flamengo'],'Seçili rota Flamengo, Inter, Parma, Inter ve 2009’daki Flamengo dönüşüdür. Fiorentina ve São Paulo dönemleri bu kısa rotada gösterilmez; sonraki kariyerini de kapsamaz.'),
],['adriano','adriano_return','inter09','flamengo09'])

add('mbappe','Mbappe',[
 club('İlk ışık','Mbappé, Aralık 2015’te ilk profesyonel A takım maçına hangi kulüpte çıktı?',['Monaco','Paris Saint-Germain','Lyon','Lille'],'Kylian Mbappé, Monaco altyapısından A takıma yükseldi. İlk profesyonel maçına Aralık 2015’te çıktı.','Paris döneminden önceki kulübünü düşün.'),
 mates('2017–2024 PSG döneminde Mbappé ile oynamış 2 futbolcuyu seç.',['Neymar','Verratti','Cavani'],['Ibrahimovic','Beckham','Ronaldinho'],'Neymar, Marco Verratti ve Edinson Cavani bu dönemde Mbappé ile PSG forması giydi. Diğer adaylar Mbappé gelmeden önce ayrılmıştı.'),
 era('2021/22–2022/23 sezonlarında PSG’de Mbappé ile oynamış futbolcuyu seç.','Messi',['Ibrahimovic','Cavani','Beckham'],'Lionel Messi, 2021–2023 arasında Mbappé ile PSG’de oynadı. Cavani daha önce Mbappé’nin takım arkadaşıydı ancak bu sezonlardan önce ayrılmıştı.'),
 club('Yeni forma','Monaco → PSG → ?\nMbappé’nin 2024 yazında katıldığı kulübü seç.',['Real Madrid','Liverpool','Manchester City','FC Barcelona'],'Mbappé, 2024 yazında Real Madrid’e katıldı. Bu görev 2024 transferinde sona erer; sonraki sezonları sormaz.','2024 yazında Fransa dışındaki ilk kulübüne geçti.',True),
],['mbappe','psg18','psg22','madrid24'])

# These two routes ask first arrivals, not every spell. Their hint must agree.
for journey in journeys:
 if journey['id'] in ('pirlo','henry'):
  journey['tasks'][3]['hint']='İlk katılmaları düşün; kiralık dönüşleri tekrar sayma.'

enrich(journeys)
out=ROOT/'assets/data/player_journey_chapter_four.json'
out.write_text(json.dumps(dict(version=2,chapterId='chapter_4_icons',journeys=journeys),ensure_ascii=False,indent=2)+'\n')
print(f'Wrote {len(journeys)} journeys / {sum(len(j["tasks"]) for j in journeys)} tasks')
