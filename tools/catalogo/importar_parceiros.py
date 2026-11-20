"""Importa a planilha de parceiros do cliente para o catálogo do app.

Uso:
  python tools/catalogo/importar_parceiros.py modelo  [saida.xlsx]
      gera a planilha modelo para o cliente preencher.
  python tools/catalogo/importar_parceiros.py importar planilha.xlsx [--fotos pasta]
      confere a planilha e gera:
        flutter/lib/mvp/data/content_importado.dart  (itens do catálogo)
        supabase/seed/horarios_importados.sql        (turnos e vagas)
      Fotos: link https na coluna "foto", ou o nome de um arquivo .jpg da
      pasta --fotos (copiado para flutter/assets/photos/imp_<id>.jpg).

Nada é enviado ao banco: o SQL é aplicado à parte, depois de revisado.
"""
from __future__ import annotations

import re
import shutil
import sys
import unicodedata
from pathlib import Path

from openpyxl import Workbook, load_workbook
from openpyxl.styles import Font, PatternFill
from openpyxl.worksheet.datavalidation import DataValidation

ROOT = Path(__file__).resolve().parents[2]
DART_OUT = ROOT / "flutter/lib/mvp/data/content_importado.dart"
SQL_OUT = ROOT / "supabase/seed/horarios_importados.sql"
PHOTOS = ROOT / "flutter/assets/photos"

CATEGORIAS = ["passeio", "gastronomia", "hospedagem", "cultura", "natureza", "evento", "artesanato", "fotografia", "transporte"]
POLOS = ["lencois", "delta", "chapada", "saoluis", "munim", "guaras", "lagos", "cocais", "amazonia", "serras", "balaiada"]
DIAS = {"seg": 1, "ter": 2, "qua": 3, "qui": 4, "sex": 5, "sab": 6, "sáb": 6, "dom": 7}

# (coluna, obrigatória, explicação, exemplo)
COLUNAS = [
    ("nome", True, "Nome do passeio, restaurante, pousada ou evento", "Passeio às Lagoas"),
    ("categoria", True, "Uma de: " + ", ".join(CATEGORIAS), "passeio"),
    ("polo", True, "Polo turístico: " + ", ".join(POLOS), "lencois"),
    ("cidade", True, "Município", "Barreirinhas"),
    ("resumo", True, "Uma frase, até 90 caracteres", "Lagoas Azul e Bonita, com banho e fotos."),
    ("descricao", True, "Texto completo para a página do item", "Visita às lagoas Azul e Bonita com guia local."),
    ("nome_en", False, "Nome em inglês (aparece quando o app está em inglês)", "Lagoons Tour"),
    ("resumo_en", False, "Resumo em inglês", "Blue and Bonita lagoons, with swimming and photos."),
    ("descricao_en", False, "Descrição em inglês", "Visit to the Blue and Bonita lagoons with a local guide."),
    ("preco_reais", False, "Preço por pessoa (hospedagem: por noite). Só números", "120"),
    ("duracao", False, "Ex.: 4 horas", "4 horas"),
    ("horario_funcionamento", False, "Ex.: Todos os dias, 8h às 18h", "Todos os dias, 8h às 18h"),
    ("endereco", False, "Endereço ou ponto de encontro", "Av. Beira Rio, 100"),
    ("telefone", False, "WhatsApp com DDD", "(98) 99999-0000"),
    ("latitude", False, "Do Google Maps (clique com o botão direito no lugar)", "-2.6630"),
    ("longitude", False, "Do Google Maps", "-42.8602"),
    ("foto", False, "Link https da foto ou nome do arquivo .jpg enviado junto", "lagoas.jpg"),
    ("data_evento", False, "Só para eventos: AAAA-MM-DD HH:MM", "2026-12-06 19:00"),
    ("manha_horario", False, "Turno da manhã. Vazio = não abre de manhã", "8h às 12h"),
    ("manha_vagas", False, "Pessoas por dia na manhã", "20"),
    ("tarde_horario", False, "Turno da tarde. Vazio = não abre à tarde", "14h às 18h"),
    ("tarde_vagas", False, "Pessoas por dia na tarde", "20"),
    ("dias_semana", False, "Dias que funciona: seg,ter,qua,qui,sex,sab,dom (vazio = todos)", "ter,qua,qui,sex,sab,dom"),
    ("acessivel", False, "sim ou não", "não"),
    ("email_parceiro", False, "E-mail da conta do parceiro no app (liga o item ao parceiro)", "contato@pousada.com.br"),
]


