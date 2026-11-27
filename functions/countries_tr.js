"use strict";
// Country names in Turkish for hints (Transfer Duel, solo Transfer Dedektifi).
const COUNTRIES_TR = {"Spain": "İspanya", "France": "Fransa", "Portugal": "Portekiz", "Italy": "İtalya",
  "Netherlands": "Hollanda", "Germany": "Almanya", "Brazil": "Brezilya", "England": "İngiltere",
  "Belgium": "Belçika", "Argentina": "Arjantin", "Denmark": "Danimarka", "Turkey": "Türkiye",
  "Türkiye": "Türkiye", "Greece": "Yunanistan", "Switzerland": "İsviçre", "Serbia": "Sırbistan",
  "Uruguay": "Uruguay", "Japan": "Japonya", "Colombia": "Kolombiya", "Russia": "Rusya", "Croatia": "Hırvatistan",
  "Côte d'Ivoire": "Fildişi Sahili", "Cote d'Ivoire": "Fildişi Sahili", "Ukraine": "Ukrayna",
  "Senegal": "Senegal", "Scotland": "İskoçya", "Algeria": "Cezayir", "Morocco": "Fas", "Poland": "Polonya",
  "Austria": "Avusturya", "Nigeria": "Nijerya", "Mexico": "Meksika", "Sweden": "İsveç", "Ghana": "Gana",
  "Cameroon": "Kamerun", "Bosnia and Herzegovina": "Bosna-Hersek", "DR Congo": "Kongo DC",
  "Slovakia": "Slovakya", "Norway": "Norveç", "Guinea": "Gine", "Hungary": "Macaristan", "Kosovo": "Kosova",
  "Canada": "Kanada", "Ecuador": "Ekvador", "Egypt": "Mısır", "Montenegro": "Karadağ", "Iran": "İran",
  "Czech Republic": "Çekya", "Slovenia": "Slovenya", "Chile": "Şili", "Venezuela": "Venezuela",
  "Ireland": "İrlanda", "Iceland": "İzlanda", "USA": "ABD", "United States": "ABD", "Gabon": "Gabon",
  "Finland": "Finlandiya", "Costa Rica": "Kosta Rika", "Northern Ireland": "Kuzey İrlanda",
  "Australia": "Avustralya", "Angola": "Angola", "Cape Verde": "Yeşil Burun Adaları", "Romania": "Romanya",
  "Togo": "Togo", "Tunisia": "Tunus", "Mali": "Mali", "Suriname": "Surinam", "Albania": "Arnavutluk",
  "Peru": "Peru", "Burkina Faso": "Burkina Faso", "New Zealand": "Yeni Zelanda", "Tanzania": "Tanzanya",
  "Benin": "Benin", "Paraguay": "Paraguay", "Jamaica": "Jamaika", "Congo": "Kongo",
  "Central African Republic": "Orta Afrika Cumhuriyeti", "Belarus": "Belarus", "Armenia": "Ermenistan",
  "Israel": "İsrail", "Equatorial Guinea": "Ekvator Ginesi", "Uzbekistan": "Özbekistan", "Georgia": "Gürcistan",
  "North Macedonia": "Kuzey Makedonya", "Wales": "Galler", "South Korea": "Güney Kore", "Korea Republic":
  "Güney Kore", "Bulgaria": "Bulgaristan", "Lithuania": "Litvanya", "Latvia": "Letonya", "Estonia": "Estonya",
  "Zambia": "Zambiya", "Zimbabwe": "Zimbabve", "Kenya": "Kenya", "South Africa": "Güney Afrika",
  "Saudi Arabia": "Suudi Arabistan", "Qatar": "Katar", "China": "Çin", "Bolivia": "Bolivya",
  "Honduras": "Honduras", "Panama": "Panama", "Haiti": "Haiti", "Guinea-Bissau": "Gine-Bissau",
  "Sierra Leone": "Sierra Leone", "Gambia": "Gambiya", "The Gambia": "Gambiya", "Mozambique": "Mozambik",
  "Cyprus": "Kıbrıs", "Luxembourg": "Lüksemburg", "Moldova": "Moldova", "Azerbaijan": "Azerbaycan",
  "Kazakhstan": "Kazakistan", "Iraq": "Irak", "Syria": "Suriye", "Jordan": "Ürdün", "Lebanon": "Lübnan",
  "Libya": "Libya", "Sudan": "Sudan", "Ethiopia": "Etiyopya", "Uganda": "Uganda", "Madagascar": "Madagaskar",
  "Comoros": "Komorlar", "Mauritania": "Moritanya", "Niger": "Nijer", "Curaçao": "Curaçao"};
const countryTr = (c) => COUNTRIES_TR[c] || c || "bilinmiyor";

module.exports = {COUNTRIES_TR, countryTr};
