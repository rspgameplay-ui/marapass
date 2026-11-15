"""Build MaraPass palettes from the licensed OpenFreeMap Liberty style.
Usage: python scripts/prepare_map_styles.py /path/to/openfreemap-styles/styles/liberty/style.json
Geometry and attribution remain upstream; no coast is invented or smoothed.
"""
import json,sys,copy
from pathlib import Path
base=json.loads(Path(sys.argv[1]).read_text().replace('__TILEJSON_DOMAIN__','tiles.openfreemap.org'))
root=Path(__file__).resolve().parents[1]
for night in (False,True):
 s=copy.deepcopy(base);s['name']='MaraPass Terra '+('Noite' if night else 'Dia')
 s['sources'].pop('ne2_shaded',None)
 layers=[]
 for l in s['layers']:
  name=l['id'].lower();source=l.get('source-layer','');kind=l['type']
  if kind=='raster' or source in ('poi','housenumber') or 'shield' in name: continue
  paint=l.setdefault('paint',{});layout=l.setdefault('layout',{})
  if kind=='background':paint['background-color']='#1d292e' if night else '#f3f0e9'
  elif kind=='fill':
   color=('#243e47' if night else '#d5e5e4') if 'water' in name else ('#293b35' if night else '#e2e8d8') if any(x in name for x in ('wood','park','grass','forest')) else ('#38403b' if night else '#e9e2d4') if 'building' in name else ('#293535' if night else '#eeeade')
   paint['fill-color']=color
   if 'fill-outline-color' in paint:paint['fill-outline-color']=color
  elif kind=='line':
   if source=='boundary' or 'boundary' in name:
    paint.update({'line-color':'#78837d' if night else '#aaa99a','line-width':.6,'line-opacity':.28});l['minzoom']=7
   elif 'water' in name:paint['line-color']='#34505a' if night else '#b9d7d7'
   else:paint['line-color']=('#43504f' if night else '#d3d0c5') if 'casing' in name else ('#69706a' if night else '#e7d6b5') if any(x in name for x in ('motorway','trunk','primary')) else ('#4a5857' if night else '#ffffff')
  elif kind=='symbol':
   if 'text-field' not in layout:continue
   layout.pop('icon-image',None);layout['text-font']=['MaraSans']
   paint['text-color']='#c4cfcc' if night else '#59665f';paint['text-halo-color']='#253235' if night else '#f3f0e9';paint['text-halo-width']=1
   if source in ('transportation_name',):l['minzoom']=max(13,l.get('minzoom',0))
   if any(x in name for x in ('village','suburb','neighbourhood')):l['minzoom']=max(11,l.get('minzoom',0))
  layers.append(l)
 s['layers']=layers
 (root/'assets/map'/('style_night.json' if night else 'style_day.json')).write_text(json.dumps(s,ensure_ascii=False,separators=(',',':')))
license=Path(sys.argv[1]).parent/'LICENSE.md'
(root/'assets/map/OpenFreeMap_STYLE_LICENSE.md').write_text(license.read_text())
print('Generated day/night styles from licensed geometry.')
