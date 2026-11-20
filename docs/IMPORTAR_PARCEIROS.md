# Importar parceiros da planilha

1. Mande ao cliente `docs/modelo_parceiros.xlsx` (uma linha por item; aba Instruções explica cada coluna).
2. Com a planilha preenchida (e as fotos .jpg na mesma pasta, se não forem links):

   ```powershell
   python tools/catalogo/importar_parceiros.py importar C:\caminho\parceiros.xlsx
   ```

   O importador confere tudo antes. Se houver erro, lista as linhas e não gera nada.
3. Ele gera:
   - `flutter/lib/mvp/data/content_importado.dart`: itens do catálogo (entram no app no próximo build);
   - `flutter/assets/photos/imp_*.jpg`: fotos enviadas como arquivo;
   - `supabase/seed/horarios_importados.sql`: turnos, vagas e ligação item → parceiro. Revise e aplique no banco à parte.
4. Rode os testes, faça o build e publique.

Para gerar o modelo de novo: `python tools/catalogo/importar_parceiros.py modelo docs/modelo_parceiros.xlsx`.
Requer `pip install openpyxl`.