def modelo(path: Path) -> None:
    wb = Workbook()
    ws = wb.active
    ws.title = "Parceiros"
    head = Font(bold=True, color="FFFFFF")
    for c, (name, req, _, ex) in enumerate(COLUNAS, 1):
        cell = ws.cell(row=1, column=c, value=name)
        cell.font = head
        cell.fill = PatternFill("solid", fgColor="0B3A5B" if req else "4F7A94")
        ws.cell(row=2, column=c, value=ex)
        ws.column_dimensions[cell.column_letter].width = max(16, len(name) + 4)
    for col, values in (("B", CATEGORIAS), ("C", POLOS)):
        dv = DataValidation(type="list", formula1='"' + ",".join(values) + '"', allow_blank=False)
        ws.add_data_validation(dv)
        dv.add(f"{col}2:{col}500")
    ws.freeze_panes = "A2"

    info = wb.create_sheet("Instruções")
    info.column_dimensions["A"].width = 26
    info.column_dimensions["B"].width = 70
    info.append(["MaraPass · planilha de parceiros", ""])
    info["A1"].font = Font(bold=True, size=14)
    info.append(["Uma linha por item (passeio, restaurante, pousada, evento...). A linha 2 é um exemplo: apague ou substitua.", ""])
    info.append(["Colunas azul-escuras são obrigatórias.", ""])
    info.append(["", ""])
    for name, req, desc, ex in COLUNAS:
        info.append([name + (" *" if req else ""), f"{desc}. Exemplo: {ex}"])
    wb.save(path)
    print(f"Modelo gerado: {path}")


