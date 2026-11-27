"use strict";
// What each paid support does in each game, in the player's words. Written from
// the hint each server module actually returns (not from the planning table),
// and checked by test: every mode in boosts.modes has a text for each product.
const B = require("./boosts");

const grid = "Seçtiğin kutu için geçerli bir adayın milliyeti ve mevki grubu.";
const story = {boost_basic: "Görevin kendi ipucu.",
  boost_strong: "İlk bağlantıyı gösterir ya da bir yanlış seçeneği eler."};
const word = {boost_basic: "Cevabın kaç harften oluştuğu."};
const anagram = {boost_basic: "Futbolcunun ülkesi ve mevkisi.", boost_first_letter: "Futbolcunun adının ilk harfi."};

const guide = {
  solo_grid_classic: ["Grid · Solo Klasik", "Grid", {boost_basic: grid}],
  solo_grid_reverse: ["Grid · Solo Tersten", "Grid",
    {boost_basic: "Eksenin ortak kriterinin türü: kulüp, milliyet ya da mevki."}],
  solo_grid_random: ["Grid · Solo Rastgele", "Grid", {boost_basic: grid}],
  bot_grid_classic: ["Grid · Bot Klasik", "Grid", {boost_basic: grid}],
  bot_grid_reverse: ["Grid · Bot Tersten", "Grid",
    {boost_basic: "Eksenin ortak kriterinin türü: kulüp, milliyet ya da mevki."}],
  bot_grid_random: ["Grid · Bot Rastgele", "Grid", {boost_basic: grid}],
  bot_loto: ["Bot · Football Loto", "Botla oyna", {boost_basic: "Sıradaki futbolcunun ülkesi ve mevkisi."}],
  bot_team_race: ["Bot · Takım Yarışı", "Botla oyna",
    {boost_basic: "Henüz bulunmamış ortak oyunculardan birinin ülkesi ve mevkisi."}],
  bot_cinko: ["Bot · Futbol Çinko", "Botla oyna", {boost_basic: "Açık bir kutuya uyan bir oyuncu hakkında bilgi."}],
  bot_random_five: ["Bot · Rastgele Beşler", "Botla oyna",
    {boost_basic: "Bir adayın beş kulübün kaçına uyduğu, ülkesi ve mevkisi."}],
  squad_vault: ["Kadro Kasası", "Kadro", {
    boost_basic: "Seçili mevkiye uyan, henüz bulunmamış bir futbolcunun ülkesi ya da ligi.",
    boost_strong: "Aynı futbolcu için daha güçlü bir oyuncu ipucu."}],
  letter11: ["Harf 11", "Kadro", {
    boost_basic: "Seçili mevkiye uyan bir futbolcunun ülkesi, ligi ya da adının ilk iki harfi.",
    boost_connection: "Aynı futbolcunun oynadığı bir kulüp."}],
  career: ["Kariyer Bulmacası", "Bulmaca", {
    boost_basic: "Futbolcunun ülkesi ya da mevkisi.",
    boost_connection: "Sıralama aşamasında yanlış yerdeki bir kartı doğru yerine koyar."}],
  transfer: ["Transfer Dedektifi", "Bulmaca", {
    boost_basic: "Futbolcunun ülkesi ya da mevkisi.",
    boost_first_letter: "Üçüncü ipucu: futbolcunun adının ilk harfi."}],
  mystery: ["Gizemli Futbolcu", "Bulmaca", {boost_basic: "Sıradaki kariyer ipucunu erken açar."}],
  mastermind: ["Kariyer Zinciri", "Bulmaca", {boost_connection: "Sıradaki köprü futbolcusunun adı."}],
  fake_endless: ["Sahte Kulüp · Sonsuz Seri", "Bulmaca", {
    boost_eliminate: "Gerçek kulüplerden birini eleyerek seçenekleri daraltır.",
    boost_connection: "Bir kulübün gerçekten oynanmış olduğunu doğrular."}],
  burst_survival: ["Burst · Dayanıklılık", "Arcade", {boost_basic: "Sorunun ek ipucu."}],
  pyramid: ["Pyramid", "Arcade", {boost_strong: "Bir bağlantı ya da aday türü ipucu."}],
  matching: ["Matching", "Arcade", {boost_strong: "Doğru bir çift önerisi."}],
  daily_lingo: ["Günün Lingo’su", "Kelime", word],
  daily_anagram: ["Günün Anagramı", "Kelime", anagram],
  anagram_practice: ["Sekizli Anagram", "Kelime", anagram],
  passa_daily: ["Mini Passaparola", "Kelime", word],
  passa_weekly: ["Haftalık Passaparola", "Kelime", word],
  daily_question: ["Günün Sorusu", "Günlük", {boost_eliminate: "Bir yanlış şıkkı eler."}],
  daily_match: ["Günün Maçları", "Günlük", {boost_basic: "Maçın iki takımı için bir ortak oyuncu ipucu."}],
  daily_footballer: ["Günün Futbolcusu", "Günlük", {boost_basic: "İlk tahminden sonra isim ipucu."}],
  squad_challenge: ["Kadro Mücadelesi", "Kadro", {
    boost_basic: "Kriterlere uyan 5 adaylık liste; puandan 10 düşer.",
    boost_strong: "Tek aday önerisi; puandan 20 düşer."}],
  higher_lower_training: ["Higher or Lower · Antrenman", "Seçim", {boost_basic: "Gizli değerin aralığı."}],
  blind_ranking_training: ["Blind Ranking · Antrenman", "Seçim",
    {boost_basic: "İstatistikte listenin üst ya da alt yarısında olduğu."}],
  player_journey: ["Oyuncu Yolculuğu", "Hikâye", story],
  what_if: ["What If", "Hikâye", story],
  ucl_moments: ["UCL Moments", "Hikâye", story],
  nostalgia: ["Türkiye Nostaljisi", "Hikâye", story],
  international_glory: ["International Glory", "Hikâye", story],
  dynasties: ["Hanedanlar", "Hikâye", story],
  football_docu: ["Futbol Belgeseli", "Hikâye", story],
  derby_day: ["Derbi Günü", "Hikâye", story],
};

/** The guide for the modes this player can use supports in, store order kept. */
function forModes(ready) {
  return Object.entries(guide).filter(([modeId]) => ready?.[modeId] === true && B.modes[modeId])
      .map(([modeId, [name, group, effects]]) => ({modeId, name, group,
        supports: B.modes[modeId].map((id) => ({itemId: "boost_" + id, title: B.products["boost_" + id].title,
          effect: effects["boost_" + id]}))}));
}

module.exports = {guide, forModes};
