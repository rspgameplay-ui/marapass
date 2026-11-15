"""Regression of the production catalogue against the existing substring search."""
import json,pathlib,unittest,unicodedata,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[3]
def norm(s): return ''.join(c for c in unicodedata.normalize('NFD',s.lower()) if not unicodedata.combining(c))
def search(rows,q):
 return [r for r in rows if norm(q) in norm(' '.join(str(r.get(k) or '') for k in ['name','city','description','area','tags','address']))]
class Beaches(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.rows=json.loads((ROOT/'flutter/assets/data/places.json').read_text())
 def test_aracagy_variants_return_same_stable_beach(self):
  for q in ['Praia do Araçagy','Praia do Aracagy','Praia do Araçagi','praia de aracagy','praia aracaji','praia do arcagy']:
   with self.subTest(q=q):self.assertIn('osm:node:7700339990',[r['id'] for r in search(self.rows,q)])
 def test_names_and_known_spellings(self):
  for q,id_ in [('Praia de Atins','praia:atins'),('Praia do Cabure','cabure'),('Praia da Travosa','praia:travosa'),('Praia do Olho d’Água','osm:node:7700339991'),('Praia do Olho Dagua','osm:node:7700339991'),('Praia Olho de Porco','osm:node:8638253851'),('praia do calau','osm:node:7700339993')]:
   with self.subTest(q=q):self.assertIn(id_,[r['id'] for r in search(self.rows,q)])
 def test_all_beaches_nature_and_sourced(self):
  beaches=[r for r in self.rows if r.get('subcategory')=='praia'];self.assertEqual(len(beaches),43)
  for r in beaches:
   with self.subTest(id=r['id']):
    self.assertEqual(r['cat'],'nature');self.assertTrue(r['sourceUrl'].startswith('https://'));self.assertTrue(r['referenceLocation']);self.assertEqual(r['bathingStatus'],'não verificada');self.assertIsNone(r['hours']);self.assertTrue(-11<r['lat']<0);self.assertTrue(-49<r['lng']<-41)
 def test_existing_ids_and_unrelated_places_preserved(self):
  old=json.loads(subprocess.check_output(['git','show','2da825b9a1a040ed6b031a118cf026f4d9ff049d:flutter/assets/data/places.json'],cwd=ROOT));new={r['id']:r for r in self.rows}
  self.assertEqual(len(new),len(self.rows));self.assertTrue({r['id'] for r in old}<=set(new))
  for r in old:
   if not ((r['cat'] in ['nature','culture'] and norm(r['name']).startswith(('praia ','praia_'))) or r['id']=='cabure'):self.assertEqual(r,new[r['id']])
 def test_four_catalogues_identical(self):
  content=(ROOT/'flutter/assets/data/places.json').read_bytes()
  for f in ['dist/assets/assets/data/places.json','flutter/admin/data/places.json','dist/admin/data/places.json']:self.assertEqual((ROOT/f).read_bytes(),content)
 def test_fluvial_beaches_not_marked_coastal(self):
  for r in self.rows:
   if r.get('subcategory')=='praia' and r['city'] in ['Imperatriz','Nina Rodrigues','Timbiras']:self.assertEqual(r['beachType'],'fluvial');self.assertNotIn('Litoral do Maranhão',r['tags'])
unittest.main()
