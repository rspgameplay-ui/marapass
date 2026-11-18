/* Gravuras de cultura maranhense e nordestina, em estilo de xilogravura/cordel e azulejo.
   São SVGs pequenos (sem arquivos externos) desenhados no mapa como ilustrações,
   visíveis só com o mapa afastado. Na navegação (zoom alto) somem e não atrapalham. */
import type {Map as LibreMap} from 'maplibre-gl';

const INK = '#2a1a10', PAPER = '#f3e2b8', SUN = '#e8a63a', RED = '#b5432a', BLUE = '#1f4e9c';
const S = `stroke="${INK}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"`;

const SW = (w: number) =>
  `stroke="${INK}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"`;

const art: Record<string, string> = {
  /* Lençóis Maranhenses: sol e dunas */
  dunas: `<circle cx="48" cy="34" r="13" fill="${SUN}" ${S}/>
    ${[0, 45, 90, 135, 180, 225, 270, 315].map(a =>
      `<line x1="48" y1="12" x2="48" y2="18" transform="rotate(${a} 48 34)" ${S}/>`).join('')}
    <path d="M4 82Q24 54 46 74T92 64V92H4Z" fill="${PAPER}" ${S}/>
    <path d="M14 84h24M30 77h20M58 80h24M66 72h16" ${SW(2)}/>`,
  /* Jangada de vela, litoral do Maranhão */
  jangada: `<path d="M50 10V68" ${S}/>
    <path d="M48 14L20 62H48Z" fill="${PAPER}" ${S}/>
    <path d="M52 22L76 62H52Z" fill="${RED}" ${S}/>
    <path d="M8 66H88L78 80H18Z" fill="${INK}"/>
    <path d="M4 88q6-7 12 0t12 0 12 0 12 0 12 0 12 0 12 0" fill="none" stroke="${BLUE}" stroke-width="4" stroke-linecap="round"/>`,
  /* Palmeira de buriti, Chapada das Mesas / Cerrado */
  buriti: `<path d="M45 92L48 42H52L55 92Z" fill="${INK}"/>
    <path d="M50 42Q20 18 6 46M50 42Q28 34 14 62M50 42Q38 14 28 10M50 42Q62 14 72 10M50 42Q72 34 86 62M50 42Q80 18 94 46M50 42V8"
      fill="none" ${SW(4)}/>
    <circle cx="50" cy="44" r="5" fill="${SUN}" ${SW(2)}/>`,
  /* Bumba meu boi */
  boi: `<path d="M16 52Q16 36 34 34H70Q84 34 84 48V66H74V84H64V66H38V84H28V66H18Z" fill="${INK}"/>
    <path d="M30 34H76V58H30Z" fill="${BLUE}" stroke="${PAPER}" stroke-width="2.5"/>
    <path d="M53 40l3 7h7l-5.5 4.5 2 7L53 54l-5.500 4.500 2-7L44 47h7Z" fill="${SUN}"/>
    <path d="M18 44Q4 40 6 24M24 40Q16 28 24 18" fill="none" ${SW(4)}/>
    <circle cx="22" cy="48" r="2.500" fill="${PAPER}"/>
    <path d="M84 44q8-2 8 10" fill="none" ${S}/>`,
  /* Casarão de azulejos, São Luís */
  casarao: `<path d="M8 36L48 14L88 36Z" fill="${RED}" ${S}/>
    <rect x="14" y="36" width="68" height="52" fill="${PAPER}" ${S}/>
    <rect x="14" y="36" width="68" height="12" fill="${BLUE}" ${S}/>
    ${[22, 34, 46, 58, 70].map(x => `<path d="M${x} 42l4-4 4 4-4 4Z" fill="${PAPER}"/>`).join('')}
    ${[22, 42, 62].map(x => `<path d="M${x} 80V62a6 6 0 0 1 12 0V80Z" fill="${INK}"/>`).join('')}
    <path d="M14 88H82" ${S}/>`,
  /* Folheto de cordel com xilogravura */
  cordel: `<rect x="22" y="10" width="52" height="76" rx="4" fill="${PAPER}" ${S}/>
    <rect x="29" y="17" width="38" height="28" fill="${INK}"/>
    <path d="M48 21l3 7h7l-5.500 4.500 2 7L48 35l-5.500 4.500 2-7L39 28h7Z" fill="${SUN}"/>
    <path d="M29 54h38M29 61h38M29 68h30M29 75h22" ${SW(2.500)}/>`,
  /* Sanfona do forró */
  sanfona: `<rect x="12" y="26" width="16" height="44" rx="4" fill="${RED}" ${S}/>
    <rect x="68" y="26" width="16" height="44" rx="4" fill="${RED}" ${S}/>
    <path d="M28 30H68V66H28Z" fill="${PAPER}" ${S}/>
    ${[36, 44, 52, 60].map(x => `<path d="M${x} 30V66" ${SW(2.500)}/>`).join('')}
    ${[36, 48, 60].map(y => `<circle cx="20" cy="${y}" r="3" fill="${PAPER}"/>`).join('')}
    <path d="M8 74H88" ${S}/>`,
  /* Mandacaru / sertão */
  mandacaru: `<path d="M44 92V30a6 6 0 0 1 12 0V92Z" fill="${INK}"/>
    <path d="M44 66H30a6 6 0 0 1-6-6V44a5 5 0 0 1 10 0V54H44ZM56 58H70a6 6 0 0 0 6-6V36a5 5 0 0 0-10 0V46H56Z" fill="${INK}"/>
    <path d="M50 38v44M32 48v10M70 40v10" stroke="${PAPER}" stroke-width="2" stroke-dasharray="3 5"/>
    <circle cx="50" cy="22" r="5" fill="${RED}" ${SW(2)}/>`,
};

