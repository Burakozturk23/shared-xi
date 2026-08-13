import json
from pathlib import Path

import pandas as pd
import re

# ==========================================================
# PATHS
# ==========================================================

BASE_DIR = Path(__file__).resolve().parent.parent

DATASET = BASE_DIR / "dataset"
OUTPUT = BASE_DIR / "assets" / "data"

OUTPUT.mkdir(parents=True, exist_ok=True)


# ==========================================================
# HELPERS
# ==========================================================

def safe(value):
    if pd.isna(value):
        return ""
    return str(value).strip()

def normalize(text):
    if not text:
        return ""

    text = text.lower().strip()

    replacements = {
        "á":"a","à":"a","ä":"a","â":"a","ã":"a","å":"a","ā":"a",
        "ç":"c","ć":"c","č":"c",
        "ď":"d","đ":"d",
        "é":"e","è":"e","ë":"e","ê":"e","ē":"e",
        "ğ":"g",
        "í":"i","ì":"i","ï":"i","î":"i","ī":"i","ı":"i",
        "ñ":"n","ń":"n",
        "ó":"o","ò":"o","ö":"o","ô":"o","õ":"o","ō":"o",
        "ş":"s","ś":"s","š":"s",
        "ú":"u","ù":"u","ü":"u","û":"u","ū":"u",
        "ý":"y","ÿ":"y",
        "ž":"z","ź":"z","ż":"z",
        "'":"",
        "-":"",
        "`":"",
        "´":"",
        "’":""
    }

    for old, new in replacements.items():
        text = text.replace(old, new)

    return re.sub(r'[^a-z0-9]', '', text)


# ==========================================================
# LOAD TEAM DETAILS
# ==========================================================

print("Loading team_details.csv...")

teams_df = pd.read_csv(
    DATASET / "team_details.csv",
    low_memory=False,
)

print(f"Loaded {len(teams_df)} rows")


# ==========================================================
# BUILD CLUBS
# ==========================================================

clubs = {}

for _, row in teams_df.iterrows():

    club_id = int(row["club_id"])

    if club_id not in clubs:

        clean_club_name = re.sub(
            r"\s*\(\d+\)$",
            "",
            safe(row["club_name"]),
        ).strip()

        clubs[club_id] = {
            "id": club_id,
            "name": clean_club_name,
            "country": safe(row["country_name"]),
            "league": safe(row["competition_name"]),
            "logo": safe(row["logo_url"]),
        }


clubs_json = sorted(
    clubs.values(),
    key=lambda x: x["name"]
)


# ==========================================================
# SAVE
# ==========================================================

with open(
    OUTPUT / "clubs.json",
    "w",
    encoding="utf-8"
) as f:

    json.dump(
        clubs_json,
        f,
        ensure_ascii=False,
        indent=2
    )

print()
print("=" * 40)
print(f"clubs.json created!")
print(f"Club count : {len(clubs_json)}")
print("=" * 40)


# ==========================================================
# LOAD PLAYERS
# ==========================================================

print("\nLoading player_profiles.csv...")

players_df = pd.read_csv(
    DATASET / "player_profiles.csv",
    low_memory=False,
)

print(f"Loaded {len(players_df)} players")


# ==========================================================
# LOAD TRANSFERS
# ==========================================================

print("\nLoading transfer_history.csv...")

transfers_df = pd.read_csv(
    DATASET / "transfer_history.csv",
    low_memory=False,
)

print(f"Loaded {len(transfers_df)} transfers")


# ==========================================================
# BUILD CAREER TIMELINE (chronological club order + years)
# ==========================================================

print("\nBuilding career timelines...")

valid_club_ids = set(clubs.keys())

transfer_history_df = pd.read_csv(
    DATASET / "transfer_history.csv",
    low_memory=False,
    usecols=["player_id", "transfer_date", "to_team_id", "transfer_type"],
)

transfer_history_df = transfer_history_df[
    transfer_history_df["transfer_type"].isin(["Transfer", "Loan", "Draft"])
]

transfer_history_df["transfer_date"] = pd.to_datetime(
    transfer_history_df["transfer_date"],
    errors="coerce",
)

