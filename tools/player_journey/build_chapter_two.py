"""Chapter 2, adapted from the user's second eight-player presentation."""
from narratives import enrich
import json
from pathlib import Path
from pack_helpers import P, club, mates, era, timeline

ROOT = Path(__file__).resolve().parents[2]
S = {
 'vardy': 'https://www.lcfc.com/media-article/Leicester-City%27s-Non-League-Links',
 'leicester': 'https://www.lcfc.com/history-honours-men-premierleague',
 'maddison': 'https://www.lcfc.com/media-article/Leicester-City-Confirm-Transfer-Of-James-Maddison-To-Tottenham-Hotspur',
 'kante': 'https://www.premierleague.com/ar/news/3546919',
 'chelsea': 'https://www.chelseafc.com/en/ngolo-kante',
 'hazard': 'https://www.chelseafc.com/en/news/article/eden-hazard-s-career-at-chelsea',
 'drogba': 'https://www.didierdrogba.com/fr/biographie/index.asp',
 'chelsea08': 'https://www.chelseafc.com/en/news/article/every-penalty-shoot-out-involving-chelsea',
 'atleti': 'https://www.uefa.com/newsfiles/uefacup/2012/md15_1_fs.pdf',
 'arda': 'https://players.fcbarcelona.com/en/player/2427-arda-turan-arda-turan',
 'ozil': 'https://www.arsenal.com/news/german-international-ozil-joins-arsenal-aFEWj7I0BzHD',
 'arsenal': 'https://www.arsenal.com/feature/alexis-a7n2w2p6zIM6',
 'eriksen': 'https://www.manutd.com/en/news/christian-eriksen-career-to-date-after-joining-man-utd-july-2022',
 'final19': 'https://www.uefa.com/newsfiles/UCL/2019/2025486_LU.pdf',
 'inter': 'https://www.inter.it/en/news/2021-05-02-inter-squad-champions-of-italy-2021',
 'salah': 'https://www.liverpoolfc.com/news/media-watch/266516-liverpool-set-to-seal-35m-mohamed-salah-transfer',
 'falcao': 'https://www.uefa.com/uefachampionsleague/news/0223-0e912b5e0804-1826758cbeb8-1000--falcao-s-proven-track-record-in-uefa-competition/',
 'monaco': 'https://ligue1.com/en/articles/l1_article_246-copa-america-stars-radamel-falcao-colombia',
}
journeys = []
def add(id, key, tasks, sources):
 for i, t in enumerate(tasks): t['id'] = f'{id}_v2_{i+1}'
 journeys.append(dict(id=id, name=P[key][1], playerId=P[key][0], tasks=tasks, sources=[S[s] for s in sources]))

add('vardy', 'Vardy', [
 club('Bir üst basamak', 'Vardy, 2012’de Leicester City’ye transfer olmadan hemen önce hangi kulüpte oynuyordu?', ['Fleetwood Town','Sheffield Wednesday','Nottingham Forest','Derby County'], 'Alt liglerde yükselen Vardy, Fleetwood Town’daki golcü sezonunun ardından 2012’de Leicester City’ye geçti.', 'Altyapısını değil, transferden hemen önce A takımında oynadığı kulübü düşün.'),
 mates('2015/16 sezonunda Leicester City ile lig şampiyonu olan Vardy’nin takım arkadaşlarından 2 isim seç.', ['Mahrez','Schmeichel','Drinkwater'], ['Maddison','Haaland','Kroos'], 'Riyad Mahrez, Kasper Schmeichel ve Danny Drinkwater o şampiyonluk kadrosundaydı. James Maddison kulübe 2018’de katıldı.'),
 era('2018/19–2022/23 sezonlarında Leicester City’de Vardy ile oynamış futbolcuyu seç.', 'Maddison', ['Kante','Hazard','Kane'], 'James Maddison 2018–2023 arasında Vardy ile Leicester forması giydi. Kanté ise 2016’da ayrılmıştı.'),
 timeline('Vardy’nin aşağıdaki erken kariyer duraklarını sırala. Rota, 2012’deki transferinde sona eriyor.', ['Stocksbridge Park Steels','FC Halifax Town','Fleetwood Town','Leicester City'], 'Vardy alt liglerde Stocksbridge, Halifax ve Fleetwood basamaklarını geçti. 2012’de Leicester’a katıldı ve 2015/16 şampiyonluğunun başrollerinden biri oldu.'),
], ['vardy','leicester','maddison'])

