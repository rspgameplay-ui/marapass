import 'package:flutter/material.dart';

/// Catálogo editorial da versão de demonstração.
///
/// Textos e fotos vêm do protótipo aprovado; módulos e categorias seguem o
/// Design Master. Parceiros, preços e ofertas são DEMONSTRAÇÃO e não indicam
/// parceria comercial. Itens publicados no Supabase entram por cima deste catálogo.
enum Cat {
  passeio('Passeios', Icons.hiking_rounded, MP_Tint.green),
  gastronomia('Gastronomia', Icons.restaurant_rounded, MP_Tint.yellow),
  hospedagem('Hospedagem', Icons.hotel_rounded, MP_Tint.blue),
  cultura('Cultura', Icons.theater_comedy_rounded, MP_Tint.purple),
  natureza('Natureza', Icons.forest_rounded, MP_Tint.green),
  evento('Eventos', Icons.event_rounded, MP_Tint.red),
  artesanato('Artesanato', Icons.palette_rounded, MP_Tint.yellow),
  fotografia('Fotografia', Icons.photo_camera_rounded, MP_Tint.purple),
  transporte('Transporte', Icons.airport_shuttle_rounded, MP_Tint.blue);

  const Cat(this.label, this.icon, this.tint);
  final String label;
  final IconData icon;
  final MP_Tint tint;

  /// Que ação principal a ficha oferece.
  bool get reservavel => this == passeio || this == natureza || this == cultura;
}

// ignore: camel_case_types
enum MP_Tint {
  green(Color(0xffe3f3ea), Color(0xff176b54)),
  yellow(Color(0xfffdf1cf), Color(0xffa87b00)),
  blue(Color(0xffe6eefb), Color(0xff1a3a5c)),
  purple(Color(0xffeee8fb), Color(0xff5b3fa8)),
  red(Color(0xfffde5e3), Color(0xffc53b36));

