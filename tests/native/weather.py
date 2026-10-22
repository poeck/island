"""Offline subprocess double for the native WeatherService test."""
import json
import os
from pathlib import Path
import sys
import time
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'lib'))
import weather

request=json.loads(sys.argv[1])
scenario=Path(os.environ['ISLAND_WEATHER_SCENARIO']).read_text().strip()
with open(os.environ['ISLAND_WEATHER_REQUESTS'],'a') as log:log.write(json.dumps(request)+'\n')
if request.get('op')=='search':
    if request['query']=='slow':time.sleep(.8)
    results=[] if request['query']=='none' else [dict(weather.DEFAULT,name=request['query'].title(),admin1='Test region')]
    print(json.dumps({'results':results,'error':''}))
else:
    def fetch(*args):
        if scenario=='offline':raise OSError('offline')
        time.sleep(.2)
        now=time.time();times=[now+i*3600 for i in range(24)]
        return {'timezone':'Europe/Vienna','elevation':190,'current':{'temperature_2m':17,'apparent_temperature':15,'relative_humidity_2m':72,'weather_code':51,'is_day':1,'time':now,'wind_speed_10m':14,'wind_gusts_10m':23,'wind_direction_10m':180,'pressure_msl':1014,'precipitation':.2},'daily':{'time':[now+i*86400 for i in range(7)],'temperature_2m_min':[10,8,9,10,11,9,7],'temperature_2m_max':[21,19,18,17,18,19,20],'weather_code':[51,3,2,61,3,0,2],'precipitation_probability_max':[65,20,5,70,30,0,10],'sunrise':[now-36000]*7,'sunset':[now+3600]*7,'uv_index_max':[2.4]*7},'hourly':{'time':times,'temperature_2m':[17-i%8 for i in range(24)],'weather_code':[51]*4+[3]*20,'is_day':[1]*4+[0]*10+[1]*10,'precipitation_probability':[65]*4+[15]*20}}
    print(json.dumps(weather.handle(request,transport=fetch)))
