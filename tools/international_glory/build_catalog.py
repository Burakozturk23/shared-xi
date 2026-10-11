"""Reproducible editorial catalog. No StatsBomb data is imported or shipped."""
import json, random, unicodedata
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
CHAPTERS=['Dünya Kupası Efsaneleri','Avrupa Şampiyonası Efsaneleri','Kıtaların Kahramanları','Modern Millî Futbol']
# date | teams | tournament | stage | mechanic | prompt | ordered correct labels | distractors | FT | ET | PSO
ROWS='''1986-06-22|Arjantin;İngiltere|Dünya Kupası 1986|Çeyrek final|critical|Arjantin’in ünlü solo golünü atan futbolcu kimdi?|Diego Maradona|Jorge Valdano;Jorge Burruchaga;Gary Lineker|2-1||
2014-07-08|Brezilya;Almanya|Dünya Kupası 2014|Yarı final|timeline|Seçilmiş dört Alman golünü sırala: ilk gol, Klose’nin golü, Kroos’un ilk golü ve beşinci gol.|Thomas Müller;Miroslav Klose;Toni Kroos;Sami Khedira||1-7||
2022-12-18|Arjantin;Fransa|Dünya Kupası 2022|Final|penalty|Arjantin’in şampiyonluğunu kesinleştiren son seri penaltısını kim attı?|Gonzalo Montiel|Lionel Messi;Paulo Dybala;Leandro Paredes|2-2|3-3|4-2
2006-07-09|İtalya;Fransa|Dünya Kupası 2006|Final|critical|Uzatmalarda kırmızı kart gören Fransız kaptan kimdi?|Zinedine Zidane|Thierry Henry;Patrick Vieira;Lilian Thuram|1-1|1-1|5-3
1998-07-12|Fransa;Brezilya|Dünya Kupası 1998|Final|route|Fransa’nın çeyrek final, yarı final ve final rakiplerini eşleştir.|İtalya;Hırvatistan;Brezilya||3-0||
1998-06-30|Arjantin;İngiltere|Dünya Kupası 1998|Son 16|penalty|İngiltere’nin son seri penaltısını kim kullanıp kaçırdı?|David Batty|Alan Shearer;Michael Owen;Paul Merson|2-2|2-2|4-3
2014-06-13|Hollanda;İspanya|Dünya Kupası 2014|Grup|critical|Hollanda’nın uçarak kafa vuruşuyla beraberliği sağlayan ismi kimdi?|Robin van Persie|Arjen Robben;Wesley Sneijder;Daley Blind|5-1||
2010-07-02|Uruguay;Gana|Dünya Kupası 2010|Çeyrek final|timeline|İki normal süre golü, çizgide el müdahalesi, kaçan penaltı ve seri sonucunu sırala.|Sulley Muntari;Diego Forlán;Luis Suárez (el);Asamoah Gyan (kaçan penaltı);Uruguay turu||1-1|1-1|4-2
1994-07-17|Brezilya;İtalya|Dünya Kupası 1994|Final|penalty|İtalya’nın son seri penaltısını üstten dışarı atan kimdi?|Roberto Baggio|Franco Baresi;Daniele Massaro;Demetrio Albertini|0-0|0-0|3-2
2002-06-30|Brezilya;Almanya|Dünya Kupası 2002|Final|critical|Finalde iki gol atarak Brezilya’yı şampiyon yapan isim kimdi?|Ronaldo Nazário|Rivaldo;Ronaldinho;Kleberson|2-0||
2004-07-04|Portekiz;Yunanistan|EURO 2004|Final|critical|Yunanistan’a şampiyonluğu getiren final golünü kim attı?|Angelos Charisteas|Traianos Dellas;Giorgos Karagounis;Zisis Vryzas|0-1||
1992-06-26|Danimarka;Almanya|EURO 1992|Final|route|Danimarka’nın son grup galibiyetinden finale uzanan rakiplerini eşleştir.|Fransa;Hollanda;Almanya||2-0||
2016-07-10|Portekiz;Fransa|EURO 2016|Final|critical|Uzatmalarda kupayı getiren golü kim attı?|Éder|Cristiano Ronaldo;Nani;Ricardo Quaresma|0-0|1-0|
2000-07-02|Fransa;İtalya|EURO 2000|Final|timeline|Finaldeki üç golcüyü gerçekleşme sırasına koy.|Marco Delvecchio;Sylvain Wiltord;David Trezeguet||1-1|2-1|
2012-07-01|İspanya;İtalya|EURO 2012|Final|xi|İspanya’nın ilk 11’inde başlayıp sonradan Torres’e yerini bırakan hücumcu kimdi?|Cesc Fàbregas|Fernando Torres;Pedro Rodríguez;Fernando Llorente|4-0||
2021-07-11|İtalya;İngiltere|EURO 2020|Final|penalty|İngiltere’nin penaltı serisinde direğe vuran ismi kimdi?|Marcus Rashford|Jadon Sancho;Bukayo Saka;Harry Kane|1-1|1-1|3-2
2004-07-01|Yunanistan;Çekya|EURO 2004|Yarı final|critical|Uzatmalarda gümüş golü atan Yunan savunmacı kimdi?|Traianos Dellas|Angelos Charisteas;Takis Fyssas;Giourkas Seitaridis|0-0|1-0|
2000-06-29|Hollanda;İtalya|EURO 2000|Yarı final|penalty|Seride “Cucchiaio” aşırtmasını yapan İtalyan futbolcu kimdi?|Francesco Totti|Alessandro Del Piero;Luigi Di Biagio;Paolo Maldini|0-0|0-0|1-3
2016-07-01|Galler;Belçika|EURO 2016|Çeyrek final|timeline|Karşılaşmadaki dört golcüyü kronolojik sıraya koy.|Radja Nainggolan;Ashley Williams;Hal Robson-Kanu;Sam Vokes||3-1||
1988-06-25|Hollanda;SSCB|EURO 1988|Final|critical|Finalde dar açıdan unutulmaz vole golünü atan kimdi?|Marco van Basten|Ruud Gullit;Frank Rijkaard;Ronald Koeman|2-0||
2012-02-12|Zambiya;Fildişi Sahili|AFCON 2012|Final|penalty|Zambiya’ya kupayı getiren son seri penaltısını kim attı?|Stoppila Sunzu|Christopher Katongo;Emmanuel Mayuka;Kennedy Mweene|0-0|0-0|8-7
2024-02-11|Fildişi Sahili;Nijerya|AFCON 2023|Final|route|Fildişi Sahili’nin son 16’dan itibaren geçtiği rakipleri eşleştir.|Senegal;Mali;DC Kongo;Nijerya||2-1||
2022-02-06|Senegal;Mısır|AFCON 2021|Final|penalty|Senegal’in şampiyonluğunu kesinleştiren seri penaltısını kim attı?|Sadio Mané|Kalidou Koulibaly;Abdou Diallo;Bamba Dieng|0-0|0-0|4-2
2021-07-10|Arjantin;Brezilya|Copa América 2021|Final|critical|Finalin tek golünü atan Arjantinli futbolcu kimdi?|Ángel Di María|Lionel Messi;Lautaro Martínez;Rodrigo De Paul|1-0||
2016-06-26|Şili;Arjantin|Copa América 2016|Final|xi|Şili’nin finalde ilk 11 başlayan kalecisi kimdi?|Claudio Bravo|Johnny Herrera;Cristopher Toselli;Sergio Romero|0-0|0-0|4-2
2004-07-25|Brezilya;Arjantin|Copa América 2004|Final|timeline|Finaldeki dört golcüyü kronolojik sıraya koy.|Kily González;Luisão;César Delgado;Adriano||2-2||4-2
2007-07-15|Brezilya;Arjantin|Copa América 2007|Final|route|Brezilya’nın çeyrek final, yarı final ve final rakiplerini eşleştir.|Şili;Uruguay;Arjantin||3-0||
2007-07-29|Irak;Suudi Arabistan|Asya Kupası 2007|Final|xi|Irak’ın finalde ilk 11’deki takım kaptanı kimdi?|Younis Mahmoud|Hawar Mulla Mohammed;Nashat Akram;Noor Sabri|1-0||
1999-07-04|Arjantin;Kolombiya|Copa América 1999|Grup|penalty|Maç sırasında üç penaltı kaçıran Arjantinli kimdi?|Martín Palermo|Gabriel Batistuta;Hernán Crespo;Ariel Ortega|0-3||
2001-07-29|Kolombiya;Meksika|Copa América 2001|Final|route|Kolombiya’nın çeyrek finalden itibaren oynadığı rakipleri eşleştir.|Peru;Honduras;Meksika||1-0||
2018-07-02|Belçika;Japonya|Dünya Kupası 2018|Son 16|timeline|Japonya’nın öne geçmesinden Belçika’nın galibiyetine kadarki beş golcüyü sırala.|Genki Haraguchi;Takashi Inui;Jan Vertonghen;Marouane Fellaini;Nacer Chadli||3-2||
2018-06-30|Fransa;Arjantin|Dünya Kupası 2018|Son 16|critical|Fransa’ya beraberliği getiren ünlü vole golünü kim attı?|Benjamin Pavard|Kylian Mbappé;Antoine Griezmann;Paul Pogba|4-3||
2022-11-22|Arjantin;Suudi Arabistan|Dünya Kupası 2022|Grup|critical|Suudi Arabistan’ın galibiyet golünü kim attı?|Salem Al-Dawsari|Saleh Al-Shehri;Firas Al-Buraikan;Mohammed Kanno|1-2||
2022-12-09|Hollanda;Arjantin|Dünya Kupası 2022|Çeyrek final|penalty|Arjantin’in turu garantileyen son seri penaltısını kim attı?|Lautaro Martínez|Lionel Messi;Leandro Paredes;Gonzalo Montiel|2-2|2-2|3-4
2022-12-09|Hırvatistan;Brezilya|Dünya Kupası 2022|Çeyrek final|xi|Hırvatistan’ın çeyrek finaldeki başlangıç kalecisi kimdi?|Dominik Livaković|Ivo Grbić;Ivica Ivušić;Danijel Subašić|0-0|1-1|4-2
2022-12-10|Fas;Portekiz|Dünya Kupası 2022|Çeyrek final|route|Fas’ın yarı finale giderken eleme turlarında geçtiği iki ülkeyi eşleştir.|İspanya;Portekiz||1-0||
2024-06-18|Türkiye;Gürcistan|EURO 2024|Grup|xi|Türkiye’nin başlangıç 11’inde sol bek oynayan isim kimdi?|Ferdi Kadıoğlu|Zeki Çelik;Rıdvan Yılmaz;Eren Elmalı|3-1||
2024-06-26|Türkiye;Çekya|EURO 2024|Grup|critical|Türkiye’nin son bölümdeki galibiyet golünü kim attı?|Cenk Tosun|Hakan Çalhanoğlu;Arda Güler;Kenan Yıldız|2-1||
2024-07-06|Hollanda;Türkiye|EURO 2024|Çeyrek final|timeline|Karşılaşmanın üç gol olayını kronolojik sıraya koy.|Samet Akaydin;Stefan de Vrij;Mert Müldür (KK)||2-1||
2024-07-14|İspanya;İngiltere|EURO 2024|Final|route|İspanya’nın son 16, çeyrek final, yarı final ve final rakiplerini eşleştir.|Gürcistan;Almanya;Fransa;İngiltere||2-1||'''
TIMES={2:['11','23','24','29'],8:['45+2','55','120','120+1','Penaltı serisi'],14:['55','90+4','103'],19:['13','31','55','86'],26:['20','45+1','87','90+3'],31:['48','52','69','74','90+4'],39:['35','70','76']}
LINEUPS={15:[['Iker Casillas'],['Álvaro Arbeloa','Gerard Piqué','Sergio Ramos','Jordi Alba'],['Xabi Alonso','Sergio Busquets'],['David Silva','Xavi','Andrés Iniesta'],['?']],25:[['?'],['Mauricio Isla','Gary Medel','Gonzalo Jara','Jean Beausejour'],['Charles Aránguiz','Marcelo Díaz','Arturo Vidal'],['José Pedro Fuenzalida','Eduardo Vargas','Alexis Sánchez']],28:[['Noor Sabri'],['Jassim Ghulam','Bassem Abbas','Ali Rehema','Haidar Abdul Amir'],['Nashat Akram','Mahdi Karim','Qusay Munir','Hawar Mulla Mohammed'],['Karrar Jassim','?']],35:[['?'],['Josip Juranović','Dejan Lovren','Joško Gvardiol','Borna Sosa'],['Luka Modrić','Marcelo Brozović','Mateo Kovačić'],['Mario Pašalić','Andrej Kramarić','Ivan Perišić']],37:[['Mert Günok'],['Mert Müldür','Samet Akaydin','Abdülkerim Bardakcı','?'],['Kaan Ayhan','Hakan Çalhanoğlu'],['Arda Güler','Orkun Kökçü','Kenan Yıldız'],['Barış Alper Yılmaz']]}
NOTES={2:'Kroos’un 26. dakikadaki ikinci golü bu seçilmiş dört olay arasında değildir.',14:'Altın gol kuralı: Trezeguet’nin golüyle karşılaşma hemen sona erdi.',16:'Rashford direğe vurdu. Donnarumma, Sancho ve Saka’nın penaltılarını kurtardı.',17:'Gümüş gol kuralı: İlk uzatma devresi sonunda önde olan Yunanistan finale çıktı.',22:'Turnuvanın adı AFCON 2023; final 2024 takvim yılında oynandı.',23:'Turnuvanın adı AFCON 2021; final 2022’de oynandı. Maç içindeki kaçan penaltı ile son seri vuruşu farklıdır.',26:'Normal sürenin ardından uzatma oynanmadan penaltı serisine geçildi.',29:'Bu olay penaltı serisi değil, maç içindeki üç ayrı penaltıdır.',39:'Galibiyet golü Mert Müldür’ün kendi kalesine golü olarak kaydedildi.'}
NOTES.update({
1:'Solo golüyle öne çıkan Arjantin, çeyrek finali 2-1 kazanarak yoluna devam etti.',
3:'Normal süre 2-2, uzatma 3-3 bitti. Montiel’in son vuruşuyla seri Arjantin lehine 4-2 tamamlandı.',
4:'Fransa kaptanı uzatmalarda oyun dışında kaldı. İtalya, 1-1 biten finali penaltı serisiyle kazandı.',
5:'Fransa, çeyrek finalde İtalya’yı, yarı finalde Hırvatistan’ı ve finalde Brezilya’yı geçti.',
6:'Batty’nin son vuruşunu Roa kurtardı. Arjantin seriyi 4-3 kazanarak çeyrek finale çıktı.',
7:'Van Persie’nin kafa golü Hollanda’ya beraberliği getirdi; karşılaşma 5-1 tamamlandı.',
8:'Normal süre golleri Muntari ve Forlán’dan geldi. Uzatmanın sonundaki el, kırmızı kart ve kaçan penaltının ardından turu seri belirledi.',
9:'Baggio’nun vuruşu üstten dışarı gitti. Golsüz finalin ardından Brezilya penaltılarda 3-2 üstünlük sağladı.',
10:'Ronaldo finalin iki golünü de atarak Brezilya’nın 2-0 galibiyetini sağladı.',
11:'Charisteas’ın kafa golü, ev sahibi Portekiz karşısında Yunanistan’a kupayı getirdi.',
12:'Danimarka son grup maçında Fransa’yı yendi; Hollanda’yı seride geçip finalde Almanya’yı mağlup etti.',
13:'Normal süre golsüz bitti. Éder’in uzatmalardaki golü Portekiz’e ilk Avrupa şampiyonluğunu getirdi.',
15:'Fàbregas başlangıç on birindeydi ve 75. dakikada yerini Torres’e bıraktı. İspanya finali 4-0 kazandı.',
18:'Totti’nin aşırtma vuruşu penaltı serisindeydi. İtalya seriyi 3-1 kazanarak finale çıktı.',
19:'Belçika öne geçti; Galler, Williams, Robson-Kanu ve Vokes ile yanıt verip yarı finale yükseldi.',
20:'Van Basten’in dar açıdan volesi, Hollanda’nın finaldeki ikinci golüydü.',
21:'Sunzu son vuruşu gole çevirdi. Zambiya golsüz finalin ardından uzun seriyi 8-7 kazandı.',
24:'Di María’nın golü finaldeki tek gol oldu. Arjantin 1-0 kazanarak kupaya ulaştı.',
25:'Bravo finalin başlangıç kalecisiydi. Şili, golsüz normal süre ve uzatmadan sonra seriyi 4-2 kazandı.',
27:'Brezilya eleme turlarında Şili, Uruguay ve Arjantin ile karşılaştı; finali 3-0 kazandı.',
28:'Younis Mahmoud ilk on birin kaptanıydı. Finalin tek golünü de atarak Irak’a kupayı getirdi.',
30:'Kolombiya çeyrek finalde Peru, yarı finalde Honduras ve finalde Meksika’yı geçti.',
31:'Japonya iki farklı üstünlüğe ulaştı. Vertonghen, Fellaini ve Chadli’nin golleri Belçika’yı çeyrek finale taşıdı.',
32:'Pavard’ın volesi skoru 2-2 yaptı. Fransa son 16 karşılaşmasını 4-3 kazandı.',
33:'Suudi Arabistan, Al-Shehri ve Al-Dawsari’nin golleriyle geriden gelerek 2-1 kazandı.',
34:'Normal süre ve uzatma 2-2 bitti. Lautaro Martínez’in son seri vuruşuyla Arjantin yarı finale yükseldi.',
35:'Livaković başlangıç on birindeydi. Hırvatistan normal süresi golsüz, uzatması 1-1 biten maçı seriyle kazandı.',
36:'Fas, son 16’da İspanya’yı ve çeyrek finalde Portekiz’i eleyerek yarı finale ulaştı.',
37:'Ferdi Kadıoğlu başlangıç on birinin sol bek bölgesindeydi. Türkiye grup açılışını 3-1 kazandı.',
38:'Tosun’un son bölümdeki golü, Türkiye’ye 2-1 galibiyeti ve son 16 biletini getirdi.',
40:'İspanya sırasıyla Gürcistan, Almanya, Fransa ve İngiltere’yi geçerek Avrupa şampiyonu oldu.',
})
def slug(s):return ''.join(c for c in unicodedata.normalize('NFKD',s).lower() if c.isascii() and c.isalnum())
def build():
 sources=json.loads((ROOT/'tools/international_glory/sources.json').read_text())
 matches=[]
 for n,line in enumerate(ROWS.splitlines(),1):
  date,teams,competition,stage,kind,prompt,correct,wrong,ft,et,pso=line.split('|');home,away=teams.split(';');answer=correct.split(';');labels=answer+(wrong.split(';') if wrong else [])
  options=[{'id':slug(label),'label':label} for label in labels];keys=[slug(x) for x in answer];random.Random(731+n).shuffle(options)
  if kind in ('timeline','route') and [o['id'] for o in options]==keys:options=options[1:]+options[:1]
  m={'id':f'ig2_{n:02}','number':n,'contentVersion':2,'chapterId':(n-1)//10+1,'date':date,'competition':competition,'round':stage,'home':{'id':slug(home),'name':home},'away':{'id':slug(away),'name':away},'title':f'{home} – {away}','intro':f'{competition}: {home} ve {away}, {stage.lower()} karşılaşmasında sahaya çıkıyor. Ülke formalarının arkasındaki hikâyeyi tek görevle hatırla.','type':kind,'difficulty':'Orta' if kind in ('route','timeline') else 'Kolay','prompt':prompt,'clock':('Maç içi penaltı' if n==29 else 'Penaltı serisi') if kind=='penalty' else 'Millî takım arşivi','hint':{'critical':'Soruda tarif edilen tek olaya odaklan; maçın diğer golleriyle karıştırma.','penalty':'Maç içindeki vuruşlar ile maçtan sonraki seriyi birbirinden ayır.','timeline':'Normal süre, uzatma ve penaltı serisi farklı aşamalardır.','route':'Tur sırasını izleyerek rakipleri yerleştir.','xi':'Yedek kulübesini değil, başlangıç düdüğündeki on biri düşün.'}[kind],'options':options,'answerKeys':keys}
  if kind=='route':m['slots']={12:['Son grup maçı','Yarı final','Final'],22:['Son 16','Çeyrek final','Yarı final','Final'],36:['Son 16','Çeyrek final'],40:['Son 16','Çeyrek final','Yarı final','Final']}.get(n,['Çeyrek final','Yarı final','Final'])
  if kind=='xi':m['lineup']={'club':home,'rows':LINEUPS[n]}
  m['result']={'answer':' → '.join(answer),'story':(' → '.join(answer)+'. '+NOTES.get(n,'Bu karşılaşmanın hatırası Milletler Albümü’ne eklendi.')),'score':et or ft,'scoreFT':ft,'scoreET':et or None,'penalties':[int(x) for x in pso.split('-')] if pso else None,'duration':103 if n==14 else 105 if n==17 else 120 if et else 90,'events':[{'label':label,'minute':minute} for label,minute in zip(answer,TIMES.get(n,[]))],'sources':sources[str(n)]}
  m['verification']={'verifiedAt':'2026-10-11','coverage':'starting_xi' if kind=='xi' else 'selected_match_facts','editorial':True,'sources':sources[str(n)]}
  matches.append(m)
 economy={'match':{'coins':8,'xp':20},'milestones':[{'count':n,'coins':c,'xp':x} for n,c,x in [(10,40,75),(20,70,100),(30,90,125),(40,120,175)]],'hintCoins':6}
 private={'version':2,'chapters':CHAPTERS,'economy':economy,'matches':matches}
 public={'version':2,'chapters':CHAPTERS,'matches':[{k:v for k,v in m.items() if k not in ('answerKeys','result','verification')} for m in matches]}
 for name,data in [('functions/config/international_catalog.json',private),('assets/data/international_glory_v2.json',public)]: (ROOT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':build()
