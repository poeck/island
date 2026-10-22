"""On-demand Open-Meteo client. Coordinates stay local except forecast requests."""
import datetime as dt
import json
import math
import os
from pathlib import Path
import time
import tempfile
import urllib.parse
import urllib.request
from zoneinfo import ZoneInfo

DEFAULT = {"name": "Vienna", "country": "Austria", "latitude": 48.2085, "longitude": 16.3721, "timezone": "Europe/Vienna"}
TTL = 900

def location(value):
    if not isinstance(value, dict):
        raise ValueError("Choose a city first.")
    lat, lon = float(value["latitude"]), float(value["longitude"])
    if not math.isfinite(lat) or not math.isfinite(lon) or not (-90 <= lat <= 90 and -180 <= lon <= 180):
        raise ValueError("Invalid location coordinates.")
    return {"name": str(value.get("name", "Selected location"))[:100], "country": str(value.get("country", ""))[:100], "latitude": lat, "longitude": lon, "timezone": str(value.get("timezone", "UTC"))[:100]}

def read(path, default=None):
    try:
        if path.stat().st_size > 2_000_000:
            return default
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return default

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, prefix=path.name, delete=False) as file:
        temp = Path(file.name)
        try:
            file.write(json.dumps(value, allow_nan=False))
            file.close()
            os.replace(temp, path)
        finally:
            temp.unlink(missing_ok=True)

def fetch(host, path, params):
    url = "https://" + host + path + "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"User-Agent": "Island/0.1 (desktop weather)", "Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=8) as response:
        payload = response.read(2_000_001)
        if len(payload) > 2_000_000:
            raise ValueError("Weather response was too large.")
        return json.loads(payload)

def number(value):
    return value if isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) else None

def normalize(raw, city, now):
    """Normalize sparse API responses, retaining missing values rather than fake zeroes."""
    if not isinstance(raw, dict):
        raise ValueError("Invalid forecast response.")
    zone = ZoneInfo(raw.get("timezone") or city["timezone"])
    def local(epoch, fmt):
        return dt.datetime.fromtimestamp(epoch, zone).strftime(fmt) if number(epoch) is not None else "—"
    current = raw.get("current") or {}
    if not isinstance(current, dict):
        raise ValueError("Invalid current conditions.")
    if number(current.get("temperature_2m")) is None:
        raise ValueError("No current weather is available for this location.")
    fields = {"temperature": "temperature_2m", "feels": "apparent_temperature", "humidity": "relative_humidity_2m", "code": "weather_code", "wind": "wind_speed_10m", "direction": "wind_direction_10m", "gusts": "wind_gusts_10m", "pressure": "pressure_msl", "precipitation": "precipitation"}
    conditions = {name: number(current.get(key)) for name, key in fields.items()}
    conditions["day"] = current.get("is_day", 1) != 0
    conditions["time"] = local(current.get("time"), "%H:%M")
    def rows(group, mapping):
        data = raw.get(group) or {}
        if not isinstance(data, dict):
            raise ValueError("Invalid forecast series.")
        epochs = data.get("time") or []
        if not isinstance(epochs, list):
            raise ValueError("Invalid forecast timestamps.")
        result = []
        for i, epoch in enumerate(epochs):
            if number(epoch) is None:
                continue
            row = {"epoch": epoch, "time": local(epoch, "%H:%M"), "dayLabel": local(epoch, "%a"), "dateLabel": local(epoch, "%d %b")}
            for key, source in mapping.items():
                values = data.get(source) or []
                if not isinstance(values, list):
                    raise ValueError("Invalid forecast values.")
                row[key] = number(values[i]) if i < len(values) else None
            result.append(row)
        return result
    daily = rows("daily", {"code": "weather_code", "min": "temperature_2m_min", "max": "temperature_2m_max", "rain": "precipitation_probability_max", "uv": "uv_index_max", "sunrise": "sunrise", "sunset": "sunset"})[:7]
    for row in daily:
        row["sunrise"] = local(row["sunrise"], "%H:%M")
        row["sunset"] = local(row["sunset"], "%H:%M")
    hourly = rows("hourly", {"temperature": "temperature_2m", "code": "weather_code", "rain": "precipitation_probability", "day": "is_day"})
    hourly = [row for row in hourly if row["epoch"] >= now - 1800][:24]
    return {"location": city, "timezone": str(zone), "elevation": number(raw.get("elevation")), "updated": now, "updatedLabel": local(now, "%H:%M"), "updatedDateLabel": local(now, "%d %b %H:%M"), "current": conditions, "daily": daily, "hourly": hourly}

def handle(request, *, state=None, cache=None, transport=fetch, now=None):
    now = time.time() if now is None else now
    state = Path(state or os.environ.get("XDG_STATE_HOME", str(Path.home()/".local/state"))) / "island/weather-location.json"
    cache = Path(cache or os.environ.get("XDG_CACHE_HOME", str(Path.home()/".cache"))) / "island/weather.json"
    try:
        op = request.get("op", "load")
        if op == "search":
            query = str(request.get("query", "")).strip()[:120]
            if len(query) < 2:
                return {"results": [], "error": ""}
            raw = transport("geocoding-api.open-meteo.com", "/v1/search", {"name": query, "count": 8, "language": "en", "format": "json"})
            if not isinstance(raw, dict):
                raise ValueError("Invalid search response.")
            results = [dict(location(row), region=str(row.get("admin1", ""))[:100]) for row in (raw.get("results") or [])]
            return {"results": results, "error": ""}
        city = location(request.get("location") or read(state, DEFAULT))
        saved = read(cache, {})
        data = saved if isinstance(saved, dict) and saved.get("location") == city and isinstance(saved.get("current"), dict) else None
        age = max(0, now - data.get("updated", 0)) if data else None
        if op == "load":
            return {"location": city, "data": data, "stale": age is None or age >= TTL, "error": ""}
        if op != "forecast":
            raise ValueError("Unknown weather request.")
        # A selected city is remembered even if the connection is currently offline.
        write(state, city)
        if data and age < TTL and not request.get("force"):
            return {"location": city, "data": data, "stale": False, "error": ""}
        try:
            raw = transport("api.open-meteo.com", "/v1/forecast", {
                "latitude": city["latitude"], "longitude": city["longitude"], "timezone": "auto", "timeformat": "unixtime", "forecast_days": 7,
                "current": "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m",
                "hourly": "temperature_2m,weather_code,precipitation_probability,is_day",
                "daily": "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max",
                "temperature_unit": "celsius", "wind_speed_unit": "kmh", "precipitation_unit": "mm"})
            data = normalize(raw, city, now)
            write(cache, data)
            return {"location": city, "data": data, "stale": False, "error": ""}
        except (OSError, ValueError, KeyError, TypeError) as exc:
            return {"location": city, "data": data, "stale": True, "error": "Weather unavailable. Check your connection and retry."}
    except (OSError, ValueError, KeyError, TypeError):
        return {"error": "Could not load weather. Check your connection or choose another city.", "results": []}

def main(value):
    try:
        request = json.loads(value)
        result = handle(request) if isinstance(request, dict) else {"error": "Invalid weather request."}
    except (ValueError, TypeError):
        result = {"error": "Invalid weather request."}
    print(json.dumps(result, allow_nan=False))