/* Figuras soltas, só decoração. */
export const GRAVURAS: {id: keyof typeof art; at: [number, number]}[] = [
  {id: 'jangada', at: [-42.30, -2.72]},
  {id: 'jangada', at: [-44.62, -2.28]},
  {id: 'dunas', at: [-42.60, -2.95]},
  {id: 'buriti', at: [-45.60, -6.20]},
  {id: 'buriti', at: [-46.20, -5.30]},
  {id: 'mandacaru', at: [-42.80, -5.70]},
  {id: 'mandacaru', at: [-44.40, -5.00]},
  {id: 'sanfona', at: [-43.90, -4.20]},
  {id: 'cordel', at: [-45.30, -4.00]},
  {id: 'boi', at: [-43.60, -3.40]},
];

/* Insígnias: medalhão com figura e o nome do lugar. Ficam visíveis até a vista de bairro. */
export const INSIGNIAS: {id: keyof typeof art; name: string; at: [number, number]}[] = [
  {id: 'dunas', name: 'Lençóis Maranhenses', at: [-43.05, -2.57]},
  {id: 'casarao', name: 'Centro Histórico', at: [-44.303, -2.529]},
  {id: 'casarao', name: 'Alcântara', at: [-44.413, -2.408]},
  {id: 'boi', name: 'Bumba meu boi', at: [-44.06, -2.57]},
  {id: 'jangada', name: 'Delta do Parnaíba', at: [-42.80, -2.80]},
  {id: 'buriti', name: 'Chapada das Mesas', at: [-47.20, -7.10]},
  {id: 'mandacaru', name: 'Sertão de Caxias', at: [-43.36, -4.86]},
  {id: 'cordel', name: 'Cordel', at: [-44.85, -3.60]},
  {id: 'sanfona', name: 'Forró', at: [-43.90, -4.30]},
];

const RING: Record<string, string> = {dunas: SUN, casarao: BLUE, boi: RED, jangada: BLUE, buriti: '#4f7a2c',
  mandacaru: '#4f7a2c', cordel: RED, sanfona: RED};

function medallion(id: string): string {
  const c = RING[id] ?? BLUE;
  return `<circle cx="48" cy="48" r="45" fill="${INK}"/>
    <circle cx="48" cy="48" r="41" fill="${c}"/>
    <circle cx="48" cy="48" r="35" fill="${PAPER}" stroke="${INK}" stroke-width="2"/>
    ${Array.from({length: 24}, (_, i) =>
      `<circle cx="48" cy="9" r="1.800" fill="${PAPER}" transform="rotate(${i * 15} 48 48)"/>`).join('')}
    <g transform="translate(19 18) scale(.6)">${art[id]}</g>`;
}

function load(svg: string): Promise<HTMLImageElement> {
  const src = 'data:image/svg+xml;charset=utf-8,' +
    encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">${svg}</svg>`);
  return new Promise((resolve, reject) => {
    const img = new Image(96, 96);
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = src;
  });
}

/* Registra as imagens e as camadas. Falhas aqui nunca derrubam o mapa. */
export async function addGravuras(map: LibreMap) {
  try {
    for (const [name, svg] of Object.entries(art)) {
      if (!map.hasImage('g-' + name)) map.addImage('g-' + name, await load(svg), {pixelRatio: 2});
      if (!map.hasImage('m-' + name)) map.addImage('m-' + name, await load(medallion(name)), {pixelRatio: 2});
    }
    map.addSource('gravuras', {type: 'geojson', data: {type: 'FeatureCollection',
      features: GRAVURAS.map(g => ({type: 'Feature', properties: {img: 'g-' + g.id},
        geometry: {type: 'Point', coordinates: g.at}}))}});
    map.addLayer({id: 'gravuras', type: 'symbol', source: 'gravuras', minzoom: 5, maxzoom: 12.5,
      layout: {'icon-image': ['get', 'img'], 'icon-allow-overlap': true, 'icon-ignore-placement': true,
        'icon-size': ['interpolate', ['linear'], ['zoom'], 5, .55, 11, .8]},
      paint: {'icon-opacity': ['interpolate', ['linear'], ['zoom'], 5, .75, 11, .75, 12.5, 0]}});
    map.addSource('insignias', {type: 'geojson', data: {type: 'FeatureCollection',
      features: INSIGNIAS.map(g => ({type: 'Feature', properties: {img: 'm-' + g.id, name: g.name},
        geometry: {type: 'Point', coordinates: g.at}}))}});
    map.addLayer({id: 'insignias', type: 'symbol', source: 'insignias', minzoom: 5, maxzoom: 16.2,
      layout: {'icon-image': ['get', 'img'], 'icon-allow-overlap': true, 'icon-ignore-placement': true,
        'icon-size': ['interpolate', ['linear'], ['zoom'], 5, .6, 10, .85, 15, 1.05],
        'text-field': ['get', 'name'], 'text-font': ['Noto Sans Regular'], 'text-size': 12,
        'text-anchor': 'top', 'text-offset': [0, 2], 'text-optional': true},
      paint: {'icon-opacity': ['interpolate', ['linear'], ['zoom'], 14.5, 1, 16.2, 0],
        'text-color': INK, 'text-halo-color': PAPER, 'text-halo-width': 2,
        'text-opacity': ['interpolate', ['linear'], ['zoom'], 14.5, 1, 16.2, 0]}});
  } catch (e) { console.error("gravuras", e); }
}
