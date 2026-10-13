"""Append-only expansion exports. Never rewrites a legacy catalog or database."""
import copy, hashlib, json
from urllib.parse import urlsplit
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).parent
S=json.loads((HERE/'sources.json').read_text())
S['S33']='https://archive.coritiba.com.br/arq/sanfonas/lt/idolos.html'
S['S34']='https://www.fifa.com/pt/articles/historia-brasil-finais-copa-mundo-fifa'
PACK='five-mode-2026-10'
def sources(*codes): return [{'name':urlsplit(S[c]).netloc,'label':urlsplit(S[c]).netloc,'url':S[c],'accessed':'2026-10-12'} for c in codes]
def task(id,prompt,answers,wrong,hint,src,kind='single',story=None):
    labels=answers+wrong
    assert len(set(labels))==len(labels),id
    # Keys and presentation order are independent of correctness and answer position.
    key=lambda label:hashlib.sha256((id+'|'+label).encode()).hexdigest()[:12]
    options=sorted([{'id':key(l),'label':l} for l in labels],key=lambda o:o['id'])
    return dict(id=id,prompt=prompt,options=options,answerKeys=[key(a) for a in answers],
        requiredCount=len(answers),hint=hint,contentVersion=1,expansion=PACK,rewardPolicy='mode_default',
        result=dict(answer=' → '.join(answers) if kind=='order' else ', '.join(answers),
                    story=story or 'Doğru cevap: '+', '.join(answers)+'.',sources=sources(*src)))