  const MP_Tint(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

class Polo {
  const Polo({
    required this.id,
    required this.nome,
    required this.resumo,
    required this.descricao,
    required this.cidades,
    required this.melhor,
    required this.melhorTexto,
    this.foto,
    this.hero,
    this.destaque = false,
  });
  final String id;
  final String nome;
  final String resumo;
  final String descricao;
  final List<String> cidades;
  final List<int> melhor; // meses 0..11
  final String melhorTexto;
  final String? foto;
  final String? hero;
  final bool destaque;
}

class Item {
  const Item({
    required this.id,
    required this.cat,
    required this.titulo,
    required this.resumo,
    required this.descricao,
    required this.polo,
    required this.cidade,
    this.foto,
    this.hero,
    this.faixa = 2,
    this.precoCents,
    this.duracao,
    this.horario,
    this.endereco,
    this.telefone,
    this.saida,
    this.cupom,
    this.tags = const [],
    this.acessivel = false,
    this.autentica = false,
    this.distanciaKm,
    this.data,
    this.artesao,
    this.remoteId,
  });
  final String id;
  final Cat cat;
  final String titulo;
  final String resumo;
  final String descricao;
  final String polo;
  final String cidade;
  final String? foto;
  final String? hero;
  final int faixa; // 1 = $, 2 = $$, 3 = $$$
  final int? precoCents;
  final String? duracao;
  final String? horario;
  final String? endereco;
  final String? telefone;
  final String? saida;
  final String? cupom;
  final List<String> tags;
  final bool acessivel;
  final bool autentica;
  final double? distanciaKm;
  final DateTime? data;
  final String? artesao;

  /// Id da experiência no Supabase, quando o item vem do banco real.
  final String? remoteId;

  String get faixaLabel => r'$' * faixa;
  String get mapsQuery => '$titulo $cidade Maranhão';
}

class Cupom {
  const Cupom({
    required this.id,
    required this.itemId,
    required this.parceiro,
    required this.cat,
    required this.beneficio,
    required this.detalhe,
    required this.validade,
    this.foto,
    this.valorCents,
  });
  final String id;
  final String itemId;
  final String parceiro;
  final Cat cat;
  final String beneficio;
  final String detalhe;
  final DateTime validade;
  final String? foto;
  final int? valorCents;
}

class Dica {
  const Dica({
    required this.titulo,
    required this.autor,
    required this.papel,
    required this.texto,
    required this.itemId,
  });
  final String titulo;
  final String autor;
  final String papel;
  final String texto;
  final String itemId;
}

class Aviso {
  const Aviso({
    required this.id,
    required this.titulo,
    required this.texto,
    required this.destino,
    required this.icon,
  });
  final String id;
  final String titulo;
  final String texto;
  final String destino; // cupons | passaporte | polo:x | item:x | eventos
  final IconData icon;
}

class Faq {
  const Faq(this.pergunta, this.resposta);
  final String pergunta;
  final String resposta;
}

DateTime _d(int y, int m, int d, [int h = 0]) => DateTime(y, m, d, h);

abstract final class Content {
  static const polos = <Polo>[
    Polo(
      id: 'lencois',
      nome: 'Lençóis Maranhenses',
      resumo: 'Dunas brancas e lagoas cristalinas.',
      descricao: 'Dunas de areia branca com lagoas de água doce. A melhor época é de junho a setembro, quando as lagoas estão cheias.',
      cidades: ['Barreirinhas', 'Santo Amaro', 'Atins', 'Paulino Neves'],
      melhor: [5, 6, 7, 8],
      melhorTexto: 'Junho a setembro',
      foto: 'dunas_card',
      hero: 'hero_dunas',
      destaque: true,
    ),
    Polo(
      id: 'delta',
      nome: 'Delta das Américas',
      resumo: 'Ilhas, igarapés e revoada de aves.',
      descricao: 'O único delta em mar aberto das Américas, com ilhas, dunas e comunidades de pescadores.',
      cidades: ['Tutóia', 'Araioses', 'Água Doce'],
      melhor: [6, 7, 8, 9, 10],
      melhorTexto: 'Julho a novembro',
      foto: 'lagoa_boat',
      destaque: true,
    ),
    Polo(
      id: 'chapada',
      nome: 'Chapada das Mesas',
      resumo: 'Cachoeiras e paisagens de serra.',
      descricao: 'Parque nacional com cachoeiras, poços de água azul e mirantes. Ideal para quem gosta de natureza e caminhadas leves.',
      cidades: ['Carolina', 'Riachão', 'Estreito'],
      melhor: [4, 5, 6, 7, 8, 9],
      melhorTexto: 'Maio a outubro',
      foto: 'chapada',
      hero: 'w_chapada',
      destaque: true,
    ),
    Polo(
      id: 'saoluis',
      nome: 'São Luís',
      resumo: 'Centro histórico e cultura.',
      descricao: 'Capital do Maranhão, com casarões de azulejos, museus e culinária típica. O centro histórico é Patrimônio Mundial.',
      cidades: ['São Luís', 'São José de Ribamar', 'Raposa', 'Alcântara'],
      melhor: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
      melhorTexto: 'O ano todo',
      foto: 'saoluis',
      hero: 'w_saoluis',
      destaque: true,
    ),
    Polo(
      id: 'munim',
      nome: 'Munim',
      resumo: 'Rios, manguezais e vilas.',
      descricao: 'Região de rios calmos e comunidades ribeirinhas. Bom para passeios de barco e pôr do sol.',
      cidades: ['Axixá', 'Icatu', 'Morros', 'Cachoeira Grande'],
      melhor: [6, 7, 8, 9, 10, 11],
      melhorTexto: 'Julho a dezembro',
      foto: 'munim',
    ),
    Polo(
      id: 'guaras',
      nome: 'Floresta dos Guarás',
      resumo: 'Aves vermelhas e natureza.',
      descricao: 'Manguezais onde vivem os guarás, aves de cor vermelha intensa. Os passeios de barco saem no fim da tarde.',
      cidades: ['Cururupu', 'Guimarães', 'Apicum-Açu'],
      melhor: [7, 8, 9, 10, 11],
      melhorTexto: 'Agosto a dezembro',
      foto: 'guaras',
      hero: 'w_guaras',
    ),
    Polo(
      id: 'lagos',
      nome: 'Lagos e Campos Floridos',
      resumo: 'Pororoca, rios e sabores.',
      descricao: 'Campos alagados que florescem na cheia, rios largos e o encontro das águas da pororoca.',
      cidades: ['Viana', 'Arari', 'Penalva'],
      melhor: [1, 2, 3, 4],
      melhorTexto: 'Fevereiro a maio',
    ),
    Polo(
      id: 'cocais',
      nome: 'Cocais',
      resumo: 'Babaçu, carnaúba e tradição.',
      descricao: 'Matas de babaçu e carnaúba, quebradeiras de coco e artesanato de palha.',
      cidades: ['Caxias', 'Codó', 'Timon'],
      melhor: [5, 6, 7, 8],
      melhorTexto: 'Junho a setembro',
    ),
    Polo(
      id: 'amazonia',
      nome: 'Amazônia Maranhense',
      resumo: 'Floresta, rios e vivências.',
      descricao: 'A porção maranhense da floresta amazônica, com rios de águas escuras e comunidades tradicionais.',
      cidades: ['Santa Inês', 'Zé Doca', 'Carutapera'],
      melhor: [5, 6, 7, 8, 9],
      melhorTexto: 'Junho a outubro',
    ),
    Polo(
      id: 'serras',
      nome: 'Serras Indígenas',
      resumo: 'Povos originários e serras.',
      descricao: 'Territórios dos povos Guajajara, Timbira e Kanela. Visitas somente com agendamento e autorização das comunidades.',
      cidades: ['Barra do Corda', 'Grajaú', 'Fernando Falcão'],
      melhor: [5, 6, 7, 8],
      melhorTexto: 'Junho a setembro',
    ),
    Polo(
      id: 'balaiada',
      nome: 'Polo Balaiada',
      resumo: 'Memória, águas e cultura.',
      descricao: 'Cidades marcadas pela Balaiada, com casarões, rios e festas populares.',
      cidades: ['Caxias', 'Chapadinha', 'Brejo'],
      melhor: [5, 6, 11],
      melhorTexto: 'Junho e dezembro',
      foto: 'cultura',
    ),
  ];

  static final items = <Item>[
    // Passeios
    const Item(
      id: 'lagoas',
      cat: Cat.passeio,
      titulo: 'Passeio às Lagoas',
      resumo: 'Lagoas Azul e Bonita, com banho e fotos.',
      descricao: 'Visita às lagoas Azul e Bonita, com tempo para banho e fotos. Guia local incluído.',
      polo: 'lencois',
      cidade: 'Barreirinhas',
      foto: 'lagoas',
      hero: 'hero_passeio',
      precoCents: 12000,
      duracao: '4 horas',
      saida: 'Barreirinhas',
      cupom: 'c2',
      faixa: 2,
      distanciaKm: 28,
      tags: ['lagoas', 'dunas', 'banho'],
    ),
    const Item(
      id: 'rio',
      cat: Cat.passeio,
      titulo: 'Passeio pelo Rio Preguiças',
      resumo: 'Barco até Vassouras e o farol.',
      descricao: 'Passeio de barco pelo rio, com paradas em Vassouras e no farol de Mandacaru.',
      polo: 'lencois',
      cidade: 'Barreirinhas',
      foto: 'rio',
      precoCents: 15000,
      duracao: '5 horas',
      saida: 'Barreirinhas',
      faixa: 2,
      distanciaKm: 1,
      acessivel: true,
      tags: ['barco', 'rio'],
    ),
    const Item(
      id: 'por',
      cat: Cat.passeio,
      titulo: 'Pôr do sol nas dunas',
      resumo: 'Caminhada leve até o alto das dunas.',
      descricao: 'Caminhada leve até o alto das dunas para ver o pôr do sol.',
      polo: 'lencois',
      cidade: 'Santo Amaro',
      foto: 'sunset',
      precoCents: 9000,
      duracao: '3 horas',
      saida: 'Santo Amaro',
      faixa: 1,
      distanciaKm: 35,
      tags: ['pôr do sol', 'dunas'],
    ),
    const Item(
      id: '4x4',
      cat: Cat.passeio,
      titulo: 'Passeio de 4x4 pelas dunas',
      resumo: 'Até Atins e Canto do Atins, com almoço.',
      descricao: 'Passeio de carro 4x4 até Atins e Canto do Atins, com almoço incluído.',
      polo: 'lencois',
      cidade: 'Atins',
      foto: 'jeep',
      precoCents: 18000,
      duracao: '6 horas',
      saida: 'Atins',
      faixa: 3,
      distanciaKm: 40,
      tags: ['4x4', 'aventura'],
    ),
    const Item(
      id: 'kite',
      cat: Cat.passeio,
      titulo: 'Aula de kitesurf',
      resumo: 'Para iniciantes, com equipamento.',
      descricao: 'Aula para iniciantes com instrutor e equipamento incluídos.',
      polo: 'lencois',
      cidade: 'Atins',
      foto: 'kite',
      precoCents: 25000,
      duracao: '2 horas',
      saida: 'Atins',
      cupom: 'c5',
      faixa: 3,
      distanciaKm: 40,
      tags: ['esporte', 'vento'],
    ),
    const Item(
      id: 'centro',
      cat: Cat.passeio,
      titulo: 'Caminhada no centro histórico',
      resumo: 'Casarões, igrejas e museus com guia.',
      descricao: 'Passeio a pé com guia pelos casarões, igrejas e museus.',
      polo: 'saoluis',
      cidade: 'São Luís',
      foto: 'saoluis',
      precoCents: 6000,
      duracao: '3 horas',
      saida: 'Praça Benedito Leite',
      faixa: 1,
      acessivel: true,
      distanciaKm: 260,
      tags: ['história', 'azulejos'],
    ),
    const Item(
      id: 'barco',
      cat: Cat.passeio,
      titulo: 'Passeio de barco no Munim',
      resumo: 'Rio calmo com parada para banho.',
      descricao: 'Barco tranquilo pelo rio, com parada para banho.',
      polo: 'munim',
      cidade: 'Axixá',
      foto: 'munim',
      precoCents: 8000,
      duracao: '3 horas',
      saida: 'Axixá',
      faixa: 1,
      acessivel: true,
      distanciaKm: 150,
      tags: ['barco', 'rio'],
    ),
    const Item(
      id: 'delta-ilhas',
      cat: Cat.passeio,
      titulo: 'Ilhas do Delta',
      resumo: 'Igarapés, dunas e revoada de aves.',
      descricao: 'Lancha pelos igarapés do Delta, com parada na ilha do Caju e revoada dos guarás no fim da tarde.',
      polo: 'delta',
      cidade: 'Tutóia',
      foto: 'lagoa_boat',
      precoCents: 20000,
      duracao: '7 horas',
      saida: 'Porto de Tutóia',
      faixa: 3,
      distanciaKm: 90,
      tags: ['lancha', 'ilhas'],
    ),
    // Natureza
    const Item(
      id: 'cach',
      cat: Cat.natureza,
      titulo: 'Trilha das cachoeiras',
      resumo: 'Santa Bárbara e São Romão, com banho.',
      descricao:
          'Visita às cachoeiras de Santa Bárbara e São Romão, com banho.',
      polo: 'chapada',
      cidade: 'Carolina',
      foto: 'chapada',
      hero: 'w_chapada',
      precoCents: 16000,
      duracao: '6 horas',
      saida: 'Carolina',
      faixa: 2,
      distanciaKm: 800,
      tags: ['cachoeira', 'trilha'],
    ),
    const Item(
      id: 'guara',
      cat: Cat.natureza,
      titulo: 'Revoada dos guarás',
      resumo: 'Aves voltando para os ninhos.',
      descricao:
          'Barco pelos manguezais para ver as aves voltando para os ninhos.',
      polo: 'guaras',
      cidade: 'Cururupu',
      foto: 'guaras',
      hero: 'w_guaras',
      precoCents: 14000,
      duracao: '4 horas',
      saida: 'Cururupu',
      faixa: 2,
      distanciaKm: 420,
      tags: ['aves', 'mangue'],
    ),
    const Item(
      id: 'mirante',
      cat: Cat.natureza,
      titulo: 'Mirante da Chapada',
      resumo: 'Vista do pôr do sol sobre as mesas.',
      descricao:
          'Subida curta até o mirante, com vista para as formações de arenito.',
      polo: 'chapada',
      cidade: 'Carolina',
      foto: 'w_chapada',
      precoCents: 5000,
      duracao: '2 horas',
      faixa: 1,
      acessivel: true,
      distanciaKm: 800,
      tags: ['mirante'],
    ),
    // Cultura
    const Item(
      id: 'boi',
      cat: Cat.cultura,
      titulo: 'Noite de Bumba meu boi',
      resumo: 'Música, dança e comidas típicas.',
      descricao: 'Apresentação com música, dança e comidas típicas.',
      polo: 'saoluis',
      cidade: 'São Luís',
      foto: 'cultura',
      precoCents: 5000,
      duracao: '3 horas',
      faixa: 1,
      acessivel: true,
      distanciaKm: 260,
      tags: ['festa', 'boi'],
    ),
    const Item(
      id: 'kanela',
      cat: Cat.cultura,
      titulo: 'Vivência com a Comunidade Kanela',
      resumo: 'Visita guiada e agendada à aldeia.',
      descricao: 'Vivência conduzida pela própria comunidade, com conversa, pintura e culinária. Somente com agendamento e autorização.',
      polo: 'serras',
      cidade: 'Fernando Falcão',
      precoCents: 18000,
      duracao: '1 dia',
      faixa: 2,
      autentica: true,
      distanciaKm: 600,
      tags: ['povos originários'],
    ),
    const Item(
      id: 'quilombo',
      cat: Cat.cultura,
      titulo: 'Quilombo Urbano de São Luís',
      resumo: 'História, tambor de crioula e culinária.',
      descricao: 'Roteiro conduzido por moradores, com tambor de crioula e comida da casa.',
      polo: 'saoluis',
      cidade: 'São Luís',
      foto: 'p2',
      precoCents: 7000,
      duracao: '3 horas',
      faixa: 1,
      autentica: true,
      acessivel: true,
      distanciaKm: 262,
      tags: ['quilombo', 'tambor'],
    ),
    const Item(
      id: 'marcelino',
      cat: Cat.cultura,
      titulo: 'Vivência em Marcelino',
      resumo: 'Pesca artesanal e vida de vila.',
      descricao: 'Um dia com pescadores da vila, do preparo da rede ao almoço com peixe fresco.',
      polo: 'lencois',
      cidade: 'Barreirinhas',
      foto: 'p3',
      precoCents: 11000,
      duracao: '5 horas',
      faixa: 2,
      autentica: true,
      distanciaKm: 18,
      tags: ['pesca', 'vila'],
    ),
    // Gastronomia
    const Item(
      id: 'mangue',
      cat: Cat.gastronomia,
      titulo: 'Casa do Mangue',
      resumo: 'Comida típica com vista para o rio.',
      descricao: 'Peixes da região, arroz de cuxá e tortas de camarão, com varanda sobre o rio.',
      polo: 'lencois',
      cidade: 'Barreirinhas',
      foto: 'rest2',
      hero: 'hero_mangue',
      horario: 'Todos os dias, 11h às 23h',
      endereco: 'Barreirinhas - MA',
      telefone: '(98) 99123-4567',
      cupom: 'c1',
      faixa: 2,
      distanciaKm: 3,
      acessivel: true,
      tags: ['regional', 'peixe', 'maranhense'],
    ),
    const Item(
      id: 'buriti',
      cat: Cat.gastronomia,
      titulo: 'Restaurante o Buriti',
      resumo: 'Peixes e frutos do mar.',
      descricao: 'Peixe na brasa, caldeirada e frutos do mar frescos.',
      polo: 'lencois',
      cidade: 'Santo Amaro',
      foto: 'fish',
      horario: 'Terça a domingo, 11h às 22h',
      endereco: 'Santo Amaro - MA',
      telefone: '(98) 98877-1122',
      faixa: 2,
      distanciaKm: 35,
      tags: ['frutos do mar', 'peixe'],
    ),
    const Item(
      id: 'cozinha',
      cat: Cat.gastronomia,
      titulo: 'Cozinha da Praia Grande',
      resumo: 'Arroz de cuxá e pratos da casa.',
      descricao: 'Cozinha maranhense no centro histórico, com arroz de cuxá, peixada e doce de buriti.',
      polo: 'saoluis',
      cidade: 'São Luís',
      foto: 'food',
      horario: 'Todos os dias, 11h às 16h',
      endereco: 'Centro Histórico, São Luís - MA',
      telefone: '(98) 3222-1010',
      faixa: 1,
      distanciaKm: 260,
      acessivel: true,
      tags: ['regional', 'maranhense'],
    ),
    const Item(
      id: 'juja',
      cat: Cat.gastronomia,
      titulo: 'Casa de Juja',
      resumo: 'Galinha caipira e comida de quintal.',
      descricao: 'Comida feita no fogão a lenha, com galinha caipira e farinha d’água.',
      polo: 'lencois',
      cidade: 'Barreirinhas',
      foto: 'rest',
      horario: 'Sexta a domingo, 11h às 15h',
      endereco: 'Barreirinhas - MA',
      telefone: '(98) 99777-0001',
      faixa: 1,
      distanciaKm: 6,
      tags: ['galinha', 'regional'],
    ),
    const Item(
      id: 'conchas',
      cat: Cat.gastronomia,
      titulo: 'Conchas Bar',
      resumo: 'Petiscos e drinks na beira-mar.',
      descricao: 'Bar de praia com petiscos de frutos do mar e música ao vivo nos fins de semana.',
      polo: 'saoluis',
      cidade: 'São Luís',
      foto: 'p4',
      horario: 'Todos os dias, 16h à 0h',
      endereco: 'Ponta d’Areia, São Luís - MA',
      telefone: '(98) 98111-2233',
      faixa: 3,
      distanciaKm: 258,
      tags: ['bar', 'mar'],
    ),
    // Hospedagem
    const Item(
      id: 'vila',
      cat: Cat.hospedagem,
      titulo: 'Pousada Vila Lençóis',
      resumo: 'Quartos com varanda e café da manhã.',
      descricao:
          'Pousada familiar com varandas, redes e café da manhã regional.',
      polo: 'lencois',
      cidade: 'Santo Amaro',
      foto: 'pousada',
      telefone: '(98) 99900-2233',
      cupom: 'c3',
      faixa: 2,
      distanciaKm: 4,
      acessivel: true,
      tags: ['pousada', 'café da manhã', 'wi-fi'],
    ),
    const Item(
      id: 'atins-hotel',
      cat: Cat.hospedagem,
      titulo: 'Refúgio de Atins',
      resumo: 'Chalés perto da praia.',
      descricao: 'Chalés de madeira a 5 minutos da praia, com piscina e aluguel de bicicletas.',
      polo: 'lencois',
      cidade: 'Atins',
      foto: 'p1',
      telefone: '(98) 99555-4040',
      faixa: 3,
      distanciaKm: 40,
      tags: ['chalé', 'piscina'],
    ),
    const Item(
      id: 'slz-hotel',
      cat: Cat.hospedagem,
      titulo: 'Hotel Casarão Colonial',
      resumo: 'Casarão restaurado no centro.',
      descricao: 'Hotel em casarão de azulejos restaurado, a poucos passos dos museus.',
      polo: 'saoluis',
      cidade: 'São Luís',
      foto: 'w_saoluis',
      telefone: '(98) 3232-7788',
      faixa: 2,
      distanciaKm: 260,
      acessivel: true,
      tags: ['hotel', 'centro histórico'],
    ),
    // Eventos
    Item(
      id: 'ev-boi',
      cat: Cat.evento,
      titulo: 'Festival de Bumba meu boi',
      resumo: 'Os grupos de boi na praça.',
      descricao: 'Apresentações de grupos de boi de vários sotaques, com barracas de comida típica.',
      polo: 'saoluis',
      cidade: 'São Luís',
      foto: 'cultura',
      data: _d(2026, 12, 6, 19),
      endereco: 'Praça Maria Aragão',
      faixa: 1,
      cupom: 'c6',
      acessivel: true,
      distanciaKm: 260,
    ),
    Item(
      id: 'ev-sabores',
      cat: Cat.evento,
      titulo: 'Circuito de Sabores de Barreirinhas',
      resumo: 'Restaurantes com pratos especiais.',
      descricao: 'Uma semana com pratos especiais nos restaurantes participantes e benefício 2x1.',
      polo: 'lencois',
      cidade: 'Barreirinhas',
      foto: 'food',
      data: _d(2026, 11, 28, 11),
      faixa: 2,
      distanciaKm: 2,
    ),
    Item(
      id: 'ev-regata',
      cat: Cat.evento,
      titulo: 'Regata de canoas no Preguiças',
      resumo: 'Competição tradicional de canoas.',
      descricao: 'Disputa de canoas a vela entre comunidades ribeirinhas, com feira de artesanato.',
      polo: 'lencois',
      cidade: 'Barreirinhas',
      foto: 'rio',
      data: _d(2026, 12, 13, 8),
      faixa: 1,
      distanciaKm: 1,
    ),
    // Artesanato
    const Item(
      id: 'ceramica',
      cat: Cat.artesanato,
      titulo: 'Cerâmica de Rosário',
      resumo: 'Peças de barro feitas à mão.',
      descricao:
          'Potes, panelas e esculturas de barro queimados em forno a lenha.',
      polo: 'munim',
      cidade: 'Rosário',
      foto: 'ceramica',
      precoCents: 4500,
      cupom: 'c4',
      faixa: 1,
      artesao: 'Dona Raimunda',
      telefone: '(98) 99222-1100',
      tags: ['Cerâmica'],
      distanciaKm: 140,
    ),
    const Item(
      id: 'buriti-bolsa',
      cat: Cat.artesanato,
      titulo: 'Bolsa de fibra de buriti',
      resumo: 'Trançada por artesãs de Barreirinhas.',
      descricao: 'Bolsa tingida com corantes naturais e trançada à mão com fibra de buriti.',
      polo: 'lencois',
      cidade: 'Barreirinhas',
      precoCents: 12000,
      faixa: 2,
      artesao: 'Associação das Artesãs do Buriti',
      telefone: '(98) 99333-2200',
      tags: ['Buriti'],
      distanciaKm: 2,
    ),
    const Item(
      id: 'biojoia',
      cat: Cat.artesanato,
      titulo: 'Colar de biojoias',
      resumo: 'Sementes e capim dourado.',
      descricao:
          'Colar feito com sementes nativas e detalhes de capim dourado.',
      polo: 'chapada',
      cidade: 'Carolina',
      precoCents: 8000,
      faixa: 2,
      artesao: 'Ateliê Sementes do Cerrado',
      telefone: '(99) 99111-3300',
      tags: ['Biojoias'],
      distanciaKm: 800,
    ),
    const Item(
      id: 'babacu',
      cat: Cat.artesanato,
      titulo: 'Cesto de palha de babaçu',
      resumo: 'Feito pelas quebradeiras de coco.',
      descricao: 'Cesto trançado com palha de babaçu pelas quebradeiras de coco do Cocais.',
      polo: 'cocais',
      cidade: 'Codó',
      precoCents: 6000,
      faixa: 1,
      artesao: 'Coletivo das Quebradeiras',
      telefone: '(99) 99444-5500',
      tags: ['Babaçu'],
      distanciaKm: 380,
    ),
    // Fotografia
    const Item(
      id: 'foto-dunas',
      cat: Cat.fotografia,
      titulo: 'Ensaio nas dunas',
      resumo: '1 hora com fotógrafo local.',
      descricao: 'Sessão de 1 hora ao nascer ou pôr do sol, com 30 fotos tratadas entregues em galeria on-line.',
      polo: 'lencois',
      cidade: 'Barreirinhas',
      foto: 'hero_dunas',
      precoCents: 35000,
      duracao: '1 hora',
      faixa: 3,
      distanciaKm: 20,
    ),
    const Item(
      id: 'foto-centro',
      cat: Cat.fotografia,
      titulo: 'Fotos no centro histórico',
      resumo: 'Retratos entre azulejos.',
      descricao: 'Passeio fotográfico de 40 minutos pelas ruas de azulejos, com 20 fotos tratadas.',
      polo: 'saoluis',
      cidade: 'São Luís',
      foto: 'saoluis',
      precoCents: 22000,
      duracao: '40 minutos',
      faixa: 2,
      distanciaKm: 260,
    ),
    // Transporte
    const Item(
      id: 'transfer-slz',
      cat: Cat.transporte,
      titulo: 'Transfer São Luís → Barreirinhas',
      resumo: 'Van com ar-condicionado, 4 horas.',
      descricao: 'Saídas diárias da rodoviária, do aeroporto ou do seu endereço em São Luís.',
      polo: 'lencois',
      cidade: 'São Luís',
      precoCents: 9000,
      duracao: '4 horas',
      faixa: 1,
      distanciaKm: 260,
    ),
    const Item(
      id: 'transfer-atins',
      cat: Cat.transporte,
      titulo: 'Travessia para Atins',
      resumo: 'Lancha ou 4x4 a partir de Barreirinhas.',
      descricao: 'Travessia compartilhada até Atins pelo rio ou pelas dunas.',
      polo: 'lencois',
      cidade: 'Barreirinhas',
      precoCents: 6000,
      duracao: '1h30',
      faixa: 1,
      distanciaKm: 1,
    ),
  ];

  static final cupons = <Cupom>[
    Cupom(
      id: 'c1',
      itemId: 'mangue',
      parceiro: 'Casa do Mangue',
      cat: Cat.gastronomia,
      beneficio: '10% de desconto',
      detalhe: 'No almoço e no jantar.',
      validade: _d(2026, 12, 30),
      foto: 'food',
    ),
    Cupom(
      id: 'c2',
      itemId: 'lagoas',
      parceiro: 'Passeio às Lagoas',
      cat: Cat.passeio,
      beneficio: r'R$ 50 de desconto',
      detalhe: 'Por pessoa, em passeios regulares.',
      validade: _d(2027, 1, 31),
      foto: 'lagoa_boat',
      valorCents: 5000,
    ),
    Cupom(
      id: 'c3',
      itemId: 'vila',
      parceiro: 'Pousada Vila Lençóis',
      cat: Cat.hospedagem,
      beneficio: '20% de desconto',
      detalhe: 'Na diária, fora da alta temporada.',
      validade: _d(2026, 11, 30),
      foto: 'pousada',
    ),
    Cupom(
      id: 'c4',
      itemId: 'ceramica',
      parceiro: 'Cerâmica de Rosário',
      cat: Cat.artesanato,
      beneficio: '10% de desconto',
      detalhe: 'Em peças selecionadas.',
      validade: _d(2026, 12, 31),
      foto: 'ceramica',
    ),
    Cupom(
      id: 'c5',
      itemId: 'kite',
      parceiro: 'Aula de kitesurf',
      cat: Cat.passeio,
      beneficio: r'R$ 40 de desconto',
      detalhe: 'Na aula experimental.',
      validade: _d(2027, 2, 28),
      foto: 'kite',
      valorCents: 4000,
    ),
    Cupom(
      id: 'c6',
      itemId: 'ev-boi',
      parceiro: 'Festival de Bumba meu boi',
      cat: Cat.evento,
      beneficio: 'Leve 2, pague 1',
      detalhe: 'No prato típico das barracas participantes.',
      validade: _d(2026, 12, 7),
      foto: 'cultura',
    ),
  ];

  static const dicas = <Dica>[
    Dica(
      titulo: 'Vá às lagoas de manhã cedo',
      autor: 'Seu Zé Ribamar',
      papel: 'Guia em Barreirinhas há 20 anos',
      texto: 'Saindo às 7h você pega as lagoas vazias e a areia ainda fresca. Leve água e protetor: não há sombra nas dunas.',
      itemId: 'lagoas',
    ),
    Dica(
      titulo: 'Peça o arroz de cuxá',
      autor: 'Dona Ana',
      papel: 'Cozinheira em São Luís',
      texto: 'É o prato mais maranhense que existe: arroz com vinagreira, gergelim e camarão seco.',
      itemId: 'cozinha',
    ),
  ];

  static const avisos = <Aviso>[
    Aviso(
      id: 'n1',
      titulo: 'Cupom novo para você',
      texto: 'Pousada Vila Lençóis com 20% de desconto.',
      destino: 'cupons',
      icon: Icons.local_activity_rounded,
    ),
    Aviso(
      id: 'n2',
      titulo: 'Lembrete da reserva',
      texto: 'Confira o dia e a hora em Minhas reservas.',
      destino: 'reservas',
      icon: Icons.event_available_rounded,
    ),
    Aviso(
      id: 'n3',
      titulo: 'Época das lagoas cheias',
      texto: 'De junho a setembro as lagoas ficam mais bonitas.',
      destino: 'polo:lencois',
      icon: Icons.wb_sunny_rounded,
    ),
    Aviso(
      id: 'n4',
      titulo: 'Festival de Bumba meu boi',
      texto: 'Dia 6 de dezembro na Praça Maria Aragão.',
      destino: 'item:ev-boi',
      icon: Icons.event_rounded,
    ),
  ];

  static const faq = <Faq>[
    Faq(
      'Como uso um cupom?',
      'Abra Cupons, toque no cupom e mostre o QR ao atendente. Cada cupom vale uma vez.',
    ),
    Faq(
      'Preciso pagar para reservar?',
      'Não. Você envia um pedido e o parceiro confirma. O pagamento é combinado com ele.',
    ),
    Faq(
      'Como faço o check-in?',
      'No local, abra Check-in e leia a placa MaraPass com a câmera ou digite o código da placa.',
    ),
    Faq(
      'O que são os pontos do passaporte?',
      'Você ganha pontos ao fazer check-in, usar cupons e visitar destinos novos. Eles mudam o seu nível.',
    ),
    Faq(
      'Posso usar sem cadastro?',
      'Sim, para explorar. Para reservar, ativar cupons e guardar o passaporte, entre com o seu e-mail.',
    ),
    Faq(
      'Como deixo a letra maior?',
      'Em Perfil, ligue a opção Letra grande. Vale para o aplicativo todo.',
    ),
    Faq(
      'Como excluo minha conta?',
      'Em Perfil, toque em Excluir minha conta e confirme.',
    ),
  ];

  static const oQueLevar = [
    'Protetor solar',
    'Chapéu ou boné',
    'Roupa de banho',
    'Garrafa de água',
    'Sandália ou chinelo',
    'Dinheiro ou Pix',
  ];

  static const niveis = [
    ('Viajante', 0),
    ('Explorador', 500),
    ('Aventureiro', 1000),
    ('Mestre', 2500),
  ];

  static Polo polo(String id) =>
      polos.firstWhere((p) => p.id == id, orElse: () => polos.first);
  static Item? item(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  static Cupom? cupom(String? id) {
    for (final c in cupons) {
      if (c.id == id) return c;
    }
    return null;
  }

  static List<Item> byCat(Cat c) => items.where((i) => i.cat == c).toList();
  static List<Item> byPolo(String polo) =>
      items.where((i) => i.polo == polo).toList();
  static List<String> cidades(Iterable<Item> list) =>
      {for (final i in list) i.cidade}.toList()..sort();

  /// Busca universal: título, resumo, cidade, polo, categoria e etiquetas.
  static List<Item> search(String q) {
    final t = _norm(q);
    if (t.isEmpty) return const [];
    return items.where((i) {
      final hay = _norm(
        '${i.titulo} ${i.resumo} ${i.cidade} ${polo(i.polo).nome} ${i.cat.label} ${i.tags.join(' ')}',
      );
      return t.split(' ').every(hay.contains);
    }).toList();
  }

  static String _norm(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const to = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    final b = StringBuffer();
    for (final ch in s.trim().split('')) {
      final k = from.indexOf(ch);
      b.write(k >= 0 ? to[k] : ch);
    }
    return b.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
