import json,time,urllib.request,math
from pathlib import Path
base=Path(__file__).resolve().parents[1]
places=json.loads((base/'assets/data/places.json').read_text())
from urllib.parse import urlparse
assert not any(p.get('isPartner') for p in places)
assert all(urlparse(p.get('sourceUrl','')).hostname in {'www.ibge.gov.br','www.openstreetmap.org','turismo.ma.gov.br','www.gov.br'} for p in places)
# Only public seeded coordinates are sent, never record IDs, names, remote partner records, or user positions.
out=base/'assets/data/elevations.json'
result=json.loads(out.read_text()) if out.exists() else {'dataset':'SRTM 1 arc-second','resolutionMeters':30,'verticalDatum':'EGM96','provider':'Open Topo Data','source':'https://www.opentopodata.org/datasets/srtm/','queriedAt':'2026-11-05','measurementEpoch':'2000','points':{}}
left=[p for p in places if p['id'] not in result['points']]
for i in range(0,len(left),90):
 batch=left[i:i+90]
 locations='|'.join(f"{p['lat']},{p['lng']}" for p in batch)
 req=urllib.request.Request('https://api.opentopodata.org/v1/srtm30m?locations='+locations+'&interpolation=bilinear',headers={'User-Agent':'MaraPass elevation data import'})
 for attempt in range(3):
  try:
   data=json.load(urllib.request.urlopen(req,timeout=40))
   assert data['status']=='OK' and len(data['results'])==len(batch)
   for p,r in zip(batch,data['results']):
    assert abs(r['location']['lat']-p['lat'])<1e-7 and abs(r['location']['lng']-p['lng'])<1e-7
    h=r['elevation'];assert h is None or (isinstance(h,(int,float)) and math.isfinite(h) and -500<h<9000)
    result['points'][p['id']]={'lat':p['lat'],'lng':p['lng'],'meters':h}
   out.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':')))
   print('Altitude consultada:',len(result['points']),'/',len(places),flush=True)
   break
  except Exception as e:
   print('Tentativa',attempt+1,type(e).__name__,flush=True)
   if attempt==2: raise
   time.sleep(3)
 time.sleep(1.1)
print('Altitudes disponíveis:',sum(p['meters'] is not None for p in result['points'].values()),flush=True)