transfer_history_df = transfer_history_df.dropna(subset=["transfer_date"])
transfer_history_df = transfer_history_df.sort_values("transfer_date")

career_timeline_map = {}

for player_id, group in transfer_history_df.groupby("player_id"):
    stops = []

    for _, row in group.iterrows():
        club_id = row["to_team_id"]
        if pd.isna(club_id):
            continue

        club_id = int(club_id)
        if club_id not in valid_club_ids:
            continue

        year = row["transfer_date"].year

        if stops and stops[-1]["clubId"] == club_id:
            continue

        stops.append({"clubId": club_id, "startYear": int(year)})

    if len(stops) < 2:
        continue

    timeline = []
    for i, stop in enumerate(stops):
        end_year = stops[i + 1]["startYear"] if i + 1 < len(stops) else None
        timeline.append({
            "clubId": stop["clubId"],
            "startYear": stop["startYear"],
            "endYear": end_year,
        })

    career_timeline_map[int(player_id)] = timeline

print(f"Built career timelines for {len(career_timeline_map)} players")




print("\nLoading player_performances.csv (career goals)...")

performances_df = pd.read_csv(
    DATASET / "player_performances.csv",
    low_memory=False,
    usecols=["player_id", "goals"],
)

performances_df["goals"] = performances_df["goals"].fillna(0)

career_goals_map = (
    performances_df.groupby("player_id")["goals"].sum().to_dict()
)

print(f"Loaded career goals for {len(career_goals_map)} players")


# ==========================================================
# LOAD MARKET VALUES
# ==========================================================

print("\nLoading player_latest_market_value.csv...")

market_value_df = pd.read_csv(
    DATASET / "player_latest_market_value.csv",
    low_memory=False,
)

market_value_map = dict(
    zip(
        market_value_df["player_id"],
        market_value_df["value"],
    )
)

print(f"Loaded {len(market_value_map)} market values")


# ==========================================================
# LOAD PEAK MARKET VALUES (kariyer boyunca görülen en yüksek değer)
# ==========================================================

print("\nLoading player_market_value.csv (peak values)...")

market_value_history_df = pd.read_csv(
    DATASET / "player_market_value.csv",
    low_memory=False,
    usecols=["player_id", "value"],
)

peak_market_value_map = (
    market_value_history_df.groupby("player_id")["value"].max().to_dict()
)

print(f"Loaded peak market values for {len(peak_market_value_map)} players")


# ==========================================================
# LOAD NATIONAL TEAMS
# ==========================================================

print("\nLoading player_national_performances.csv...")

national_df = pd.read_csv(
    DATASET / "player_national_performances.csv",
    low_memory=False,
)

print(f"Loaded {len(national_df)} national appearances")

# ==========================================================
# BUILD PLAYER -> CLUBS MAP
# ==========================================================

print("\nBuilding player clubs...")

player_clubs = {}

for _, row in transfers_df.iterrows():

    player_id = int(row["player_id"])

    if player_id not in player_clubs:
        player_clubs[player_id] = set()

    # Eski kulüp
    if pd.notna(row["from_team_id"]):
        player_clubs[player_id].add(int(row["from_team_id"]))

    # Yeni kulüp
    if pd.notna(row["to_team_id"]):
        player_clubs[player_id].add(int(row["to_team_id"]))


# Oyuncunun güncel kulübünü de ekle
for _, row in players_df.iterrows():

    player_id = int(row["player_id"])

    if player_id not in player_clubs:
        player_clubs[player_id] = set()

    if pd.notna(row["current_club_id"]):
        player_clubs[player_id].add(int(row["current_club_id"]))

print(f"Player map created : {len(player_clubs)} players")

# ==========================================================
# BUILD PLAYER -> NATIONAL TEAMS MAP
# ==========================================================

print("\nBuilding player national teams...")

player_nationals = {}

for _, row in national_df.iterrows():

    player_id = int(row["player_id"])

    if player_id not in player_nationals:
        player_nationals[player_id] = set()

    if pd.notna(row["team_id"]):
        player_nationals[player_id].add(int(row["team_id"]))

print(f"National map created : {len(player_nationals)} players")

