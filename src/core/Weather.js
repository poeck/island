function condition(code, day) {
    if (code === null || code === undefined) return {label:"Weather unavailable", icon:"cloud"};
    if (code === 0) return {label:day === false || day === 0 ? "Clear night" : "Clear sky", icon:day === false || day === 0 ? "moon" : "sun"};
    if (code === 1 || code === 2) return {label:"Partly cloudy",icon:"partly"};
    if (code === 3) return {label:"Overcast",icon:"cloud"};
    if ([45,48].includes(code)) return {label:"Fog",icon:"fog"};
    if ([51,53,55,56,57].includes(code)) return {label:"Drizzle",icon:"rain"};
    if ([61,63,65,66,67,80,81,82].includes(code)) return {label:"Rain",icon:"rain"};
    if ([71,73,75,77,85,86].includes(code)) return {label:"Snow",icon:"snow"};
    if ([95,96,99].includes(code)) return {label:"Thunderstorms",icon:"storm"};
    return {label:"Unknown conditions",icon:"cloud"};
}
function value(n, unit, decimals) { return typeof n === "number" && isFinite(n) ? n.toFixed(decimals || 0) + (unit || "") : "—"; }
function direction(n) { return typeof n === "number" && isFinite(n) ? ["N","NE","E","SE","S","SW","W","NW"][Math.round(n/45)%8] : ""; }
function demo() {
    const city={name:"Vienna",country:"Austria",latitude:48.2085,longitude:16.3721,timezone:"Europe/Vienna"};
    return {location:city,timezone:"Europe/Vienna",elevation:190,updated:0,updatedLabel:"17:30",current:{temperature:17,feels:15,humidity:72,code:51,wind:14,direction:180,gusts:23,pressure:1014,precipitation:0.2,day:true,time:"17:30"},daily:[51,3,2,61,3,0,2].map((code,i)=>({code:code,min:10+i%3,max:21-i,rain:[65,15,10,80,25,0,5][i],uv:2.4,sunrise:"07:23",sunset:"17:54",dayLabel:["Wed","Thu","Fri","Sat","Sun","Mon","Tue"][i],dateLabel:(21+i)+" Oct"})),hourly:Array.from({length:24},(_,i)=>({temperature:17-i%8,code:i<4?51:3,rain:i<4?65:15,day:i<2||i>13,time:String((18+i)%24).padStart(2,"0")+":00",dayLabel:i<6?"Wed":"Thu",dateLabel:i<6?"21 Oct":"22 Oct"}))};
}
if (typeof module !== "undefined") module.exports = {condition,value,direction,demo};