add('kante', 'Kante', [
 club('İlk sıçrama', 'Kanté, 2015’te Premier League’e transfer olmadan hemen önce hangi Fransız kulübünde oynuyordu?', ['Caen','Lille','Rennes','Nantes'], 'Kanté, Boulogne’un ardından Caen’de oynadı. 2015 yazında Leicester City’ye transfer oldu.', 'İngiltere’ye taşınmadan önceki son Fransız kulübünü düşün.'),
 mates('2015/16 Leicester City sezonunda Kanté ile aynı takımda oynamış 2 futbolcuyu seç.', ['Vardy','Mahrez','Schmeichel'], ['Maddison','Bellingham','Benzema'], 'Jamie Vardy, Riyad Mahrez ve Kasper Schmeichel, Kanté ile Leicester’ın şampiyonluğunu paylaştı.'),
 era('2016/17–2018/19 sezonlarında Chelsea’de Kanté ile oynamış futbolcuyu seç.', 'Hazard', ['Lampard','Drogba','Kroos'], 'Eden Hazard ve Kanté bu üç sezonda Chelsea’de birlikte oynadı. Lampard ve Drogba, Kanté gelmeden önce ayrılmıştı.'),
 club('Yeni sayfa', 'Caen → Leicester City → Chelsea → ?\nKanté’nin 2023 yazındaki transferiyle rotayı tamamla.', ['Al-Ittihad','Al-Nassr','Al-Hilal','Al-Ahli'], 'Kanté, Chelsea’deki yedi sezonun ardından 2023 yazında Al-Ittihad’a katıldı. Bu rota yalnızca o transfere kadar uzanıyor.', '2023 yazındaki Suudi Arabistan transferini hatırla.', True),
], ['leicester','kante','chelsea','hazard'])

add('drogba', 'Drogba', [
 club('Eksik basamak', 'Le Mans → ? → Olympique Marseille\nDrogba’nın 2002–2003 dönemindeki eksik kulübünü seç.', ['Guingamp','Bordeaux','Lille','AS Monaco'], 'Drogba, Le Mans’tan sonra Guingamp’ta forma giydi. Buradaki çıkışı 2003’te Marseille’e transferinin önünü açtı.', 'Fransa’daki yükselişinin ara durağını düşün.', True),
 club('Büyük sıçrama', 'Drogba, 2004’te Chelsea’ye transfer olmadan hemen önce hangi Fransız kulübünde oynuyordu?', ['Olympique Marseille','Olympique Lyon','Paris Saint-Germain','Rennes'], 'Drogba, Marseille’de geçirdiği 2003/04 sezonunun ardından Chelsea’ye transfer oldu.', 'İngiltere’ye geçmeden önceki son sezonunu hatırla.'),
 mates('2006–2012 arasında Chelsea’de Drogba ile oynamış 2 futbolcuyu seç.', ['Lampard','Terry','Essien'], ['Kante','Haaland','Bellingham'], 'Frank Lampard, John Terry ve Michael Essien bu dönemde Drogba’nın Chelsea takım arkadaşlarıydı.'),
 timeline('Drogba’nın 2003’ten 2013’teki İstanbul transferine kadar bu dört durağını sırala.', ['Olympique Marseille','Chelsea','Shanghai Shenhua','Galatasaray'], 'Drogba, Marseille ve Chelsea’nin ardından 2012’de Shanghai Shenhua’ya, 2013’te Galatasaray’a geçti. Çin dönemi, Londra ile İstanbul arasındaki duraktır.'),
], ['drogba','chelsea08'])

