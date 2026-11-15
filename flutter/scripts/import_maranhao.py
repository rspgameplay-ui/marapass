"""Build dated, attributed map data from IBGE and OSM extracts.
Usage: PYTHONPATH=<shapely+pyproj+pyshp> python scripts/import_maranhao.py <source-dir>
No provider data is fetched at application startup; no private contacts are read.
"""
from pathlib import Path
import sys,json,sqlite3,unicodedata,hashlib
from collections import Counter
import shapefile
from pyproj import Transformer
from shapely.geometry import shape,Point,mapping
from shapely.ops import transform,unary_union

source=Path(sys.argv[1]);root=Path(__file__).resolve().parents[1]
base=json.loads((root/'assets/data/places.json').read_text())
# Preserve previous destination IDs so existing favourites and local overrides survive.
old_cities={p['city']:p for p in base if p['cat']=='destination'}
old_attractions=[p for p in base if p['cat']!='destination' and not p['id'].startswith('osm:')]
reader=shapefile.Reader(str(source/'MA_Municipios_2025.shp'),encoding='utf-8')
transformer=Transformer.from_crs(4674,4326,always_xy=True)
geometries={};records={}
for s in reader.iterShapeRecords():
    r=s.record.as_dict();code=r['CD_MUN'];records[code]=r
    geometries[code]=transform(transformer.transform,shape(s.shape.__geo_interface__))
assert len(records)==217
conn=sqlite3.connect(source/'ibge_localities.gpkg');conn.row_factory=sqlite3.Row
rows=conn.execute("select * from BR_localidades_2022 where CD_UF='21' and CT_LOCALIDADE='Cidade' order by case when SCT_LOCALIDADE='Capital Estadual' then 0 else 1 end").fetchall()
seats={}
for row in rows: seats.setdefault(row['CD_MUN'],row)
assert set(seats)==set(records)
municipalities=[];places=[]
ibge_url='https://www.ibge.gov.br/geociencias/organizacao-do-territorio/tipologias-do-territorio/27385-localidades.html'
for code,r in sorted(records.items(),key=lambda pair:pair[1]['NM_MUN']):
    seat=seats[code];lng,lat=transformer.transform(seat['LONG_LOCALIDADE'],seat['LAT_LOCALIDADE'])
    bounds=geometries[code].bounds
    municipalities.append({'id':code,'name':r['NM_MUN'],'lat':round(lat,7),'lng':round(lng,7),'bounds':[bounds[1],bounds[0],bounds[3],bounds[2]],'region':r['NM_RGI'],'intermediateRegion':r['NM_RGINT'],'areaKm2':r['AREA_KM2'],'sourceUrl':ibge_url})
    previous=old_cities.get(r['NM_MUN'],{})
    places.append({'id':previous.get('id','ibge:'+code),'name':r['NM_MUN'],'city':r['NM_MUN'],'cat':'destination','lat':round(lat,7),'lng':round(lng,7),'municipalityId':code,'area':previous.get('area'),
      'description':f"Município do Maranhão, código IBGE {code}. Integra a Região Geográfica Imediata de {r['NM_RGI']}. O marcador corresponde à sede municipal na base de Localidades do Brasil (Censo 2022), publicada pelo IBGE em 2025; não indica uma entrada de atrativo.",
      'sourceUrl':ibge_url,'dataSource':'IBGE • Localidades 2022 / Malha 2025','checkedAt':'2026-10-30','referenceLocation':True})