# En çok maça (caps) sahip olduğu takım = gerçek A Milli Takım'ı
# (diğerleri genelde U15/U17/U19/U21 gibi altyapı kademeleri oluyor).
print("\nBuilding primary (A Milli) national team map...")

primary_national_df = national_df.copy()
primary_national_df["matches"] = primary_national_df["matches"].fillna(0)

primary_national_map = {}

for player_id, group in primary_national_df.groupby("player_id"):
    top_row = group.loc[group["matches"].idxmax()]
    primary_national_map[int(player_id)] = int(top_row["team_id"])

print(f"Primary national team found for {len(primary_national_map)} players")

print("\nBuilding players.json...")

players_json = []

for _, row in players_df.iterrows():

    player_id = int(row["player_id"])

    raw_name = str(row["player_name"]) if pd.notna(row["player_name"]) else ""

    name = re.sub(
    r"\s*\(\d+\)$",
       "",
    raw_name
    ).strip()

    aliases = []

    if name:
     aliases.append(name)

    normalized_aliases = [
    normalize(alias)
    for alias in aliases
]

    players_json.append({

    "id": player_id,

    "name": name,

    "countries": re.split(r"\s{2,}", str(row["citizenship"]).strip())
        if pd.notna(row["citizenship"]) and str(row["citizenship"]).strip()
        else [],

    "position": str(row["main_position"]) if pd.notna(row["main_position"]) else "",

    "detailedPosition": str(row["position"]) if pd.notna(row["position"]) else "",

    "clubs": sorted(
        list(
            player_clubs.get(player_id, set())
        )
    ),

    "nationalTeams": sorted(
        list(
            player_nationals.get(player_id, set())
        )
    ),

    "primaryNationalTeamId": primary_national_map.get(player_id),

    "aliases": aliases,

    "normalizedName": normalize(name),

    "normalizedAliases": normalized_aliases,

    "marketValue": float(market_value_map.get(player_id, 0) or 0),

    "peakMarketValue": float(peak_market_value_map.get(player_id, 0) or 0),

    "careerGoals": int(career_goals_map.get(player_id, 0) or 0),

    "careerTimeline": career_timeline_map.get(player_id, []),

})


# ==========================================================
# MANUAL / SUPPLEMENTARY PLAYERS
# ==========================================================
# These players are added only when they are not already present
# in the imported dataset. Club IDs are resolved from the same
# clubs dictionary that is used to create clubs.json, so we do not
# hard-code potentially wrong club IDs.