add('arda_turan', 'Arda', [
 club('İlk bağ', 'Arda Turan, altyapısından yetişip A takım kaptanlığına yükseldiği hangi kulüpte oynadı?', ['Galatasaray','Fenerbahçe','Beşiktaş','Trabzonspor'], 'Arda, Galatasaray altyapısından yetişti ve A takım kaptanlığına kadar yükseldi. Arada 2006’da Manisaspor’da kiralık oynadı.', 'Yetiştiği kulüp ile kısa kiralık dönemini birbirinden ayır.'),
 mates('2011–2015 Atlético Madrid döneminde Arda ile oynamış 2 futbolcuyu seç.', ['Koke','Godin','Falcao'], ['Haaland','Kroos','Bellingham'], 'Koke, Diego Godín ve Radamel Falcao bu aralıkta Arda ile Atlético Madrid forması giydi.'),
 era('2016–2017 arasında Barcelona A takımında Arda ile oynamış futbolcuyu seç.', 'Messi', ['Xavi','Pedri','Lewandowski'], 'Lionel Messi bu dönemde Arda ile oynadı. Xavi 2015’te ayrılmıştı; Pedri ve Lewandowski daha sonra geldi.'),
 timeline('2006 yazındaki kiralık dönüşünden 2020’deki dönüşüne kadar Arda’nın bu duraklarını sırala. Aynı kulüp iki kez yer alıyor.', ['Galatasaray','Atlético Madrid','FC Barcelona','Başakşehir','Galatasaray'], '2006’da Galatasaray’a dönen Arda, Atlético ve Barcelona’nın ardından Başakşehir’de kiralık oynadı. 2020’de tekrar Galatasaray’a katıldı. Daha önceki Manisaspor dönemi bu zaman aralığının dışındadır.'),
], ['arda','atleti'])

add('ozil', 'Ozil', [
 club('Yıldızın doğuşu', 'Özil, 2010’da Real Madrid’e transfer olmadan hemen önce hangi Bundesliga kulübünde oynuyordu?', ['Werder Bremen','Schalke 04','Borussia Dortmund','Bayer Leverkusen'], 'Özil, Schalke 04’ten Werder Bremen’e geçti. 2010’daki bir sonraki durağı Real Madrid oldu.', 'İspanya’ya geçmeden önceki son Alman kulübünü düşün.'),
 mates('2010–2013 Real Madrid döneminde Özil ile oynamış 2 futbolcuyu seç.', ['Ronaldo','Ramos','Benzema'], ['Kroos','Bellingham','Vinicius'], 'Cristiano Ronaldo, Sergio Ramos ve Karim Benzema bu dönemde Özil ile Real Madrid forması giydi.'),
 era('2014/15–2016/17 sezonlarında Arsenal’de Özil ile oynamış futbolcuyu seç.', 'Alexis', ['Hazard','Kane','Bellingham'], 'Alexis Sánchez bu sezonlarda Özil’in Arsenal takım arkadaşıydı.',),
 timeline('Özil’in A takım kariyerini 2021’deki Türkiye transferine kadar sırala.', ['Schalke 04','Werder Bremen','Real Madrid','Arsenal','Fenerbahçe'], 'Bu rota Schalke, Bremen, Real Madrid, Arsenal ve 2021’de Fenerbahçe şeklindedir. Kariyerinin sonraki Başakşehir dönemi bu sorunun zaman sınırının dışındadır.'),
], ['ozil','arsenal'])

add('eriksen', 'Eriksen', [
 club('Yeni okul', 'Eriksen, 2013’te Tottenham’a gelmeden önce hangi Hollanda kulübünün A takımında oynuyordu?', ['Ajax','PSV','Feyenoord','AZ Alkmaar'], 'Eriksen, Ajax A takımında kendini gösterdikten sonra 2013’te Tottenham’a geçti.', 'İngiltere’den önceki Hollanda yıllarını düşün.'),
 mates('2013–2020 Tottenham döneminde Eriksen ile oynamış 2 futbolcuyu seç.', ['Kane','Son','Lloris'], ['Modric','Bellingham','Kroos'], 'Harry Kane, Heung-min Son ve Hugo Lloris, Eriksen’in Tottenham takım arkadaşlarıydı. Modrić 2012’de ayrılmıştı.'),
 era('2020/21 sezonunda Inter’de Eriksen ile lig şampiyonu olmuş futbolcuyu seç.', 'Lukaku', ['Ibrahimovic','Kane','Ronaldo'], 'Romelu Lukaku ve Eriksen, Inter’in 2020/21 lig şampiyonluğu kadrosundaydı.'),
 club('Dönüş yolu', 'Ajax → Tottenham → Inter → Brentford → ?\nEriksen’in 2022 yazındaki transferiyle rotayı tamamla.', ['Manchester United','Manchester City','Newcastle United','Aston Villa'], 'Eriksen, Brentford’da sahalara döndükten sonra 2022 yazında Manchester United’a katıldı. Rota o transferde sona eriyor.', '2022 yazında katıldığı İngiliz kulübünü düşün.', True),
], ['eriksen','final19','inter'])

