"""Build the reviewed island supplement from focused OSM API full JSON files.
Usage: python build_coastal_islands.py <directory>
No runtime API, user positions, or private partner data are used.
"""
import json,sys,unicodedata
from pathlib import Path
from shapely.geometry import shape,Point,Polygon,LineString
from shapely.ops import unary_union,polygonize
from shapely import make_valid
root=Path(__file__).resolve().parents[1];cache=Path(sys.argv[1])
mun=[(f['properties'],shape(f['geometry'])) for f in json.loads((root/'assets/map/municipalities.geojson').read_text())['features']];land=unary_union([g for _,g in mun]);seed={p['id']:p for p in json.loads((root/'assets/data/places.json').read_text())}
ufma='https://portais.ufma.br/PortalUfma/paginas/noticias/noticia.jsf?id=8064'
icmbio='https://www.gov.br/icmbio/pt-br/assuntos/unidade-de-conservacao/unidades-de-biomas/marinho/lista-de-ucs/apa-delta-do-parnaiba/informacoes-sobre-visitacao-apa-delta-do-parnaiba/area-de-protecao-ambiental-delta-do-parnaiba'
records={};pending=[]
for file in sorted(cache.glob('*.json')):
 if file.name=='islands.json':continue
 kind,id=file.stem.split('-');id=int(id)
 if id in [13399891,10269983,10269986]:continue
 es=json.loads(file.read_text())['elements'];entity=next(e for e in es if e['type']==kind and e['id']==id);tags=entity.get('tags',{});name=tags.get('name','')
 if not name:continue
 nodes={e['id']:(e['lon'],e['lat']) for e in es if e['type']=='node'};ways={e['id']:[nodes[n] for n in e['nodes'] if n in nodes] for e in es if e['type']=='way'};g=None
 if kind=='way':
  pts=ways[id]
  if len(pts)>3 and pts[0]==pts[-1]:g=make_valid(Polygon(pts))
 elif kind=='relation':
  lines={'outer':[],'inner':[]}
  for m in entity['members']:
   pts=ways.get(m['ref'],[]) if m['type']=='way' else []
   if len(pts)>1:lines['inner' if m.get('role')=='inner' else 'outer'].append(LineString(pts))
  a=unary_union(list(polygonize(unary_union(lines['outer']))));b=unary_union(list(polygonize(unary_union(lines['inner']))));g=make_valid(a.difference(b)) if not a.is_empty else None
 rings=[]
 if g is not None and not g.is_empty and g.area>0:
  if g.intersection(land).area/g.area<.5:pending.append({'name':name,'reason':'Sobreposição territorial insuficiente no Maranhão.'});continue
  polys=[g] if g.geom_type=='Polygon' else [x for x in g.geoms if x.geom_type=='Polygon']
  if not polys:continue
  pt=max(polys,key=lambda x:x.area).representative_point()
  for poly in polys:
   poly=poly.simplify(.00025,preserve_topology=True)
   rings.append([[round(x,7),round(y,7)] for x,y in poly.exterior.coords])
   rings.extend([[[round(x,7),round(y,7)] for x,y in r.coords] for r in poly.interiors])
  method='Ponto interno do contorno OpenStreetMap. Contorno simplificado para visualização; não indica acesso.'
 elif kind=='node':pt=Point(entity['lon'],entity['lat']);method='Ponto de referência OpenStreetMap, sem contorno individual importado.'
 else:pending.append({'name':name,'reason':'Geometria incompleta ou não validada; sem marcador inventado.'});continue
 hits=[p for p,m in mun if m.covers(pt)]
 if not hits:pending.append({'name':name,'reason':'Sem associação municipal inequívoca.'});continue
 city=hits[0];source=f'https://www.openstreetmap.org/{kind}/{id}';sources=[source];alias=[s.strip() for s in tags.get('alt_name','').split(';') if s.strip()];key=f'osm:{kind}:{id}'
 if id==10037013:name='Ilha de São Luís (Upaon-Açu)';alias+=['Ilha do Maranhão','Upaon-Açu','Upaon Açu','Upaon Acu','Ilha de São Luís','Ilha São Luís','São José de Ribamar','Paço do Lumiar','Raposa'];sources+=['https://agem.ma.gov.br/programas-ou-campanhas/mapas-grande-ilha']
 if id in [34963565,34963566]:key='ilha-lencois';name='Ilha dos Lençóis';alias+=['Ilha de Lençóis','Ilha de Lençol'];sources+=[ufma]
 if id==46424281:key='osm:node:1181476027'
 if id==11152282:alias+=['Ilha de Maiaú','Ilha de São João','Bate-Vento'];sources+=[ufma]
 if id==11149871:alias+=['São Lucas','Peru','Boa Vista'];sources+=[ufma]
 if id==9632514:alias+=['Tauá Mirim','Ilha de Tauá-Mirim']
 if id==10270258:sources+=['https://www.ssp.ma.gov.br/comando-da-pm-realiza-reuniao-com-moradores-da-ilha-de-carrapatal-no-municipio-de-humberto-de-campos/']
 if id==9485488:sources+=[icmbio]
 if city['name']=='Cururupu':alias+=['Arquipélago de Maiaú']
 if city['name'] in ['Tutóia','Araioses','Água Doce do Maranhão','Paulino Neves']:region='Delta das Américas';area=region
 elif pt.x < -44.65 and city['name'] not in ['Cajapió','Alcântara']:region='Reentrâncias Maranhenses';area='Floresta dos Guarás'
 elif city['name'] in ['Icatu','Humberto de Campos','Primeira Cruz','Barreirinhas','Presidente Juscelino','Cachoeira Grande']:region='Lençóis e baía de Tubarão';area='Lençóis Maranhenses'
 else:region='Golfão Maranhense';area='São Luís e Alcântara'
 old=seed.get(key,{});lat=old.get('lat',round(pt.y,7));lng=old.get('lng',round(pt.x,7));note=method
 if old:note='Marcador anterior do MaraPass preservado; os contornos OSM não validam o ponto de desembarque em campo.'
 if key=='ilha-lencois':note+=' A extração contém dois contornos com o topônimo Lençóis, sujeitos à conferência local.'
 tokens=['marapass:coastal_island','ilha','ilhas','litoral',name,*alias,region]
 if id==10037013:tokens += ['municipio:'+c for c in ['São Luís','São José de Ribamar','Paço do Lumiar','Raposa']]
 place={**old,'id':key,'name':name,'city':city['name'],'municipalityId':city['id'],'lat':lat,'lng':lng,'cat':'nature','area':area,'description':(old.get('description','')+' ' if old else '')+f'Referência insular no setor {region}. O marcador não representa porto, estacionamento ou desembarque. Confirme acesso, visita e retorno com a comunidade ou prestador local.','sourceUrl':source,'dataSource':'OpenStreetMap / IBGE • catálogo insular','checkedAt':'2026-11-05','referenceLocation':True,'isPartner':False,'tags':';'.join(tokens)}
 entry={'place':place,'region':region,'aliases':list(dict.fromkeys(alias)),'sources':list(dict.fromkeys(sources)),'rings':rings,'note':note,'osmVersion':entity.get('version'),'osmTimestamp':entity.get('timestamp')}
 if key in records:records[key]['rings']+=rings;records[key]['sources']=list(dict.fromkeys(records[key]['sources']+sources))
 else:records[key]=entry
