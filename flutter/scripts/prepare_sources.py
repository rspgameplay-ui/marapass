"""Fetch public source snapshots for a manual catalogue rebuild, not app startup.
Run: python scripts/prepare_sources.py <empty-or-existing-source-directory>
Then install pyshp, pyproj, shapely and run import_maranhao.py.
Existing downloads are reused; there is no automated retry loop.
"""
from pathlib import Path
from urllib.request import Request,urlopen
from urllib.parse import urlencode
import sys,zipfile,json
root=Path(sys.argv[1]);root.mkdir(exist_ok=True,parents=True)
headers={'User-Agent':'MaraPass/0.2 (+https://marapass.com)'}
urls={
 'ibge_localities.zip':'https://geoftp.ibge.gov.br/organizacao_do_territorio/estrutura_territorial/localidades/Localidades_do_Brasil/2022/Localidades_Brasil_gpkg.zip',
 'MA_Municipios_2025.zip':'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2025/UFs/MA/MA_Municipios_2025.zip',
}
for filename,url in urls.items():
 p=root/filename
 if not p.exists():p.write_bytes(urlopen(Request(url,headers=headers),timeout=90).read())
 with zipfile.ZipFile(p) as z:
  for name in z.namelist():
   if name.endswith('.gpkg'):(root/'ibge_localities.gpkg').write_bytes(z.read(name))
   elif name.split('.')[-1] in {'shp','shx','dbf','cpg','prj'}:(root/Path(name).name).write_bytes(z.read(name))
p=root/'osm_maranhao.json'
if not p.exists():
 query=Path(__file__).with_name('maranhao_pois.overpass').read_text()
 request=Request('https://overpass-api.de/api/interpreter',data=urlencode({'data':query}).encode(),headers={**headers,'Content-Type':'application/x-www-form-urlencoded'})
 raw=urlopen(request,timeout=85).read();data=json.loads(raw)
 if data.get('remark'):raise RuntimeError(data['remark'])
 p.write_bytes(raw)
print('Sources prepared. A new OSM snapshot requires a fresh coverage audit and updated import dates.')
