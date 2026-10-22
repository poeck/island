// Local civil dates use noon to avoid crossing DST boundaries at midnight.
function civil(year, month, day) { return new Date(year, month, day, 12); }
function same(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
function month(date, delta) { return civil(date.getFullYear(), date.getMonth() + delta, 1); }
function day(date, delta) { return civil(date.getFullYear(), date.getMonth(), date.getDate() + delta); }
function cells(date) {
    const first = civil(date.getFullYear(), date.getMonth(), 1);
    const offset = (first.getDay() + 6) % 7;
    return Array.from({length:42}, (_,index) => day(first, index - offset));
}
function week(date) {
    const value = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    value.setUTCDate(value.getUTCDate() + 4 - (value.getUTCDay() || 7));
    const first = new Date(Date.UTC(value.getUTCFullYear(), 0, 1));
    return Math.ceil((((value - first) / 86400000) + 1) / 7);
}
function dayOfYear(date) { return Math.round((Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) - Date.UTC(date.getFullYear(), 0, 1)) / 86400000) + 1; }
if (typeof module !== 'undefined') module.exports = {civil,same,month,day,cells,week,dayOfYear};
