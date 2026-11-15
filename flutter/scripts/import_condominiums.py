"""Rebuild the optional OSM condominium layer. Requires shapely.
Usage: python flutter/scripts/import_condominiums.py docs/condominios/osm-source.json
Review the import date and exclusions before publishing a new snapshot.
"""
from pathlib import Path
import json,sys,math,unicodedata,hashlib,collections
from shapely.geometry import Point,shape
root=Path(__file__).resolve().parents[2];f=root/'flutter'
raw=json.load(open(sys.argv[1]));bound=f/'assets/map/municipalities.geojson';features=json.loads(bound.read_text())['features'];geoms=[(v['properties'],shape(v['geometry'])) for v in features]
areas={p['city']:p.get('area') for p in json.loads((f/'assets/data/places.json').read_text()) if p['cat']=='destination'}
def norm(s):return ''.join(c for c in unicodedata.normalize('NFKD',s.casefold()) if not unicodedata.combining(c))
def dist(a,b):return math.hypot((a['lat']-b['lat'])*111320,(a['lng']-b['lng'])*111320*math.cos(a['lat']*math.pi/180))
places=[];excluded=[];dups=[]
for e in sorted(raw['elements'],key=lambda e:({'relation':0,'way':1,'node':2}[e['type']],e['id'])):
 t=e['tags'];key=f"osm:{e['type']}:{e['id']}";name=t.get('name','').strip()
 if not name or any(k in t for k in ['highway','amenity','shop','office','tourism','construction','proposed','demolished','disused']) or not(t.get('landuse')=='residential' or t.get('building') in ['apartments','residential'] or t.get('residential')=='gated'):
  excluded.append(key);continue
 c=e if e['type']=='node' else e['center'];cities=[props for props,g in geoms if g.covers(Point(c['lon'],c['lat']))]
 if len(cities)!=1:excluded.append(key);continue
 city=cities[0];p={'id':key,'name':name,'city':city['name'],'municipalityId':city['id'],'area':areas.get(city['name']),'cat':'residential','lat':round(c['lat'],7),'lng':round(c['lon'],7),'sourceUrl':f"https://www.openstreetmap.org/{e['type']}/{e['id']}",'checkedAt':'2026-11-08','dataSource':'© OpenStreetMap contributors • importação, sem vistoria','referenceLocation':True,'isPartner':False,'offersFresh':False,'tags':'marapass:residential;condominio;acesso_privado;portaria_nao_verificada','description':'Referência residencial do OpenStreetMap, sem vistoria em campo. Existência, ocupação e portaria não foram verificadas. Acesso privado sujeito à autorização. Não indica hospedagem ou parceria MaraPass.','address':', '.join(t[k] for k in ['addr:street','addr:housenumber','addr:suburb'] if t.get(k)) or None}
 if any(old['city']==p['city'] and norm(old['name'])==norm(name) and dist(old,p)<=150 for old in places):dups.append(key);continue
 places.append(p)
meta={'schemaVersion':1,'importedAt':'2026-11-08','osmBaseTimestamp':raw['osm3s']['timestamp_osm_base'],'license':'ODbL-1.0','licenseUrl':'https://www.openstreetmap.org/copyright','coverage':'Parcial. Não é cadastro oficial nem vistoria de portarias.','rawCandidates':len(raw['elements']),'excluded':len(excluded),'duplicatesRemoved':len(dups),'countsByMunicipality':dict(collections.Counter(p['city'] for p in places)),'boundarySha256':hashlib.sha256(bound.read_bytes()).hexdigest(),'places':places}
(f/'assets/data/condominiums.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2));doc=root/'docs/condominios';doc.mkdir(parents=True,exist_ok=True)
(doc/'exclusoes.json').write_text(json.dumps({'excluded':excluded,'duplicates':dups}));
allowed={'name','landuse','residential','building','highway','amenity','shop','office','tourism','construction','proposed','demolished','disused','addr:street','addr:housenumber','addr:suburb'}
for e in raw['elements']:e['tags']={k:v for k,v in e['tags'].items() if k in allowed}
(doc/'osm-source.json').write_text(json.dumps(raw,ensure_ascii=False));print(len(places),meta['countsByMunicipality'])