def build():
    pj=dict(version=2,chapterId='chapter_5_expansion',journeys=[])
    people=[('PJ-33','Pelé',4000000065),('PJ-34','Diego Maradona',4000000035),('PJ-35','Ronaldo Nazário',3140),('PJ-36','Gianluigi Buffon',5023),('PJ-37','Gheorghe Hagi',4000000002),('PJ-38','Alex de Souza',4000000110),('PJ-39','Ricardo Quaresma',4188),('PJ-40','Burak Yılmaz',4000000108)]
    wrongs=[
      [['Flamengo','Palmeiras','Corinthians'],['1950','1954','1966'],['1960','1961','1964'],['Flamengo','Boca Juniors','Benfica']],
      [['River Plate','Racing Club','Independiente'],['Real Madrid','Valencia','Atlético Madrid'],['1984/85','1985/86','1987/88'],['Sevilla','Newell’s Old Boys','River Plate']],
      [['Flamengo','Santos FC','Palmeiras'],['Ajax','Benfica','Feyenoord'],['Juventus','AC Milan','Lazio'],['AC Milan','Corinthians','Flamengo']],
      [['Juventus','Genoa','Bologna'],['Inter','Lazio','Roma'],['Monaco','Lyon','Marseille'],['Parma','AC Milan','Roma']],
      [['FC Barcelona','Valencia','Sevilla'],['Real Madrid','Atlético Madrid','Villarreal'],['Fenerbahçe','Beşiktaş','Trabzonspor'],['Fenerbahçe','Inter','Valencia']],
      [['Cruzeiro','Santos FC','Grêmio'],['Coritiba','Palmeiras','Flamengo'],['Galatasaray','Beşiktaş','Trabzonspor'],['Cruzeiro','Palmeiras','Santos FC']],
      [['Real Madrid','Valencia','Sevilla'],['Benfica','Sporting CP','Braga'],['Fenerbahçe','Galatasaray','Trabzonspor'],['Başakşehir','Galatasaray','Fenerbahçe']],
      [['Beşiktaş','Bursaspor','Samsunspor'],['Rizespor','Samsunspor','Orduspor'],['Fenerbahçe','Beşiktaş','Başakşehir'],['Paris Saint-Germain','Lyon','Monaco']]]
    hints=[
      ['Altyapı dönemini değil, ilk profesyonel A takımını düşün.','İsveç’te düzenlenen turnuvayı hatırla.','Güney Amerika kupası ile Dünya Kupası yıllarını ayır.','Kulüp yolculuğunu millî takım turnuvalarıyla karıştırma.'],
      ['Buenos Aires’teki ilk A takım dönemini düşün.','İlk Avrupa transferini, daha sonraki İtalya yıllarından ayır.','Napoli’deki ilk lig kupasını, ikinci şampiyonluktan ayır.','İlk İtalya dönemine ulaştığında rotayı bitir; sonraki dönüşleri ekleme.'],
      ['Avrupa öncesindeki Brezilya A takımını ara.','İspanya öncesindeki Hollanda dönemini düşün.','1997 yazındaki İtalya transferini, sonraki İtalya dönüşünden ayır.','İlk Madrid dönemine kadar olan kulüpleri seç ve sırala.'],
      ['Genç kalecinin 1990’lardaki A takım dönemini düşün.','2001’deki transfer ile 2019’daki geri dönüşü ayır.','Bir sezonluk Fransa deneyimine odaklan.','Son kariyer durağını değil, Fransa’dan hemen sonraki dönüşü ara.'],
      ['Romanya’dan sonraki ilk ülkesini ve transfer yılını düşün.','1994 Dünya Kupası sonrasındaki iki sezonu hatırla.','Futbolcu olarak geldiği kulübü düşün; teknik direktörlük dönemlerini ayır.','Verilen dört durağı ilk katıldığı yıllara göre sırala.'],
      ['1990’lardaki ilk A takım dönemini düşün.','Türkiye transferinden hemen önceki sezonu ara.','2004 yazındaki ilk Türkiye transferini düşün.','Kariyer başlangıcı ile son dönem arasındaki bağlantıyı hatırla.'],
      ['2003 yazındaki İspanya transferini düşün.','İlk Türkiye döneminden önceki Portekiz dönüşüne odaklan.','İlk İstanbul transferini ikinci gelişinden ayır.','2019 yazındaki İstanbul içi transferi hatırla.'],
      ['İlk profesyonel A takım ile ilk büyük transfer aynı durak değil.','2010 yılındaki kulüp değişimine odaklan.','2012 yazındaki transferi, daha sonraki geri dönüşlerle karıştırma.','Takvim yılını değil, tamamlanan lig sezonunu düşün.']]
    questions=json.loads((HERE/'journey_questions.json').read_text())
    for k,(id,name,pid) in enumerate(people):
      j=dict(id=id,name=name,playerId=pid,expansion=PACK,rewardPolicy='mode_default',tasks=[])
      for i,q in enumerate(questions[k]):
        a=q['answer'];typ='clubChoice';answers=[a]
        if ' → ' in a:
          typ='timeline';answers=a.split(' → ')
        elif k==0 and i==2:typ='multiChoice';answers=['1962','1963']
        elif (k,i) in [(0,1),(1,2)]:typ='eraChoice'
        src=[q['source']]+(['S33'] if k==5 else [])
        t=task(f'{id}_v2_{i+1}',q['prompt'],answers,wrongs[k][i],hints[k][i],src,'order' if typ=='timeline' else 'single')
        t.update(type=typ,title=q['title'],introNarrative=f'{name} kariyerinin {i+1}. sayfasında. {q["title"]} başlığındaki dönemin izini sür; kulüp ve millî takım hikâyelerini ayrı düşün.',serverValidated=True)
        t['explanation']=t['result']['story']; t['options']=[dict(key=o['id'],label=o['label']) for o in t['options']]
        j['tasks'].append(t)
      pj['journeys'].append(j)
    ucl=[]
    for n,date,home,away,homeid,awayid,typ,q,a,w,score,src in [
      (35,'1994-05-18','AC Milan','Barcelona',5,131,'hero','1994 Atina finalinde Milan’ın ilk iki golünü hangi futbolcu attı?','Daniele Massaro',['Dejan Savićević','Marcel Desailly','Zvonimir Boban'],'4-0','S12'),
      (36,'1986-05-07','Steaua Bükreş','Barcelona',None,131,'hero','1986 Avrupa Kupası finali penaltı serisinde Barcelona’nın dört vuruşunu da kurtaran kaleci kimdi?','Helmuth Duckadam',['Silviu Lung','Dumitru Stângaciu','Andoni Zubizarreta'],'0-0','S13'),
      (37,'2023-06-10','Manchester City','Inter',281,46,'goal','Manchester City’ye ilk Şampiyonlar Ligi şampiyonluğunu getiren final golünü kim attı?','Rodri',['İlkay Gündoğan','Bernardo Silva','Erling Haaland'],'1-0','S14')]:
      t=task(f'UCL-{n}',q,[a],w,'Sorudaki finali ve oyuncunun o karşılaşmadaki rolünü düşün.',[src]);t.update(number=n,date=date,season=f'{int(date[:4])-1}/{date[:4]}',home={'id':homeid,'name':home},away={'id':awayid,'name':away},type=typ,title=f'{home} – {away}',round='Final',competition='Avrupa Şampiyon Kulüpler Kupası' if n==36 else 'UEFA Şampiyonlar Ligi',clock='Final gecesi',intro='İki kulüp, tek final. Karşılaşmanın belirleyici anını futbol hafızandan bul.')
      t['result'].update(score=score,penalties=[2,0] if n==36 else None,duration=120 if n==36 else 90,events=[{'label':'Rodri','minute':'68'}] if n==37 else [])
      ucl.append(t)
    tn=[]
    specs=[('1959 Millî Lig’in Doğuşu','1959',['Şampiyonluk'],[
      ('season','Türkiye 1. Futbol Ligi’nin 1959’daki ilk şampiyonu hangi kulüptü?','Fenerbahçe',['Galatasaray','Beşiktaş','Göztepe'],'İlk ulusal lig sezonunun iki ayaklı finalini düşün.','S15'),
      ('season','1959 iki ayaklı Millî Lig finalinin ikinci maçı kaç kaç bitti?','Fenerbahçe 4-0 Galatasaray',['Fenerbahçe 3-0 Galatasaray','Fenerbahçe 2-0 Galatasaray','Fenerbahçe 4-1 Galatasaray'],'İlk karşılaşmanın sonucunu değil, rövanşı ara.','S15')]),
      ('Metin Oktay ve Lefter Dönemi','1950’ler–1960’lar',['Şampiyonluk'],[
      ('legend','1959’daki ilk Millî Lig sezonunun gol kralı kimdi?','Metin Oktay',['Lefter Küçükandonyadis','Can Bartu','Şeref Has'],'Kulüp şampiyonluğu ile bireysel gol krallığını ayır.','S16'),
      ('season','Lefter Küçükandonyadis, Türkiye’de en çok hangi kulüple özdeşleşti?','Fenerbahçe',['Galatasaray','Beşiktaş','Vefa'],'İtalya ve Fransa yıllarını değil, Türkiye’deki uzun dönemini düşün.','S28')]),
      ('Eskişehirspor’un Anadolu Yükselişi','1970/71',['Anadolu'],[
      ('route','Eskişehirspor 1970/71 Türkiye Kupası finalinde hangi rakibini geçti?','Bursaspor',['Galatasaray','Fenerbahçe','Altay'],'Lig tablosunu değil, iki ayaklı kupa finalini düşün.','S17'),
      ('season','Eskişehirspor 1970/71 Cumhurbaşkanlığı Kupası’nı hangi rakibine karşı kazandı?','Galatasaray',['Fenerbahçe','Beşiktaş','Bursaspor'],'Türkiye Kupası finali ile sezonun diğer kupa maçını ayır.','S18')])]
    for n,(title,era,cats,ts) in enumerate(specs,13):
      c=dict(id=f'TN-{n}',title=title,era=era,card=era,categories=cats,intro='Türkiye futbol tarihinin bu sayfasında sezonları, kişileri ve kupaları ayrı izlerle keşfet.',expansion=PACK,tasks=[])
      for i,(kind,q,a,w,h,s) in enumerate(ts,1):
        t=task(f'TN-{n}-{i:02}',q,[a],w,h,[s]);t.update(chapterId=c['id'],mechanic=kind,question=q,serverValidated=True,slots=['Final rakibi'] if kind=='route' else [],role='',strongHint=h,explanation=t['result']['story'],sources=t['result']['sources']); c['tasks'].append(t)
      tn.append(c)
    ig=[]
    specs=[(41,1,'1970-06-21','Dünya Kupası 1970','Brezilya','İtalya','xi','1970 Dünya Kupası finalinde Brezilya’nın ilk 11 kalecisi kimdi?',['Félix'],['Ado','Leão','Gilmar'],'Maç kadrosundaki yedekleri değil, başlangıç kalecisini ara.',['S19','S34'],'4-1'),
      (42,3,'2019-02-01','Asya Kupası 2019','Katar','Japonya','route','Katar’ın 2019 Asya Kupası yarı final ve final rakiplerini sırala.',['Birleşik Arap Emirlikleri','Japonya'],['Güney Kore','Irak','İran'],'Çeyrek finali atla; son iki turun rakiplerini yerleştir.',['S20','S32'],'3-1'),
      (43,3,'2011-06-25','Gold Cup 2011','Meksika','ABD','timeline','Meksika’nın 2-0’dan döndüğü 2011 Gold Cup finalindeki dört golcüyü sırala.',['Pablo Barrera · ilk golü','Andrés Guardado','Pablo Barrera · ikinci golü','Giovani dos Santos'],[],'Aynı oyuncunun iki golü ayrı karttır; takımın gol sırasını kur.',['S21'],'4-2'),
      (44,4,'2022-12-01','Dünya Kupası 2022','Japonya','İspanya','critical','2022 Dünya Kupası’nda Japonya’nın İspanya karşısındaki galibiyet golünü kim attı?',['Ao Tanaka'],['Ritsu Dōan','Kaoru Mitoma','Daizen Maeda'],'Beraberlik golü ile öne geçiren golü birbirinden ayır.',['S22'],'2-1')]
    for n,ch,date,comp,home,away,typ,q,a,w,h,src,score in specs:
      t=task(f'IG-{n}',q,a,w,h,src,'order' if typ in ['timeline','route'] else 'single');t.update(number=n,chapterId=ch,date=date,competition=comp,round='Grup' if n==44 else 'Final',home={'id':home,'name':home},away={'id':away,'name':away},type=typ,title=f'{home} – {away}',intro='Millî formalarla yazılan bir hatıra. Bu karşılaşmanın izini sür ve sorulan anı keşfet.',clock='Millî takım arşivi',difficulty='Orta')
      t['result'].update(score=score,scoreFT=score,scoreET=None,penalties=None,duration=90,events=[])
      if n==41:t['lineup']={'club':'Brezilya','formation':'4-3-3','rows':[['?'],['Carlos Alberto','Brito','Piazza','Everaldo'],['Clodoaldo','Gérson','Rivellino'],['Jairzinho','Tostão','Pelé']]}
      if n==42:t['slots']=['Yarı final','Final']
      if n==43:t['result']['events']=[{'label':l,'minute':m} for l,m in zip(a,['29','36','50','76'])]
      ig.append(t)
    ds=[];dt=[]
    specs=[('Boca Juniors','2000–2003','Güney Amerika’nın izi',[
      ('trophies','multi','Boca Juniors’ın 2000–2003 arasında Libertadores’i kazandığı üç yılı seç.',['2000','2001','2003'],['1998','1999','2002'],'Dönemin başlangıç ve bitiş sınırlarını koru.',['S23','S29']),
      ('squad','single','Boca Juniors’ın 2000 ve 2003 Libertadores zaferlerinde görev alan ünlü teknik direktör kimdi?',['Carlos Bianchi'],['Marcelo Bielsa','Alfio Basile','Ramón Díaz'],'Oyuncuyu değil, dönemin teknik direktörünü ara.',['S29'])]),
      ('Al Ahly','2005–2008','Kahire’den kıtaya',[
      ('trophies','multi','Al Ahly’nin 2005–2008 döneminde CAF Şampiyonlar Ligi’ni kazandığı üç yılı seç.',['2005','2006','2008'],['2004','2007','2009'],'Finale katılmak ve kupayı kazanmak farklıdır.',['S24']),
      ('route','single','Al Ahly’nin 2006 CAF Şampiyonlar Ligi finalindeki rakibi hangi kulüptü?',['CS Sfaxien'],['Étoile du Sahel','Coton Sport','Espérance'],'İki ayaklı finalin aynı sezon içindeki rakibini düşün.',['S24'])]),
      ('Galatasaray','1996–2000','İstanbul’da süreklilik',[
      ('records','single','Galatasaray, 1996/97–1999/2000 döneminde lig şampiyonluğunu üst üste kaç kez kazandı?',['4'],['2','3','5'],'Başlangıç ve bitiş sezonları da hesaba katılır.',['S25']),
      ('tactics','single','Bu dört lig şampiyonluğunda Galatasaray’ın teknik direktörü kimdi?',['Fatih Terim'],['Mustafa Denizli','Gheorghe Hagi','Mircea Lucescu'],'Oyunculuk rolü ile teknik direktörlük görevini ayır.',['S25'])])]
    for n,(club,period,title,ts) in enumerate(specs,17):
      d=dict(id=f'DY-{n}',number=n,chapterId=2,club=club,period=period,title=title,intro='Bir kulübün yıllara yayılan başarısını kupalar ve teknik yönetim üzerinden keşfet.',taskIds=[f'DY-{n}-01',f'DY-{n}-02'],expansion=PACK,story=f'{club} · {period}: iki tarihsel iz tamamlandı.');ds.append(d)
      for i,(kind,interaction,q,a,w,h,src) in enumerate(ts,1):
        t=task(d['taskIds'][i-1],q,a,w,h,src);t.update(number=(n-1)*2+i,dynastyId=d['id'],stage=i,mechanic=kind,interaction=interaction,title='Yükseliş' if i==1 else 'Zirve',slots=[]);dt.append(t)
    private=dict(version=1,id=PACK,rewardPolicy='mode_default',journey=pj,ucl=ucl,nostalgia=tn,international=ig,dynasties=ds,dynastyTasks=dt)
    public=copy.deepcopy(private)
    def redact(v):
      if isinstance(v,dict):
        for k in ['answerKeys','result','explanation','strongHint','sources','story']:v.pop(k,None)
        for x in v.values():redact(x)
      elif isinstance(v,list):
        for x in v:redact(x)
    redact(public)
    return private,public
if __name__=='__main__':
    private,public=build()
    for path,data in [('functions/config/five_mode_expansion.json',private),('assets/data/five_mode_expansion.json',public)]:
      (ROOT/path).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('Built 51 private/public expansion tasks; legacy assets untouched.')