source='https://mapcarta.com/pt/Ilha_das_Can%C3%A1rias'
records['geonames:3403422']={'place':{'id':'geonames:3403422','name':'Ilha das Canárias','city':'Araioses','municipalityId':'2100907','lat':-2.7603,'lng':-41.9045,'cat':'nature','area':'Delta das Américas','description':'Ilha do Delta do Parnaíba citada pelo ICMBio entre os atrativos de Araioses. Referência de localização; confirme embarque, visita e retorno com prestadores locais.','sourceUrl':source,'dataSource':'GeoNames via Mapcarta (referência) / ICMBio (conteúdo)','checkedAt':'2026-11-05','referenceLocation':True,'isPartner':False,'tags':'marapass:coastal_island;ilha;ilhas;Canárias;Canarias;Delta'},'region':'Delta das Américas','aliases':['Ilha das Canarias','Ilhas Canárias'],'sources':[source,icmbio],'rings':[],'note':'Ponto de referência GeoNames 3403422 via Mapcarta. Contorno individual não importado; não é desembarque.'}
# Existing named tourist island in Tutóia: preserve its original point and ID.
key='osm:node:7105692035'
if key in seed:
 old=seed[key];records[key]={'place':{**old,'tags':';'.join([old.get('tags',''),'marapass:coastal_island','ilha','ilhas','litoral']),'referenceLocation':True,'checkedAt':'2026-11-05'},'region':'Delta das Américas','aliases':[],'sources':[old['sourceUrl']],'rings':[],'note':'Marcador anterior do MaraPass preservado; sem contorno individual ou desembarque validado.'}
items=sorted(records.values(),key=lambda e:(e['place']['id']!='osm:relation:10037013',unicodedata.normalize('NFKD',e['place']['name'])))
result={'checkedAt':'2026-11-05','inventoryComplete':False,'license':'OpenStreetMap © contributors / ODbL; GeoNames CC BY (Canárias); IBGE','originalSeedRecords':4217,'islandReferences':len(items),'newIslandRecords':sum(i['place']['id'] not in seed for i in items),'reusedOriginalIds':[i['place']['id'] for i in items if i['place']['id'] in seed],'islands':items,'pending':pending+[{'name':'Ilha Cangatá / São Lucas','reason':'Topônimo duplicado ou comunidade; identidade insular pendente.'}]}
(root/'assets/data/coastal_islands.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':')))
print('References:',len(items),'outlines:',sum(bool(i['rings']) for i in items),'new:',result['newIslandRecords'],'pending:',len(pending))
