"use strict";
// Every player induces a clique. A shortest club path cannot repeat a player:
// both uses would be replaceable by one edge. Blocking previously used players
// and clubs therefore makes ordinary BFS exact for the remaining legal graph.
function graphOf(catalog) {
  const players = new Map(catalog.graph.map((p) => [p.id, p.clubs]));
  const byClub = new Map();
  for (const [pid, ids] of players) {
    for (const id of ids) {
      if (!byClub.has(id)) byClub.set(id, []);
      byClub.get(id).push(pid);
    }
  }
  return {players, byClub};
}
function shortest(graph, start, target, blockedClubs = [], blockedPlayers = [], limit = 8) {
  if (start === target) return [];
  const clubs = new Set(blockedClubs); const players = new Set(blockedPlayers);
  const visited = new Set([start]); const queue = [{club: start, path: []}];
  for (let i = 0; i < queue.length; i++) {
    const node = queue[i]; if (node.path.length >= limit) continue;
    for (const pid of graph.byClub.get(node.club) || []) {
      if (players.has(pid)) continue;
      for (const club of graph.players.get(pid)) {
        if (visited.has(club) || clubs.has(club)) continue;
        const path = [...node.path, {playerId: pid, clubId: club}];
        if (club === target) return path;
        visited.add(club); queue.push({club, path});
      }
    }
  }
  return null;
}
function validMove(graph, run, playerId, clubId) {
  const path = run.path || [];
  const current = path.length ? path[path.length - 1].clubId : run.puzzle.start;
  const ids = graph.players.get(playerId);
  // Restricted chains: a banned club can never be a step of the route.
  if ((run.puzzle.banned || []).includes(clubId)) return false;
  return !!ids && ids.includes(current) && ids.includes(clubId) && clubId !== run.puzzle.start &&
    !path.some((x) => x.clubId === clubId || x.playerId === playerId) && clubId !== current;
}
function remaining(graph, run) {
  const path = run.path || [];
  const current = path.length ? path[path.length - 1].clubId : run.puzzle.start;
  const blocked = [run.puzzle.start, ...run.puzzle.banned || [], ...path.map((x) => x.clubId)];
  return shortest(graph, current, run.puzzle.target, blocked,
      path.map((x) => x.playerId), run.maxMoves - path.length);
}
// Number of distinct shortest routes (player, club steps). Layered BFS counts
// each way once; shortest routes never reuse a player or club (see above).
function countShortest(graph, start, target, banned = []) {
  const skip = new Set(banned);
  const dist = new Map([[start, 0]]); const ways = new Map([[start, 1]]); let layer = [start];
  while (layer.length && !dist.has(target)) {
    const next = new Set();
    for (const club of layer) {
      for (const pid of graph.byClub.get(club) || []) {
        for (const to of graph.players.get(pid)) {
          if (skip.has(to)) continue;
          if (dist.has(to) && dist.get(to) <= dist.get(club)) continue;
          if (!dist.has(to)) {
            dist.set(to, dist.get(club) + 1); next.add(to);
          }
          ways.set(to, (ways.get(to) || 0) + ways.get(club));
        }
      }
    }
    layer = [...next];
  }
  return ways.get(target) || 0;
}
module.exports = {graphOf, shortest, validMove, remaining, countShortest};
