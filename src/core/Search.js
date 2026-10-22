function score(query, candidate) {
    var q = query.toLocaleLowerCase().trim();
    var text = candidate.toLocaleLowerCase();
    if (!q) return 0;
    if (text === q) return 10000;
    if (text.indexOf(q) === 0) return 5000 - text.length;
    var at = text.indexOf(q);
    if (at >= 0) return 3000 - at * 10 - text.length;
    var cursor = 0, result = 0, previous = -2;
    for (var i = 0; i < q.length; i++) {
        var pos = text.indexOf(q[i], cursor);
        if (pos < 0) return -1;
        result += 30 + (pos === previous + 1 ? 25 : 0) + (pos === 0 || /[\s\-_.]/.test(text[pos - 1]) ? 40 : 0) - pos;
        previous = pos; cursor = pos + 1;
    }
    return Math.max(1, result);
}
function rank(entries, query, history) {
    return entries.map(function (e) {
        return {entry: e, score: Math.max(score(query, e.name), score(query, e.genericName || "") - 100,
                 score(query, (e.keywords || []).join(" ")) - 150), recent: history[e.id] || 0};
    }).filter(function (r) { return r.score >= 0; })
      .sort(function (a, b) { return (query.trim() ? b.score - a.score : 0) || b.recent - a.recent || a.entry.name.localeCompare(b.entry.name); })
      .map(function (r) { return r.entry; });
}
if (typeof module !== "undefined") module.exports = {score: score, rank: rank};