add('salah', 'Salah', [
 club('Avrupa’ya açılan kapı', 'Salah, 2012’de Avrupa’daki ilk kulüp deneyimi için hangi takıma katıldı?', ['FC Basel','Young Boys','FC Zürich','Grasshoppers'], 'Salah, Mısır’daki başlangıcının ardından 2012’de Basel’e geçti. Burada gösterdiği performans onu Chelsea’ye taşıdı.', 'İsviçre’de başlayan Avrupa kariyerini düşün.'),
 club('Eksik durak', 'Chelsea → Fiorentina → ? → Liverpool\nSalah’ın 2015–2017 arasında forma giydiği kulübü seç.', ['AS Roma','AC Milan','Napoli','Inter'], 'Salah, Fiorentina’nın ardından Roma’da oynadı ve 2017’de Liverpool’a transfer oldu.', 'İtalya’da geçirdiği ikinci dönemi düşün.', True),
 mates('2017/18–2021/22 sezonlarında Liverpool’da Salah ile oynamış 2 futbolcuyu seç.', ['Mane','Firmino','Henderson'], ['Kane','Hazard','Kroos'], 'Sadio Mané, Roberto Firmino ve Jordan Henderson bu sezonlarda Salah ile Liverpool forması giydi.'),
 timeline('Salah’ın Avrupa’ya ilk gelişinden 2017’deki transferine kadar forma giydiği kulüpleri sırala. Kiralık dönemler dahil.', ['FC Basel','Chelsea','Fiorentina','AS Roma','Liverpool'], 'Salah’ın Avrupa rotası Basel, Chelsea, Fiorentina, Roma ve 2017’de Liverpool sırasını izledi. İtalya’da yeniden yükselip İngiltere’ye döndü.'),
], ['salah','final19'])

add('falcao', 'Falcao', [
 club('Okyanusun ötesi', 'Falcao, River Plate’ten 2009’da ayrılıp Avrupa’da ilk olarak hangi kulübe katıldı?', ['FC Porto','Benfica','Sporting CP','SC Braga'], 'Falcao’nun ilk Avrupa durağı Porto oldu. 2009–2011 arasında burada oynayıp golcülüğünü Avrupa sahnesine taşıdı.', 'Portekiz’deki ilk dönemini düşün.'),
 mates('2011–2013 Atlético Madrid döneminde Falcao ile oynamış 2 futbolcuyu seç.', ['Arda','Koke','Godin'], ['Bellingham','Kroos','Haaland'], 'Arda Turan, Koke ve Diego Godín bu yıllarda Falcao’nun Atlético Madrid takım arkadaşlarıydı.'),
 club('İlk İngiltere durağı', 'Porto → Atlético Madrid → Monaco → ?\nFalcao’nun 2014/15 sezonundaki ilk Premier League kiralık durağını seç.', ['Manchester United','Chelsea','Arsenal','Liverpool'], 'Falcao, 2014/15 sezonunda Manchester United’a kiralandı. Chelsea’deki kiralık sezonu 2015/16’ydı; bu yüzden burada doğru cevap Chelsea değil.', 'İngiltere’deki iki kiralık döneminden önce geleni düşün.', True),
 timeline('Bu beş kulübü Falcao’nun ilk katılma sırasına koy. İngiltere’deki kiralık dönemler bu kartlar arasında yok; rota 2019’da bitiyor.', ['River Plate','FC Porto','Atlético Madrid','AS Monaco','Galatasaray'], 'Seçilen durakların sırası River, Porto, Atlético, Monaco ve Galatasaray’dır. Arada United ve Chelsea’de kiralık oynayıp Monaco’ya döndü; 2019’da Galatasaray’a geçti.'),
], ['falcao','monaco','atleti'])

enrich(journeys)
out = ROOT / 'assets/data/player_journey_chapter_two.json'
out.write_text(json.dumps(dict(version=2, chapterId='chapter_2_underdogs', journeys=journeys), ensure_ascii=False, indent=2)+'\n')
print(f'Wrote {len(journeys)} journeys / {sum(len(j["tasks"]) for j in journeys)} tasks')
