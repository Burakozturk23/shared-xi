/// Quiz / Seri / Endless / Zincir için bilinen kulüp havuzu.
/// Veritabanı silinmez; sadece soru olarak bu id'ler seçilir.
/// Oyuncu eşleşmeleri hâlâ tüm DB üzerinden yapılır.
const List<int> chainClubPool = [
  // --- Premier League (20) ---
  11, // Arsenal FC
  631, // Chelsea FC
  31, // Liverpool FC
  281, // Manchester City
  985, // Manchester United
  148, // Tottenham Hotspur
  989, // AFC Bournemouth
  405, // Aston Villa
  1148, // Brentford FC
  1237, // Brighton & Hove Albion
  1132, // Burnley FC
  873, // Crystal Palace
  29, // Everton FC
  931, // Fulham FC
  399, // Leeds United
  762, // Newcastle United
  703, // Nottingham Forest
  289, // Sunderland AFC
  379, // West Ham United
  543, // Wolverhampton Wanderers
  // --- Championship (22) ---
  337, // Birmingham City
  164, // Blackburn Rovers
  698, // Bristol City
  358, // Charlton Athletic
  990, // Coventry City
  22, // Derby County
  3008, // Hull City
  677, // Ipswich Town
  1003, // Leicester City
  641, // Middlesbrough FC
  1028, // Millwall FC
  1123, // Norwich City
  988, // Oxford United
  1020, // Portsmouth FC
  466, // Preston North End
  1039, // Queens Park Rangers
  350, // Sheffield United
  1035, // Sheffield Wednesday
  180, // Southampton FC
  512, // Stoke City
  1010, // Watford FC
  984, // West Bromwich Albion
  // --- LaLiga (20) ---
  131, // FC Barcelona
  714, // RCD Espanyol Barcelona
  418, // Real Madrid
  621, // Athletic Bilbao
  13, // Atlético de Madrid
  331, // CA Osasuna
  940, // Celta de Vigo
  1108, // Deportivo Alavés
  1531, // Elche CF
  3709, // Getafe CF
  12321, // Girona FC
  3368, // Levante UD
  237, // RCD Mallorca
  367, // Rayo Vallecano
  150, // Real Betis Balompié
  2497, // Real Oviedo
  681, // Real Sociedad
  368, // Sevilla FC
  1049, // Valencia CF
  1050, // Villarreal CF
  // --- LaLiga2 (top) (12) ---
  2448, // Sporting Gijón
  8568, // AD Ceuta FC
  1532, // Albacete Balompié
  1536, // Burgos CF
  2502, // CD Castellón
  1244, // CD Leganés
  13222, // CD Mirandés
  4542, // Cultural Leonesa
  2687, // Cádiz CF
  993, // Córdoba CF
  897, // Deportivo de La Coruña
  16795, // Granada CF
  // --- Serie A (20) ---
  5, // AC Milan
  12, // AS Roma
  46, // Inter Milan
  506, // Juventus FC
  4172, // Pisa Sporting Club
  6195, // SSC Napoli
  430, // ACF Fiorentina
  800, // Atalanta BC
  1025, // Bologna FC 1909
  1390, // Cagliari Calcio
  1047, // Como 1907
  252, // Genoa CFC
  276, // Hellas Verona
  130, // Parma Calcio 1913
  398, // SS Lazio
  416, // Torino FC
  2239, // US Cremonese
  1005, // US Lecce
  6574, // US Sassuolo
  410, // Udinese Calcio
  // --- Bundesliga (18) ---
  27, // Bayern Munich
  16, // Borussia Dortmund
  2036, // 1.FC Heidenheim 1846
  3, // 1.FC Köln
  89, // 1.FC Union Berlin
  39, // 1.FSV Mainz 05
  15, // Bayer 04 Leverkusen
  18, // Borussia Mönchengladbach
  24, // Eintracht Frankfurt
  167, // FC Augsburg
  35, // FC St. Pauli
  41, // Hamburger SV
  23826, // RB Leipzig
  60, // SC Freiburg
  86, // SV Werder Bremen
  533, // TSG 1899 Hoffenheim
  79, // VfB Stuttgart
  82, // VfL Wolfsburg
  // --- 2. Bundesliga (top) (10) ---
  2, // 1.FC Kaiserslautern
  187, // 1.FC Magdeburg
  4, // 1.FC Nuremberg
  10, // Arminia Bielefeld
  23, // Eintracht Braunschweig
  33, // FC Schalke 04
  38, // Fortuna Düsseldorf
  42, // Hannover 96
  44, // Hertha BSC
  269, // Holstein Kiel
  // --- Ligue 1 (18) ---
  1041, // Olympique Lyon
  244, // Olympique Marseille
  290, // AJ Auxerre
  162, // AS Monaco
  1420, // Angers SCO
  1158, // FC Lorient
  347, // FC Metz
  995, // FC Nantes
  415, // FC Toulouse
  1082, // LOSC Lille
  738, // Le Havre AC
  417, // OGC Nice
  10004, // Paris FC
  583, // Paris Saint-Germain
  826, // RC Lens
  667, // RC Strasbourg Alsace
  3911, // Stade Brestois 29
  273, // Stade Rennais FC
  // --- Ligue 2 (top) (10) ---
  1159, // AS Nancy-Lorraine
  618, // AS Saint-Étienne
  1416, // Amiens SC
  3524, // Clermont Foot 63
  855, // EA Guingamp
  1095, // ESTAC Troyes
  30204, // FC Annecy
  1290, // Grenoble Foot 38
  1164, // Le Mans FC
  969, // Montpellier HSC
  // --- Liga Portugal (18) ---
  720, // FC Porto
  294, // SL Benfica
  336, // Sporting CP
  110302, // Avs Futebol
  982, // CD Nacional
  2423, // CD Santa Clara
  7179, // CD Tondela
  2431, // CF Estrela Amadora
  3268, // Casa Pia AC
  2521, // FC Alverca
  8024, // FC Arouca
  3329, // FC Famalicão
  1465, // GD Estoril Praia
  2424, // Gil Vicente FC
  979, // Moreirense FC
  2425, // Rio Ave FC
  1075, // SC Braga
  2420, // Vitória Guimarães SC
  // --- Eredivisie (18) ---
  610, // Ajax Amsterdam
  234, // Feyenoord Rotterdam
  383, // PSV Eindhoven
  1090, // AZ Alkmaar
  798, // Excelsior Rotterdam
  202, // FC Groningen
  200, // FC Utrecht
  724, // FC Volendam
  385, // Fortuna Sittard
  1435, // Go Ahead Eagles
  1304, // Heracles Almelo
  132, // NAC Breda
  467, // NEC Nijmegen
  1269, // PEC Zwolle
  306, // SC Heerenveen
  1434, // SC Telstar
  468, // Sparta Rotterdam
  317, // Twente Enschede FC
  // --- Süper Lig (18) ---
  114, // Besiktas JK
  36, // Fenerbahce
  141, // Galatasaray
  11282, // Alanyaspor
  589, // Antalyaspor
  6890, // Basaksehir FK
  126, // Caykur Rizespor
  7160, // Eyüpspor
  6646, // Fatih Karagümrük
  2832, // Gaziantep FK
  820, // Genclerbirligi Ankara
  1467, // Göztepe
  10484, // Kasimpasa
  3205, // Kayserispor
  120, // Kocaelispor
  2293, // Konyaspor
  152, // Samsunspor
  449, // Trabzonspor
  // --- Brasileirão (20) ---
  614, // CR Flamengo
 //2029, // Ceará Sporting Club
 //210, // Grêmio Foot-Ball Porto Alegrense
 //1023, // Sociedade Esportiva Palmeiras
 199, // Sport Club Corinthians Paulista
 //6600, // Sport Club Internacional
 537, // Botafogo de Futebol e Regatas
 330, // Clube Atlético Mineiro
 //978, // Clube de Regatas Vasco da Gama
 609, // Cruzeiro Esporte Clube
 //10010, // Esporte Clube Bahia
 //10492, // Esporte Clube Juventude
 //2125, // Esporte Clube Vitória
 2462, // Fluminense Football Club
 //10870, // Fortaleza Esporte Clube
 //3876, // Mirassol Futebol Clube (SP)
 //8793, // Red Bull Bragantino
 221, // Santos FC
 //8718, // Sport Club do Recife
 585, // São Paulo Futebol Clube
  // --- Liga MX (18) ---
 // 2407, // CF Monterrey
 // 8590, // Atlas Guadalajara
 // 40188, // Atlético de San Luis
 // 3711, // CD Cruz Azul
 // 3631, // CF América
 // 4035, // CF Pachuca
 // 4941, // Club León FC
 // 1146, // Club Necaxa
 // 13353, // Club Tijuana
 // 6711, // Deportivo Guadalajara
 // 1804, // Deportivo Toluca
 // 49283, // FC Juárez
 // 82696, // Mazatlán FC
 // 5662, // Puebla FC
 // 4961, // Querétaro FC
 // 1403, // Santos Laguna
  7055, // Tigres UANL
 // 7633, // UNAM Pumas
  // --- MLS (30) ---
  69261, // Inter Miami CF
  1061, // Los Angeles Galaxy
  4284, // Sporting Kansas City
  51663, // Atlanta United FC
  72309, // Austin FC
  4078, // CF Montréal
  78435, // Charlotte FC
  432, // Chicago Fire FC
  1247, // Colorado Rapids
  813, // Columbus Crew
  2440, // D.C. United
  51772, // FC Cincinnati
  8816, // FC Dallas
  9168, // Houston Dynamo FC
  51828, // Los Angeles FC
  56089, // Minnesota United FC
  63966, // Nashville SC
  626, // New England Revolution
  40058, // New York City FC
  623, // New York Red Bulls
  45604, // Orlando City SC
  25467, // Philadelphia Union
  4291, // Portland Timbers
  6643, // Real Salt Lake City
  114977, // San Diego FC
  218, // San Jose Earthquakes
  9636, // Seattle Sounders FC
  82686, // St. Louis CITY SC
  11141, // Toronto FC
  6321, // Vancouver Whitecaps FC
  // --- Argentina (30) ---
  189, // CA Boca Juniors
  209, // CA River Plate
//1030, // AA Argentinos Juniors
//12301, // CA Aldosivi
//830, // CA Banfield
//25184, // CA Barracas Central
//31284, // CA Central Córdoba (SdE)
//2063, // CA Huracán
//1234, // CA Independiente
//333, // CA Lanús
//1286, // CA Newell\
//1418, // CA Rosario Central
//1775, // CA San Lorenzo de Almagro
//10511, // CA San Martín (San Juan)
//12454, // CA Sarmiento (Junin)
//3938, // CA Talleres
//7097, // CA Unión (Santa Fe)
//1029, // CA Vélez Sarsfield
//12574, // CD Godoy Cruz Antonio Tomba
//12179, // CS Independiente Rivadavia
//2417, // Club Atlético Belgrano
//928, // Club Atlético Platense
//11831, // Club Atlético Tigre
//14554, // Club Atlético Tucumán
//19775, // Club Deportivo Riestra
//288, // Club Estudiantes de La Plata
//1106, // Club de Gimnasia y Esgrima La Plata
//2402, // Defensa y Justicia
//1829, // Instituto ACC
//1444, // Racing Club
  // --- Belgium (16) ---
  520, // Cercle Brugge
  2282, // Club Brugge KV
  9010, // FCV Dender EH
  157, // KAA Gent
  1184, // KRC Genk
  354, // KV Mechelen
  968, // KVC Westerlo
  2727, // Oud-Heverlee Leuven
  3901, // RAAL La Louvière
  58, // RSC Anderlecht
  1096, // Royal Antwerp FC
  172, // Royal Charleroi SC
  475, // Sint-Truidense VV
  3057, // Standard Liège
  3948, // Union Saint-Gilloise
  3508, // Zulte Waregem
  // --- J1 League (19) ---
  //9597, // Avispa Fukuoka
 // 1022, // Cerezo Osaka
 // 6631, // FC Tokyo
 // 22171, // Fagiano Okayama
 /// 596, // Gamba Osaka
 //2241, // Kashima Antlers
 //6632, // Kashiwa Reysol
 //9598, // Kawasaki Frontale
 //593, // Kyoto Sanga
 //23568, // Machida Zelvia
 //1066, // Nagoya Grampus
 //2697, // Sanfrecce Hiroshima
 //1062, // Shimizu S-Pulse
 //8457, // Shonan Bellmare
 //3734, // Tokyo Verdy
 //828, // Urawa Red Diamonds
 //3958, // Vissel Kobe
 //3828, // Yokohama F. Marinos
 //943, // Yokohama FC
];