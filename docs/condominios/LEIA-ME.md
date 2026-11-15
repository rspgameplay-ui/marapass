# Camada opcional de condomínios

448 referências do OpenStreetMap em oito municípios, importadas em 08/11/2026: São Luís (306), São José de Ribamar (87), Paço do Lumiar (40), Imperatriz (6), Barreirinhas (3), Raposa (3), Santa Inês (2) e Vitorino Freire (1).

Abra `?layer=condominios` ou **Mais filtros → Categoria → Condomínios → Mostrar lugares**. Pesquisa por nome e salvos também encontram residências. A camada não aparece na visão turística padrão e não gera descobertas turísticas, parceria, hospedagem ou cupom.

Base parcial, sem vistoria: os pontos são referências cartográficas, não portarias confirmadas. Ausência no mapa não indica inexistência. As fichas informam que o acesso é privado e precisa ser combinado com o responsável. Não foram importados moradores, números de apartamentos, telefones ou fotografias.

Fonte: © OpenStreetMap contributors, ODbL 1.0, https://www.openstreetmap.org/copyright. Timestamp e cobertura constam em `flutter/assets/data/condominiums.json`. A consulta estadual gerou 546 candidatos; foram excluídos 97 objetos sem evidência residencial ou com outros usos e removida uma duplicidade próxima de mesmo nome. Município atribuído por contenção na malha IBGE 2025, não pela cidade mais próxima. A consulta por “condom” no nome é uma limitação expressa da cobertura inicial.

`osm-source.json` preserva somente etiquetas necessárias à reprodução; `exclusoes.json` lista IDs descartados. O script `flutter/scripts/import_condominiums.py` reproduz a filtragem espacial e exige Shapely. Revise datas e exclusões antes de atualizar o extrato.

No painel **Mapa e conteúdo → Referências do Maranhão**, pesquise pelo nome para carregar a referência como um ponto em rascunho. O fluxo de prévia, publicação, permissões e histórico continua usando os IDs existentes. Os 448 objetos não foram transformados automaticamente em documentos editoriais na nuvem. O validador de categorias foi atualizado para `residential`, preservando as demais verificações e permissões.
