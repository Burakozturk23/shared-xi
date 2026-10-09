"""Shared task templates and reviewed canonical player identities."""
P = {
 'Henry':(3207,'Thierry Henry'), 'Gerrard':(3109,'Steven Gerrard'),
 'Adriano':(5876,'Adriano'), 'Mbappe':(342229,'Kylian Mbappé'),
 'Zanetti':(4000000068,'Javier Zanetti'), 'Cambiasso':(7520,'Esteban Cambiasso'),
 'Bergkamp':(4000000031,'Dennis Bergkamp'), 'Vieira':(4000000032,'Patrick Vieira'),
 'Ljungberg':(3134,'Freddie Ljungberg'), 'XabiAlonso':(7476,'Xabi Alonso'),
 'Dudek':(3209,'Jerzy Dudek'), 'Kewell':(3241,'Harry Kewell'),
 'DeBruyne':(88755,'Kevin De Bruyne'), 'Neuer':(17259,'Manuel Neuer'),
 'Neymar':(68290,'Neymar'), 'Verratti':(102558,'Marco Verratti'),
 'Cavani':(48280,'Edinson Cavani'), 'Matuidi':(33923,'Blaise Matuidi'),
 'Perisic':(42460,'Ivan Perišić'), 'DavidSilva':(35518,'David Silva'),
 'Aguero':(26399,'Sergio Agüero'), 'Sterling':(134425,'Raheem Sterling'),
 'Rodri':(357565,'Rodri'), 'Sane':(192565,'Leroy Sané'),
 'Muller':(58358,'Thomas Müller'), 'Robben':(4360,'Arjen Robben'),
 'Ribery':(22068,'Franck Ribéry'), 'Coman':(243714,'Kingsley Coman'),
 'Reus':(35207,'Marco Reus'), 'Brandt':(187492,'Julian Brandt'),
 'Sancho':(401173,'Jadon Sancho'), 'Lahm':(2219,'Philipp Lahm'),
 'Boateng':(26485,'Jérôme Boateng'), 'Kimmich':(161056,'Joshua Kimmich'),
 'Goretzka':(153084,'Leon Goretzka'), 'Musiala':(580195,'Jamal Musiala'),
 'Vardy':(197838,'Jamie Vardy'), 'Kante':(225083,"N'Golo Kanté"),
 'Drogba':(3924,'Didier Drogba'), 'Arda':(4000000018,'Arda Turan'),
 'Ozil':(35664,'Mesut Özil'), 'Eriksen':(69633,'Christian Eriksen'),
 'Salah':(148455,'Mohamed Salah'), 'Falcao':(39152,'Radamel Falcao'),
 'Mahrez':(171424,'Riyad Mahrez'), 'Schmeichel':(16911,'Kasper Schmeichel'),
 'Drinkwater':(73491,'Danny Drinkwater'), 'Maddison':(294057,'James Maddison'),
 'Hazard':(50202,'Eden Hazard'), 'Lampard':(3163,'Frank Lampard'),
 'Terry':(3160,'John Terry'), 'Essien':(5588,'Michael Essien'),
 'Koke':(74229,'Koke'), 'Godin':(54928,'Diego Godín'),
 'Lloris':(17965,'Hugo Lloris'), 'Alexis':(40433,'Alexis Sánchez'),
 'Lukaku':(96341,'Romelu Lukaku'), 'Mane':(200512,'Sadio Mané'),
 'Firmino':(131789,'Roberto Firmino'), 'Henderson':(61651,'Jordan Henderson'),
 'Messi':(28003,'Lionel Messi'), 'Ronaldo':(8198,'Cristiano Ronaldo'),
 'Ronaldinho':(3373,'Ronaldinho'), 'Modric':(27992,'Luka Modrić'),
 'Zidane':(3111,'Zinédine Zidane'), 'Kaka':(4000000028,'Kaká'),
 'Benzema':(18922,'Karim Benzema'), 'Maldini':(4000000024,'Paolo Maldini'),
 'Xavi':(7607,'Xavi'), 'Iniesta':(7600,'Andrés Iniesta'),
 'Busquets':(65230,'Sergio Busquets'), 'Puyol':(4000000027,'Carles Puyol'),
 'Rooney':(3332,'Wayne Rooney'), 'Scholes':(4000000026,'Paul Scholes'),
 'Giggs':(4000000059,'Ryan Giggs'), 'Rio':(4000000069,'Rio Ferdinand'),
 'Heinze':(5555,'Gabriel Heinze'), 'Okocha':(3708,'Jay-Jay Okocha'),
 'Arteta':(7451,'Mikel Arteta'), 'Bale':(39381,'Gareth Bale'),
 'Lennon':(14221,'Aaron Lennon'), 'Defoe':(3875,'Jermain Defoe'),
 'VanDerVaart':(4192,'Rafael van der Vaart'), 'DelPiero':(4289,'Alessandro Del Piero'),
 'Deschamps':(4000000030,'Didier Deschamps'), 'Davids':(4000000055,'Edgar Davids'),
 'Inzaghi':(5821,'Filippo Inzaghi'), 'Seedorf':(4168,'Clarence Seedorf'),
 'Pirlo':(5817,'Andrea Pirlo'), 'Gattuso':(5813,'Gennaro Gattuso'),
 'Nesta':(4171,'Alessandro Nesta'), 'Gullit':(4000000042,'Ruud Gullit'),
 'Rijkaard':(4000000058,'Frank Rijkaard'), 'VanBasten':(4000000041,'Marco van Basten'),
 'Costacurta':(10055,'Alessandro Costacurta'), 'Casemiro':(16306,'Casemiro'),
 'Vinicius':(371998,'Vinicius Junior'), 'Valverde':(369081,'Federico Valverde'),
 'Suarez':(44352,'Luis Suárez'), 'Griezmann':(125781,'Antoine Griezmann'),
 'Dembele':(288230,'Ousmane Dembélé'), 'Pedri':(683840,'Pedri'),
 'Ramos':(25557,'Sergio Ramos'), 'Beckham':(4000000023,'David Beckham'),
 'Kroos':(31909,'Toni Kroos'), 'RobertoCarlos':(4000000029,'Roberto Carlos'),
 'Kane':(132098,'Harry Kane'), 'Son':(91845,'Heung-min Son'),
 'Bellingham':(581678,'Jude Bellingham'), 'Lewandowski':(38253,'Robert Lewandowski'),
 'Haaland':(418560,'Erling Haaland'), 'Ibrahimovic':(3455,'Zlatan Ibrahimović'),
}
def options(values, players=False):
 return [dict(key=f'o{i}',label=P[v][1],playerId=P[v][0]) if players else dict(key=f'o{i}',label=v) for i,v in enumerate(values)]
def task(kind, title, prompt, values, correct, explanation, hint, players=False):
 return dict(type=kind,title=title,prompt=prompt,options=options(values,players),answerKeys=[f'o{i}' for i in correct],requiredCount=2 if kind=='teammate' else len(values) if kind=='timeline' else 1,explanation=explanation,hint=hint)
def club(title,prompt,values,explanation,hint,missing=False):
 return task('missingClub' if missing else 'clubChoice',title,prompt,values,[0],explanation,hint)
def mates(prompt,correct,wrong,explanation):
 return task('teammate','Ortak forma',prompt,correct+wrong,list(range(len(correct))),explanation,'Aynı kulüp yetmez. Sorudaki yıllarda birlikte oynamış olmaları gerekiyor.',True)
def era(prompt,correct,wrong,explanation):
 return task('eraChoice','Dönem hafızası',prompt,[correct]+wrong,[0],explanation,'Oyuncuların kulübe geliş ve ayrılış dönemlerini karşılaştır.',True)
def timeline(prompt,values,explanation):
 return task('timeline','Kariyer rotası',prompt,values,list(range(len(values))),explanation,'Bir kulübe dönüş varsa aynı kulüp rotada yeniden yer alır.')