MANUAL_PLAYERS = [
    ("Raúl Meireles", "Portugal", "Midfield", "Central Midfield", ["Boavista", "FC Porto", "Liverpool FC", "Chelsea FC", "Fenerbahce"]),
    ("Miroslav Stoch", "Slovakia", "Attack", "Left Winger", ["Chelsea FC", "FC Twente", "Fenerbahce", "PAOK", "Slavia Prague", "Sparta Prague"]),
    ("Klaas-Jan Huntelaar", "Netherlands", "Attack", "Centre-Forward", ["PSV Eindhoven", "De Graafschap", "AGOVV Apeldoorn", "SC Heerenveen", "Ajax Amsterdam", "Real Madrid", "AC Milan", "Schalke 04"]),
    ("Mikel John Obi", "Nigeria", "Midfield", "Defensive Midfield", ["Lyn", "Chelsea FC", "Tianjin TEDA", "Middlesbrough", "Stoke City", "Trabzonspor"]),
    ("Cristian Chivu", "Romania", "Defender", "Centre-Back", ["Universitatea Craiova", "Ajax Amsterdam", "AS Roma", "Inter"]),
    ("Antonio Cassano", "Italy", "Attack", "Second Striker", ["Bari", "AS Roma", "Real Madrid", "Sampdoria", "AC Milan", "Inter", "Parma", "Hellas Verona"]),
    ("Adrian Mutu", "Romania", "Attack", "Second Striker", ["Dinamo Bucuresti", "Inter", "Hellas Verona", "Parma", "Chelsea FC", "Juventus FC", "Fiorentina", "Ajaccio", "Petrolul Ploiesti"]),
    ("Florent Malouda", "France", "Attack", "Left Winger", ["Chateauroux", "Guingamp", "Lyon", "Chelsea FC", "Trabzonspor", "Metz"]),
    ("Moussa Sow", "Senegal", "Attack", "Centre-Forward", ["Rennes", "Sedan", "Lille", "Fenerbahce", "Al Ahli", "Bursaspor", "Gaziantep"]),
    ("Çağlar Söyüncü", "Turkey", "Defender", "Centre-Back", ["Altinordu", "SC Freiburg", "Leicester City", "Atletico Madrid", "Fenerbahce"]),
    ("Diego Milito", "Argentina", "Attack", "Centre-Forward", ["Racing Club", "Genoa", "Real Zaragoza", "Inter"]),
    ("Medhi Benatia", "Morocco", "Defender", "Centre-Back", ["Clermont Foot", "Udinese", "AS Roma", "Bayern Munich", "Juventus FC", "Al-Duhail"]),
    ("Luca Toni", "Italy", "Attack", "Centre-Forward", ["Palermo", "Fiorentina", "Bayern Munich", "AS Roma", "Genoa", "Juventus FC", "Hellas Verona"]),
    ("Alberto Gilardino", "Italy", "Attack", "Centre-Forward", ["Parma", "AC Milan", "Fiorentina", "Genoa", "Bologna", "Palermo", "Empoli", "Pescara"]),
    ("Fernando Gago", "Argentina", "Midfield", "Defensive Midfield", ["Boca Juniors", "Real Madrid", "AS Roma", "Valencia", "Velez Sarsfield"]),
    ("Miloš Krasić", "Serbia", "Attack", "Right Winger", ["Vojvodina", "CSKA Moscow", "Juventus FC", "Fenerbahce", "Lechia Gdansk"]),
    ("Mamadou Niang", "Senegal", "Attack", "Centre-Forward", ["Troyes", "Metz", "Strasbourg", "Marseille", "Fenerbahce", "Al-Sadd"]),
    ("Dennis Bergkamp", "Netherlands", "Attack", "Second Striker", ["Ajax Amsterdam", "Inter", "Arsenal FC"]),
    ("Alex de Souza", "Brazil", "Midfield", "Attacking Midfield", ["Coritiba", "Palmeiras", "Parma", "Flamengo", "Fenerbahce"]),
    ("Mark van Bommel", "Netherlands", "Midfield", "Defensive Midfield", ["Fortuna Sittard", "PSV Eindhoven", "Barcelona", "Bayern Munich", "AC Milan"]),
    ("Daniel Van Buyten", "Belgium", "Defender", "Centre-Back", ["Charleroi", "Standard Liege", "Hamburger SV", "Manchester City", "Marseille", "Bayern Munich"]),
    ("Ludovic Giuly", "France", "Attack", "Right Winger", ["Lyon", "Monaco", "Barcelona", "AS Roma", "Paris Saint-Germain", "Lorient"]),
    ("Jean Makoun", "Cameroon", "Midfield", "Defensive Midfield", ["Lille", "Lyon", "Aston Villa", "Olympiacos", "Rennes", "Antalyaspor"]),
    ("Papiss Cissé", "Senegal", "Attack", "Centre-Forward", ["Metz", "Freiburg", "Newcastle United", "Fenerbahce", "Alanyaspor", "Rizespor"]),
    ("Marcos Rojo", "Argentina", "Defender", "Centre-Back", ["Estudiantes", "Spartak Moscow", "Sporting CP", "Manchester United", "Boca Juniors"]),
    ("Raúl Albiol", "Spain", "Defender", "Centre-Back", ["Valencia", "Real Madrid", "Napoli", "Villarreal"]),
    ("Jefferson Farfán", "Peru", "Attack", "Right Winger", ["Alianza Lima", "PSV Eindhoven", "Schalke 04", "Lokomotiv Moscow", "Alianza Lima"]),
    ("Jakub Błaszczykowski", "Poland", "Attack", "Right Winger", ["Wisla Krakow", "Borussia Dortmund", "Fiorentina", "Wolfsburg"]),
    ("Yoann Gourcuff", "France", "Midfield", "Attacking Midfield", ["Rennes", "AC Milan", "Bordeaux", "Lyon", "Dijon"]),
    ("Yacine Brahimi", "Algeria", "Attack", "Left Winger", ["Rennes", "Clermont Foot", "Granada", "FC Porto", "Al-Rayyan", "Al-Gharafa"]),
    ("Theo Hernández", "France", "Defender", "Left-Back", ["Atletico Madrid", "Deportivo Alaves", "Real Madrid", "Real Sociedad", "AC Milan"]),
    ("Sergej Milinković-Savić", "Serbia", "Midfield", "Central Midfield", ["Vojvodina", "Genk", "Lazio", "Al-Hilal"]),
    ("Alessio Romagnoli", "Italy", "Defender", "Centre-Back", ["AS Roma", "Sampdoria", "AC Milan", "Lazio"]),
    ("Gerard Moreno", "Spain", "Attack", "Centre-Forward", ["Villarreal", "Mallorca", "Espanyol"]),
    ("Vitor Roque", "Brazil", "Attack", "Centre-Forward", ["Cruzeiro", "Athletico Paranaense", "Barcelona", "Real Betis"]),
    ("Wilfried Bony", "Ivory Coast", "Attack", "Centre-Forward", ["Sparta Prague", "Vitesse", "Swansea City", "Manchester City", "Stoke City", "Al-Arabi"]),
    ("Seydou Doumbia", "Ivory Coast", "Attack", "Centre-Forward", ["Young Boys", "CSKA Moscow", "Roma", "Newcastle United", "Sporting CP", "Basel", "Girona"]),
    ("Yann M'Vila", "France", "Midfield", "Defensive Midfield", ["Rennes", "Rubin Kazan", "Sunderland", "Saint-Etienne", "Olympiacos", "West Bromwich Albion"]),
    ("Jayden Oosterwolde", "Netherlands", "Defender", "Left-Back", ["FC Twente", "Parma", "Fenerbahce"]),
    ("Nicolas N'Koulou", "Cameroon", "Defender", "Centre-Back", ["Monaco", "Marseille", "Lyon", "Torino", "Watford", "Aris"]),
    ("Lucas Biglia", "Argentina", "Midfield", "Defensive Midfield", ["Independiente", "Anderlecht", "Lazio", "AC Milan", "Fatih Karagumruk", "Istanbul Basaksehir"]),
    ("Álex Baena", "Spain", "Midfield", "Attacking Midfield", ["Villarreal", "Girona", "Atletico Madrid"]),
    ("Franco Mastantuono", "Argentina", "Attack", "Right Winger", ["River Plate", "Real Madrid"]),
    ("Moussa Marega", "Mali", "Attack", "Centre-Forward", ["Maritimo", "Vitoria Guimaraes", "FC Porto", "Al-Hilal", "Sharjah FC"]),
]

