import json, math, urllib.request, concurrent.futures, hashlib, tempfile
from pathlib import Path
from io import BytesIO
import numpy as np
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1]
cache=Path(tempfile.gettempdir())/'marapass-terrain-tiles';cache.mkdir(exist_ok=True)
z=8;n=2**z
project=lambda lat,lng: ((lng+180)/360*n,(1-math.asinh(math.tan(math.radians(lat)))/math.pi)/2*n)
invlat=lambda y:math.degrees(math.atan(math.sinh(math.pi*(1-2*y/n))))
b=json.loads((root/'assets/map/maranhao.geojson').read_text())
rings=[]
for f in b['features']:
 g=f['geometry'];polys=g['coordinates'] if g['type']=='MultiPolygon' else [g['coordinates']]
 rings.extend(polys)
coords=[p for poly in rings for ring in poly for p in ring]
xs,ys=zip(*(project(p[1],p[0]) for p in coords))
x0,y0=math.floor(min(xs)),math.floor(min(ys));x1,y1=math.floor(max(xs)),math.floor(max(ys))
def fetch(xy):
 x,y=xy;p=cache/f'{z}-{x}-{y}.png';url=f'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'
 if not p.exists():p.write_bytes(urllib.request.urlopen(url,timeout=40).read())
 a=np.array(Image.open(p).convert('RGB'),dtype=np.float32)
 return x,y,a[:,:,0]*256+a[:,:,1]+a[:,:,2]/256-32768
size=((y1-y0+1)*256,(x1-x0+1)*256);dem=np.zeros(size,dtype=np.float32)
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
 for x,y,a in pool.map(fetch,[(x,y) for x in range(x0,x1+1) for y in range(y0,y1+1)]):dem[(y-y0)*256:(y-y0+1)*256,(x-x0)*256:(x-x0+1)*256]=a
mask=Image.new('L',(size[1],size[0]),0);draw=ImageDraw.Draw(mask)
for poly in rings:
 for i,ring in enumerate(poly):draw.polygon([((project(lat,lng)[0]-x0)*256,(project(lat,lng)[1]-y0)*256) for lng,lat,*_ in ring],fill=255 if i==0 else 0)
# Hypsometry is elevation, not a geomorphological landform classification.
levels=np.array([0,50,150,300,600,1000,1500]);colors=np.array([[216,236,230],[200,227,211],[217,231,186],[239,225,179],[222,197,164],[199,180,166],[235,230,225]])
rgb=np.stack([np.interp(dem,levels,colors[:,c]) for c in range(3)],axis=-1)
# A real, softly shaded DEM, in Web Mercator at z8 (~610 m at equator).
dy,dx=np.gradient(dem,611.5,611.5);shade=np.clip((.75-dx*.9+dy*.9),.45,1.0);rgb=rgb*(.90+.10*shade[:,:,None])
rgba=np.dstack([rgb,np.array(mask)]).astype('uint8');image=Image.fromarray(rgba,'RGBA')
out=root/'assets/map/terrain_ma.png';image.save(out,optimize=True)
metadata={'source':'Mapzen Terrain Tiles / USGS SRTM, GMTED2010','sourceUrl':'https://registry.opendata.aws/terrain-tiles/','attributionUrl':'https://github.com/tilezen/joerd/blob/master/docs/attribution.md','accessedAt':'2026-11-05','tileZoom':z,'pixelSpacingMetersApprox':612,'bounds':{'south':invlat(y1+1),'west':x0/n*360-180,'north':invlat(y0),'east':(x1+1)/n*360-180},'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'tileCount':len(list(cache.glob('*.png'))),'rendering':'Cores por altitude e sombreamento suave; máscara do Maranhão do IBGE. Uso regional, sem classificação de risco ou trilhas.'}
(root/'assets/data/terrain_manifest.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2))
print(json.dumps(metadata,ensure_ascii=False),flush=True)