def slug(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-")[:40]


def dart_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$").replace("\n", "\\n") + "'"


def sql_str(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def importar(xlsx: Path, fotos: Path | None) -> int:
    ws = load_workbook(xlsx, data_only=True)["Parceiros"]
    header = [str(c.value or "").strip() for c in ws[1]]
    missing = [n for n, *_ in COLUNAS if n not in header]
    if missing:
        print("Colunas faltando:", ", ".join(missing))
        return 1
    errors: list[str] = []
    items: list[dict] = []
    ids: set[str] = set()
    for n, row in enumerate(ws.iter_rows(min_row=2, values_only=True), 2):
        r = {h: ("" if v is None else str(v).strip()) for h, v in zip(header, row)}
        if not any(r.values()):
            continue
        if r.get("nome") == COLUNAS[0][3] and r.get("foto") == "lagoas.jpg":
            continue  # linha de exemplo do modelo
        err = lambda m: errors.append(f"linha {n}: {m}")  # noqa: E731
        for name, req, *_ in COLUNAS:
            if req and not r.get(name):
                err(f"'{name}' é obrigatório")
        if r["categoria"] and r["categoria"] not in CATEGORIAS:
            err(f"categoria '{r['categoria']}' inválida")
        if r["polo"] and r["polo"] not in POLOS:
            err(f"polo '{r['polo']}' inválido")
        if len(r["resumo"]) > 90:
            err("resumo passa de 90 caracteres")
        preco = None
        if r["preco_reais"]:
            try:
                v = r["preco_reais"].replace("R$", "").strip()
                if "," in v:
                    v = v.replace(".", "").replace(",", ".")
                preco = round(float(v) * 100)
            except ValueError:
                err("preco_reais não é número")
        lat = lng = None
        if r["latitude"] or r["longitude"]:
            try:
                lat, lng = float(r["latitude"].replace(",", ".")), float(r["longitude"].replace(",", "."))
                if not (-11 < lat < 0 and -49 < lng < -41):
                    err("latitude/longitude fora do Maranhão")
            except ValueError:
                err("latitude/longitude inválidas")
        data = None
        if r["categoria"] == "evento":
            m = re.match(r"(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{1,2}):(\d{2}))?", r["data_evento"])
            if not m:
                err("evento precisa de data_evento no formato AAAA-MM-DD HH:MM")
            else:
                data = tuple(int(x or 0) for x in m.groups())
        dias = []
        for d in filter(None, (x.strip().lower() for x in r["dias_semana"].split(","))):
            if d not in DIAS:
                err(f"dia '{d}' inválido")
            else:
                dias.append(DIAS[d])
        turnos = []
        for periodo, pre in (("Manhã", "manha"), ("Tarde", "tarde")):
            if r[f"{pre}_horario"]:
                try:
                    vagas = int(float(r[f"{pre}_vagas"] or 0))
                except ValueError:
                    vagas = 0
                if not 1 <= vagas <= 500:
                    err(f"{pre}_vagas precisa ser de 1 a 500")
                turnos.append((periodo, r[f"{pre}_horario"], vagas))
        base = "imp-" + slug(f"{r['nome']}-{r['cidade']}")
        iid, k = base, 2
        while iid in ids:
            iid, k = f"{base}-{k}", k + 1
        ids.add(iid)
        foto = None
        if r["foto"].startswith("https://"):
            foto = r["foto"]
        elif r["foto"]:
            src = (fotos or xlsx.parent) / r["foto"]
            if not src.is_file():
                err(f"foto '{r['foto']}' não encontrada")
            elif src.suffix.lower() not in (".jpg", ".jpeg"):
                err("foto precisa ser .jpg")
            else:
                foto = f"imp_{iid[4:]}"
                r["_foto_src"] = src
        items.append({**r, "id": iid, "preco": preco, "lat": lat, "lng": lng, "data": data, "dias": dias or list(range(1, 8)), "turnos": turnos, "foto_key": foto})

    if errors:
        print(f"{len(errors)} problema(s) na planilha, nada foi gerado:")
        print("\n".join("  - " + e for e in errors))
        return 1

    lines = [
        "// GERADO por tools/catalogo/importar_parceiros.py a partir da planilha do cliente.",
        "// Não edite à mão: corrija a planilha e rode o importador de novo.",
        "part of 'content.dart';",
        "",
        "final importedItems = <Item>[",
    ]
    for it in items:
        f = [f"id: {dart_str(it['id'])}", f"cat: Cat.{it['categoria']}", f"titulo: {dart_str(it['nome'])}",
             f"resumo: {dart_str(it['resumo'])}", f"descricao: {dart_str(it['descricao'])}",
             f"polo: {dart_str(it['polo'])}", f"cidade: {dart_str(it['cidade'])}"]
        for k, dk in (("nome_en", "tituloEn"), ("resumo_en", "resumoEn"), ("descricao_en", "descricaoEn")):
            if it[k]:
                f.append(f"{dk}: {dart_str(it[k])}")
        if it["foto_key"]:
            f.append(f"foto: {dart_str(it['foto_key'])}")
        if it["preco"] is not None:
            f.append(f"precoCents: {it['preco']}")
        for k, dk in (("duracao", "duracao"), ("horario_funcionamento", "horario"), ("endereco", "endereco"), ("telefone", "telefone")):
            if it[k]:
                f.append(f"{dk}: {dart_str(it[k])}")
        if it["lat"] is not None:
            f += [f"lat: {it['lat']}", f"lng: {it['lng']}", "loc: Loc.exato"]
        if it["data"]:
            y, mo, d, h, mi = it["data"]
            f.append(f"data: DateTime({y}, {mo}, {d}, {h}, {mi})")
        if it["acessivel"].lower() in ("sim", "s", "yes"):
            f.append("acessivel: true")
        lines.append("  Item(" + ", ".join(f) + "),")
    lines += ["];", ""]
    DART_OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")

    sql = ["-- GERADO por tools/catalogo/importar_parceiros.py. Revise antes de aplicar.",
           "-- Turnos e vagas dos itens importados, e a ligação item -> parceiro (pelo e-mail da conta).", "begin;"]
    for it in items:
        for periodo, horas, vagas in it["turnos"]:
            dias = "{" + ",".join(map(str, sorted(set(it["dias"])))) + "}"
            sql.append("insert into public.mvp_item_slots (item_key, period, hours, capacity, weekdays) values "
                       f"({sql_str(it['id'])}, {sql_str(periodo)}, {sql_str(horas)}, {vagas}, '{dias}') "
                       "on conflict (item_key, period) do update set hours = excluded.hours, capacity = excluded.capacity, weekdays = excluded.weekdays, active = true, updated_at = now();")
        if it["email_parceiro"]:
            sql.append("insert into public.mvp_item_owners (item_key, user_id) select "
                       f"{sql_str(it['id'])}, id from auth.users where lower(email) = lower({sql_str(it['email_parceiro'])}) "
                       "on conflict (item_key) do update set user_id = excluded.user_id;")
    sql += ["commit;", ""]
    SQL_OUT.parent.mkdir(parents=True, exist_ok=True)
    SQL_OUT.write_text("\n".join(sql), encoding="utf-8", newline="\n")

    for it in items:
        if "_foto_src" in it:
            shutil.copyfile(it["_foto_src"], PHOTOS / f"{it['foto_key']}.jpg")

    print(f"{len(items)} itens importados.")
    print(f"  {DART_OUT.relative_to(ROOT)}")
    print(f"  {SQL_OUT.relative_to(ROOT)} (aplicar à parte, depois de revisar)")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[1] == "modelo":
        modelo(Path(argv[2]) if len(argv) > 2 else ROOT / "docs/modelo_parceiros.xlsx")
        return 0
    if len(argv) >= 3 and argv[1] == "importar":
        fotos = Path(argv[argv.index("--fotos") + 1]) if "--fotos" in argv else None
        return importar(Path(argv[2]), fotos)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