# Common naming differences between the manual list and team_details.csv.
CLUB_ALIASES = {
    "fenerbahce": "Fenerbahce",
    "barcelona": "FC Barcelona",
    "roma": "AS Roma",
    "marseille": "Olympique de Marseille",
    "monaco": "AS Monaco",
    "lyon": "Olympique Lyon",
    "atleticomadrid": "Atletico Madrid",
    "villarreal": "Villarreal CF",
    "parma": "Parma Calcio 1913",
    "bayernmunich": "Bayern Munich",
    "schalke04": "FC Schalke 04",
    "psveindhoven": "PSV Eindhoven",
    "juventusfc": "Juventus FC",
    "manchesterunited": "Manchester United",
    "manchestercity": "Manchester City",
    "realmadrid": "Real Madrid",
    "acmilan": "AC Milan",
    "liverpoolfc": "Liverpool FC",
    "chelseafc": "Chelsea FC",
    "fcporto": "FC Porto",
    "ajaxamsterdam": "Ajax Amsterdam",
    "arsenal": "Arsenal FC",
    "arsenalfc": "Arsenal FC",
    "riversplate": "CA River Plate",
    "riverplate": "CA River Plate",
    "istanbulbasaksehir": "Istanbul Basaksehir",
}


def resolve_manual_clubs(names):
    """Resolve club names against the exact clubs dictionary used by this script."""
    normalized = {}
    for cid, club in clubs.items():
        normalized[normalize(club["name"])] = cid

    result = []
    unresolved = []

    for name in names:
        key = normalize(name)
        key = normalize(CLUB_ALIASES.get(key, name))

        club_id = normalized.get(key)

        if club_id is None:
            # Conservative fallback: only accept a unique normalized prefix/contains match.
            candidates = [
                cid for cname, cid in normalized.items()
                if cname.startswith(key) or key.startswith(cname)
            ]
            if len(candidates) == 1:
                club_id = candidates[0]

        if club_id is not None:
            result.append(int(club_id))
        else:
            unresolved.append(name)

    if unresolved:
        print(f"[MANUAL PLAYER] Clubs not found: {', '.join(unresolved)}")

    return sorted(set(result))


