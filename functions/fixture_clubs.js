"use strict";
const catalog = require("./config/daily_catalog.json");
const norm = (value) => String(value).toLocaleLowerCase("tr").replace(/ı/g, "i").normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9 ]/g, " ").replace(/\b(fc|cf|ac|afc|sc|jk|de)\b/g, "")
    .replace(/\s/g, "");
const aliases = {"Manchester United": 985, "Manchester City": 281, "Atletico Madrid": 13,
  "Athletic Club": 621, "Real Sociedad": 681, "Inter": 46, "AC Milan": 5, "Bayern München": 27,
  "Bayern Munich": 27, "Borussia Dortmund": 16, "Bayer Leverkusen": 15, "RB Leipzig": 23826,
  "Borussia Mönchengladbach": 18, "Paris Saint Germain": 583, "Paris Saint-Germain": 583, "PSG": 583,
  "Lyon": 1041, "Marseille": 244, "Monaco": 162, "Lille": 1082, "Ajax": 610, "Benfica": 294,
  "Sporting CP": 336, "Sporting Lisbon": 336, "Celtic": 371, "Rangers": 124, "PSV Eindhoven": 383,
  "Fenerbahce": 36, "Besiktas": 114, "Tottenham": 148, "Newcastle": 762, "West Ham": 379,
  "Leicester": 1003, "Napoli": 6195, "Roma": 12, "Lazio": 398, "Fiorentina": 430, "Atalanta": 800,
  "Villarreal": 1050, "Valencia": 1049, "Real Betis": 150, "Porto": 720};
const clubNames = new Map(Object.entries(catalog.clubs).map(([id, name]) => [norm(name), Number(id)]));
for (const [name, id] of Object.entries(aliases)) clubNames.set(norm(name), id);
// Past days written by the old bundled calendar keep their football-data team ids.
const sourceClubs = require("./config/football_data_clubs.json");
// API-Football team id → database club id (reviewed; see daily_fixture_control/unmapped).
const apiClubs = require("./config/api_football_teams.json");
function fixtureClub(m, side) {
  if (m.source === "football-data-snapshot") return sourceClubs[String(m[side + "SourceId"])];
  const byId = apiClubs[String(m[side + "ApiId"])];
  if (byId) return byId;
  return clubNames.get(norm(m[side + "Name"]));
}
module.exports = {norm, fixtureClub};
