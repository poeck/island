import datetime as dt
import json
import sys
from pathlib import Path
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'lib'))
import weather

NOW=1792580400  # 2026-10-21 11:00 UTC

def forecast():
    return {'timezone':'Europe/Vienna','elevation':190,'current':{'temperature_2m':0,'apparent_temperature':-2,'weather_code':0,'is_day':1,'time':NOW},'daily':{'time':[NOW],'temperature_2m_min':[-3],'temperature_2m_max':[5],'sunrise':[NOW-10000],'sunset':[NOW+10000]},'hourly':{'time':[NOW-4000,NOW,NOW+3600],'temperature_2m':[0,1,2],'weather_code':[0,2,3]}}

class WeatherTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.kw={'state':self.temp.name+'/state','cache':self.temp.name+'/cache','now':NOW}
        self.calls=[]
    def transport(self,host,path,params):
        self.calls.append((host,path,params)); return forecast()
    def test_first_open_defaults_cache_and_force_refresh(self):
        result=weather.handle({'op':'load'},transport=self.transport,**self.kw)
        self.assertEqual(result['location']['name'],'Vienna'); self.assertIsNone(result['data']); self.assertFalse(self.calls)
        result=weather.handle({'op':'forecast'},transport=self.transport,**self.kw)
        self.assertEqual(result['data']['current']['temperature'],0)
        self.assertIsNone(result['data']['current']['humidity'])
        self.assertEqual(len(result['data']['hourly']),2)
        weather.handle({'op':'forecast'},transport=self.transport,**self.kw);self.assertEqual(len(self.calls),1)
        weather.handle({'op':'forecast','force':True},transport=self.transport,**self.kw);self.assertEqual(len(self.calls),2)
        self.assertEqual(self.calls[0][0],'api.open-meteo.com')
    def test_offline_preserves_stale_cache_and_city_selection(self):
        weather.handle({'op':'forecast'},transport=self.transport,**self.kw)
        def offline(*args):raise OSError('offline')
        self.kw['now']+=3600
        result=weather.handle({'op':'forecast'},transport=offline,**self.kw)
        self.assertTrue(result['stale']);self.assertTrue(result['error']);self.assertEqual(result['data']['location']['name'],'Vienna')
        city=dict(weather.DEFAULT,name='Graz',latitude=47.07)
        result=weather.handle({'op':'forecast','location':city},transport=offline,**self.kw)
        self.assertIsNone(result['data']);self.assertEqual(result['location']['name'],'Graz')
        self.assertEqual(weather.handle({'op':'load'},**self.kw)['location']['name'],'Graz')
    def test_search_no_results_and_untrusted_fields(self):
        def search(host,path,params):
            self.assertEqual(host,'geocoding-api.open-meteo.com');self.assertEqual(params['name'],'Vienna')
            return {'results':[dict(weather.DEFAULT,admin1='Vienna',untrusted='discard')]}
        result=weather.handle({'op':'search','query':' Vienna '},transport=search,**self.kw)
        self.assertEqual(result['results'][0]['region'],'Vienna');self.assertNotIn('untrusted',result['results'][0])
        self.assertEqual(weather.handle({'op':'search','query':'zz'},transport=lambda *a:{},**self.kw)['results'],[])
        self.assertEqual(weather.handle({'op':'search','query':'x'},transport=self.transport,**self.kw)['results'],[]);self.assertFalse(self.calls)
    def test_invalid_coordinates_malformed_cache_and_api_errors(self):
        self.assertTrue(weather.handle({'op':'forecast','location':dict(weather.DEFAULT,latitude=float('nan'))},**self.kw)['error'])
        target=Path(self.kw['cache'])/'island/weather.json';target.parent.mkdir(parents=True);target.write_text('not json')
        self.assertIsNone(weather.handle({'op':'load'},**self.kw)['data'])
        for raw in [{'error':True},[],{'current':{'temperature_2m':17},'hourly':5}]:
            result=weather.handle({'op':'forecast'},transport=lambda *a:raw,**self.kw)
            self.assertTrue(result['error']);self.assertIsNone(result['data'])
        raw=forecast();raw['daily']=None;raw['hourly']=None
        self.assertEqual(weather.normalize(raw,weather.DEFAULT,NOW)['daily'],[])
    def test_timezone_uses_destination_and_dst(self):
        raw=forecast();raw['timezone']='America/New_York';raw['hourly']={'time':[1793511000,1793514600,1793518200],'temperature_2m':[1,2,3]}
        data=weather.normalize(raw,weather.DEFAULT,1793511000)
        self.assertEqual([r['time'] for r in data['hourly']],['01:30','01:30','02:30'])
        self.assertEqual(data['timezone'],'America/New_York')
    def test_daily_dates_use_api_offset_across_dst_changes(self):
        for zone, start, offset in [
            ('Europe/Vienna', '2026-10-24', 7200),
            ('Europe/Vienna', '2026-03-28', 3600),
            ('America/New_York', '2026-10-31', -14400),
            ('America/New_York', '2026-03-07', -18000),
            ('Asia/Kolkata', '2026-10-24', 19800),
        ]:
            with self.subTest(zone=zone, start=start):
                first=dt.datetime.fromisoformat(start).replace(tzinfo=dt.timezone(dt.timedelta(seconds=offset)))
                dates=[first+dt.timedelta(days=i) for i in range(7)]
                epochs=[day.timestamp() for day in dates]
                raw=forecast();raw['timezone']=zone;raw['utc_offset_seconds']=offset
                raw['daily']={'time':epochs, 'temperature_2m_min':list(range(7)), 'temperature_2m_max':list(range(10,17)), 'sunrise':[epoch+7*3600 for epoch in epochs], 'sunset':[epoch+18*3600 for epoch in epochs]}
                data=weather.normalize(raw,weather.DEFAULT,epochs[0]+12*3600)
                self.assertEqual([r['dayLabel'] for r in data['daily']],[day.strftime('%a') for day in dates])
                self.assertEqual([r['dateLabel'] for r in data['daily']],[day.strftime('%d %b') for day in dates])
                self.assertEqual([r['min'] for r in data['daily']],list(range(7)))
                self.assertEqual([r['max'] for r in data['daily']],list(range(10,17)))
                # Sunrise/sunset are instants, so they still follow the destination's DST rules.
                for row, epoch in zip(data['daily'], epochs):
                    self.assertEqual(row['sunrise'],dt.datetime.fromtimestamp(epoch+7*3600,weather.ZoneInfo(zone)).strftime('%H:%M'))
                    self.assertEqual(row['sunset'],dt.datetime.fromtimestamp(epoch+18*3600,weather.ZoneInfo(zone)).strftime('%H:%M'))

if __name__=='__main__':unittest.main()