existing_player_names = {
    normalize(p["name"])
    for p in players_json
    if p.get("name")
}

# Negative IDs are deliberate: they cannot collide with the imported dataset's
# player IDs, and these records are clearly identifiable as manual additions.
next_manual_id = -1
manual_added = 0

for name, country, position, detailed_position, club_names in MANUAL_PLAYERS:
    normalized_name = normalize(name)

    # Never duplicate a player that is already present in the imported dataset.
    if normalized_name in existing_player_names:
        continue

    players_json.append({
        "id": next_manual_id,
        "name": name,
        "countries": [country],
        "position": position,
        "detailedPosition": detailed_position,
        "clubs": resolve_manual_clubs(club_names),
        "nationalTeams": [],
        "primaryNationalTeamId": None,
        "aliases": [name],
        "normalizedName": normalized_name,
        "normalizedAliases": [normalized_name],
        "marketValue": 0,
        "peakMarketValue": 0,
        "careerGoals": 0,
        "careerTimeline": [],
    })

    existing_player_names.add(normalized_name)
    next_manual_id -= 1
    manual_added += 1

print(f"Manual players added : {manual_added}")


# ==========================================================
# SAVE PLAYERS
# ==========================================================

with open(
    OUTPUT / "players.json",
    "w",
    encoding="utf-8",
) as f:

    json.dump(
        players_json,
        f,
        ensure_ascii=False,
        indent=2,
    )

print()
print("=" * 40)
print("players.json created!")
print(f"Player count : {len(players_json)}")
print("=" * 40)


# ==========================================================
# BUILD FAMOUS TRANSFERS (Transfer Detective modu için)
# ==========================================================

print("\nBuilding famous_transfers.json...")

full_transfer_df = pd.read_csv(
    DATASET / "transfer_history.csv",
    low_memory=False,
    usecols=[
        "player_id", "transfer_date", "from_team_id", "to_team_id",
        "transfer_type", "transfer_fee",
    ],
)

full_transfer_df = full_transfer_df[
    full_transfer_df["transfer_type"] == "Transfer"
]
full_transfer_df = full_transfer_df[
    full_transfer_df["transfer_fee"] >= 15_000_000
]
full_transfer_df = full_transfer_df[
    full_transfer_df["from_team_id"].isin(valid_club_ids)
    & full_transfer_df["to_team_id"].isin(valid_club_ids)
]
full_transfer_df["transfer_date"] = pd.to_datetime(
    full_transfer_df["transfer_date"], errors="coerce",
)
full_transfer_df = full_transfer_df.dropna(subset=["transfer_date"])

valid_player_ids = {p["id"] for p in players_json}
full_transfer_df = full_transfer_df[
    full_transfer_df["player_id"].isin(valid_player_ids)
]

full_transfer_df = full_transfer_df.sort_values(
    "transfer_fee", ascending=False,
).head(600)

famous_transfers_json = []

for _, row in full_transfer_df.iterrows():
    famous_transfers_json.append({
        "playerId": int(row["player_id"]),
        "year": int(row["transfer_date"].year),
        "fee": float(row["transfer_fee"]),
        "fromClubId": int(row["from_team_id"]),
        "toClubId": int(row["to_team_id"]),
    })

with open(
    OUTPUT / "famous_transfers.json", "w", encoding="utf-8",
) as f:
    json.dump(famous_transfers_json, f, ensure_ascii=False, indent=2)

print(f"famous_transfers.json created! Count: {len(famous_transfers_json)}")