raw=json.loads((source/'osm_maranhao.json').read_text());bycode=Counter();skipped=[]
labels={'restaurant':'Restaurante','cafe':'Café','fast_food':'Lanchonete','food_court':'Praça de alimentação','bar':'Bar','fuel':'Posto de combustível','pharmacy':'Farmácia','hospital':'Hospital','bus_station':'Terminal rodoviário','ferry_terminal':'Terminal de travessia','marketplace':'Mercado','atm':'Caixa eletrônico','bank':'Banco','attraction':'Atrativo','museum':'Museu','viewpoint':'Mirante','zoo':'Zoológico','theme_park':'Parque temático','gallery':'Galeria','hotel':'Hotel','guest_house':'Pousada','hostel':'Hostel','camp_site':'Camping','information':'Informação turística','monument':'Monumento','memorial':'Memorial','fort':'Forte','ruins':'Ruínas','archaeological_site':'Sítio arqueológico','beach':'Praia','waterfall':'Cachoeira','craft':'Artesanato','art':'Arte','souvenir':'Lembranças'}
normal=lambda s: ''.join(c for c in unicodedata.normalize('NFD',s.lower()) if unicodedata.category(c)!='Mn')
polygons=[(code,g,g.bounds) for code,g in geometries.items()]
for e in raw['elements']:
    t=e.get('tags',{});center=e.get('center',e);lat=center.get('lat');lng=center.get('lon')
    if lat is None or lng is None or not t.get('name'):skipped.append(e['id']);continue
    point=Point(lng,lat)
    matches=[code for code,g,b in polygons if b[0]<=lng<=b[2] and b[1]<=lat<=b[3] and g.covers(point)]
    if len(matches)!=1:skipped.append(e['id']);continue
    code=matches[0];city=records[code]['NM_MUN'];amenity=t.get('amenity');tourism=t.get('tourism');subtype=tourism or amenity or t.get('historic') or t.get('natural') or t.get('waterway') or t.get('shop')
    cat='culture'
    if amenity in {'restaurant','cafe','fast_food','food_court','bar','marketplace'}:cat='gastronomy'
    elif amenity in {'bus_station','ferry_terminal'}:cat='tourist_transport'
    elif amenity in {'fuel','pharmacy','hospital','atm','bank'}:cat='services'
    elif tourism in {'hotel','guest_house','hostel','camp_site'}:cat='lodging'
    elif tourism=='information':cat='tours'
    elif tourism in {'viewpoint','zoo','theme_park'} or subtype in {'beach','waterfall'}:cat='nature'
    elif tourism=='attraction':cat='nature' if t.get('natural') or t.get('waterway') else 'culture'
    elif t.get('shop') in {'craft','art','souvenir'}:cat='crafts'
    address=', '.join(filter(None,[t.get('addr:street'),t.get('addr:housenumber'),t.get('addr:suburb'),t.get('addr:postcode')]))
    phone=t.get('contact:phone') or t.get('phone');website=t.get('contact:website') or t.get('website')
    if website and not website.startswith(('http://','https://')):website=None
    p={'id':f"osm:{e['type']}:{e['id']}",'name':t['name'],'city':city,'municipalityId':code,'cat':cat,'lat':lat,'lng':lng,
       'description':f"{labels.get(subtype,'Ponto de interesse')} mapeado no OpenStreetMap em {city}. Informações colaborativas; confirme funcionamento e acesso com o estabelecimento ou responsável.",
       'address':address or None,'phone':phone,'website':website,'hours':t.get('opening_hours'),
       'tags':', '.join(filter(None,[labels.get(subtype),t.get('cuisine'),t.get('wheelchair') and 'Acessibilidade informada na fonte',t.get('operator')])),
       'sourceUrl':f"https://www.openstreetmap.org/{e['type']}/{e['id']}",'dataSource':'OpenStreetMap • ODbL','checkedAt':'2026-10-30',
       'osmUpdatedAt':e.get('timestamp'),'osmVersion':e.get('version'),'referenceLocation':True,'isPartner':False}
    places.append(p);bycode[code]+=1
# Previous approximate editorial points are kept only when not duplicated by a nearby named source.
for p in old_attractions:
    code=next((c for c,r in records.items() if r['NM_MUN']==p['city']),None)
    duplicate=any(q['city']==p['city'] and (normal(p['name']) in normal(q['name']) or normal(q['name']) in normal(p['name'])) and abs(p['lat']-q['lat'])<.03 and abs(p['lng']-q['lng'])<.03 for q in places if q['cat']!='destination')
    if not duplicate:places.append({**p,'municipalityId':code,'dataSource':'MaraPass • referência editorial anterior','referenceLocation':True})
for city in municipalities:city['mappedPlaces']=bycode[city['id']]
output=root/'assets/data';output.mkdir(exist_ok=True)
(output/'municipalities.json').write_text(json.dumps(municipalities,ensure_ascii=False,separators=(',',':')))
(output/'places.json').write_text(json.dumps(places,ensure_ascii=False,separators=(',',':')))
# Display geometry is simplified only after assignment against original 2025 polygons.
features=[{'type':'Feature','properties':{'id':code,'name':records[code]['NM_MUN']},'geometry':mapping(g.simplify(.002,preserve_topology=True))} for code,g in geometries.items()]
(root/'assets/map/municipalities.geojson').write_text(json.dumps({'type':'FeatureCollection','features':features},ensure_ascii=False,separators=(',',':')))
state=unary_union(list(geometries.values())).simplify(.002,preserve_topology=True)
(root/'assets/map/maranhao.geojson').write_text(json.dumps({'type':'FeatureCollection','features':[{'type':'Feature','properties':{'source':'IBGE • Malha Municipal 2025','crs':'EPSG:4326','displaySimplificationDegrees':.002},'geometry':mapping(state)}]},ensure_ascii=False,separators=(',',':')))
manifest={'municipalities':len(municipalities),'osmExtracted':len(raw['elements']),'osmAssigned':sum(bycode.values()),'excludedWithoutUniqueMunicipality':len(skipped),'totalPlaces':len(places),'citiesWithOsmPlaces':sum(v>0 for v in bycode.values()),'osmBaseTimestamp':raw['osm3s']['timestamp_osm_base'],'importedAt':'2026-10-30','categories':dict(Counter(p['cat'] for p in places)),'sources':{'localities':ibge_url,'municipalBoundaries':'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2025/UFs/MA/MA_Municipios_2025.zip','osm':'https://www.openstreetmap.org/copyright'},'sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [source/'ibge_localities.zip',source/'MA_Municipios_2025.zip',source/'osm_maranhao.json']}}
(output/'source_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
print(json.dumps(manifest,ensure_ascii=False,indent=2))
