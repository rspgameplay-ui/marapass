import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/map_state.dart';
import '../core/catalog_download.dart';
import '../data/catalog_workspace.dart';
import '../domain/tourism.dart';
import 'brand.dart';

const _teal = MaraColors.navy;

class CatalogCenter extends ConsumerStatefulWidget {
  const CatalogCenter({super.key});
  @override
  ConsumerState<CatalogCenter> createState() => _CatalogCenterState();
}

class _CatalogCenterState extends ConsumerState<CatalogCenter> {
  String query = '';
  CatalogStatus? status;
  CatalogKind? kind;
  PlaceCategory? category;
  MapCoordinator get coordinator => ref.read(mapStateProvider.notifier);
  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> edit(TourismPlace? place, CatalogEntry? entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogEditor(place: place, entry: entry),
      ),
    );
  }

  Future<void> backup() async {
    final json = coordinator.workspace.encode(coordinator.entries);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * .65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Backup do catálogo',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Inclui seus cadastros, alterações e estados de visibilidade. Guarde este JSON para restaurar ou levar a outro aparelho.',
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      json,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      if (!downloadCatalog(json)) {
                        await Clipboard.setData(ClipboardData(text: json));
                      }
                      if (sheet.mounted) {
                        Navigator.pop(sheet);
                      }
                      if (mounted) {
                        message(
                          'Backup preparado. Guarde o arquivo ou o texto copiado.',
                        );
                      }
                    } catch (_) {
                      if (mounted) {
                        message('Selecione e copie o texto do backup.');
                      }
                    }
                  },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Exportar JSON'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: json));
                    if (sheet.mounted) {
                      Navigator.pop(sheet);
                    }
                    if (mounted) {
                      message('JSON copiado.');
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar texto do backup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> importBackup() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const CatalogImport()));
  }

  Future<void> restore(CatalogEntry entry, bool base) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          base ? 'Restaurar referência original?' : 'Excluir cadastro local?',
        ),
        content: Text(
          base
              ? 'As suas alterações neste ponto serão removidas. A referência original voltará ao mapa.'
              : 'O ponto será removido deste aparelho. Exporte um backup se quiser preservá-lo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(base ? 'Restaurar' : 'Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await coordinator.removeEntry(entry.place.id);
    } catch (e) {
      if (mounted) {
        message(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(mapStateProvider);
    final entries = {for (final e in coordinator.entries) e.place.id: e};
    final seeds = {for (final p in coordinator.repo.seed) p.id: p};
    final all = {...seeds, for (final e in entries.values) e.place.id: e.place};
    final rows = all.values.where((p) {
      final e = entries[p.id];
      return (status == null ||
              (e?.status ?? CatalogStatus.visible) == status) &&
          (kind == null ||
              (e?.kind ??
                      (p.category == PlaceCategory.destination
                          ? CatalogKind.point
                          : CatalogKind.attraction)) ==
                  kind) &&
          (category == null || p.category == category) &&
          normalize(
            '${p.name} ${p.city} ${p.area ?? ''} ${p.tags ?? ''} ${p.description}',
          ).contains(normalize(query));
    }).toList()..sort((a, b) => normalize(a.name).compareTo(normalize(b.name)));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central do mapa'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Backup do catálogo',
            onSelected: (v) => v == 'export' ? backup() : importBackup(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'export',
                child: Text('Exportar meus cadastros'),
              ),
              PopupMenuItem(
                value: 'import',
                child: Text('Importar backup JSON'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(null, null),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Novo cadastro'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Seu Maranhão, ponto a ponto.',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _teal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cadastre lugares, revise referências e organize o que aparece no seu mapa.',
                      ),
                      const SizedBox(height: 18),
                      Card(
                        color: const Color(0xffeaf0fa),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.devices_outlined, color: _teal),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Área de trabalho local',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'As alterações ficam neste navegador ou aparelho. “Visível” adiciona o ponto ao seu mapa. A publicação geral e a gestão de parceiros dependem da integração administrativa.',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${entries.length} personalizações • ${entries.values.where((e) => e.status == CatalogStatus.draft).length} rascunhos',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        onChanged: (v) => setState(() => query = v),
                        decoration: const InputDecoration(
                          labelText: 'Pesquisar no catálogo',
                          hintText: 'Nome, município, região ou palavra-chave',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Filtros do catálogo'),
                        leading: const Icon(Icons.tune),
                        subtitle: Text(
                          '${[kind, status, category].where((v) => v != null).length} filtros ativos',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                DropdownMenu<CatalogKind?>(
                                  width: 260,
                                  label: const Text('Tipo'),
                                  initialSelection: kind,
                                  onSelected: (v) => setState(() => kind = v),
                                  dropdownMenuEntries: [
                                    const DropdownMenuEntry(
                                      value: null,
                                      label: 'Todos os tipos',
                                    ),
                                    for (final v in CatalogKind.values)
                                      DropdownMenuEntry(
                                        value: v,
                                        label: v.label,
                                      ),
                                  ],
                                ),
                                DropdownMenu<CatalogStatus?>(
                                  width: 260,
                                  label: const Text('Situação'),
                                  initialSelection: status,
                                  onSelected: (v) => setState(() => status = v),
                                  dropdownMenuEntries: [
                                    const DropdownMenuEntry(
                                      value: null,
                                      label: 'Todas as situações',
                                    ),
                                    for (final v in CatalogStatus.values)
                                      DropdownMenuEntry(
                                        value: v,
                                        label: v.label,
                                      ),
                                  ],
                                ),
                                DropdownMenu<PlaceCategory?>(
                                  width: 260,
                                  label: const Text('Categoria'),
                                  initialSelection: category,
                                  onSelected: (v) =>
                                      setState(() => category = v),
                                  dropdownMenuEntries: [
                                    const DropdownMenuEntry(
                                      value: null,
                                      label: 'Todas as categorias',
                                    ),
                                    for (final v in PlaceCategory.values)
                                      DropdownMenuEntry(
                                        value: v,
                                        label: v.label,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${rows.length} registros encontrados',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              if (rows.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Nenhum cadastro corresponde à pesquisa. Crie um ponto ou ajuste os filtros.',
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final p = rows[index], e = entries[p.id];
                    final currentStatus = e?.status ?? CatalogStatus.visible;
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: p.category.color.withValues(
                            alpha: .12,
                          ),
                          child: Icon(p.category.icon, color: p.category.color),
                        ),
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${p.city} • ${p.category.label}\n${e == null ? 'Referência do catálogo' : '${e.kind.label} • ${currentStatus.label}'}',
                        ),
                        isThreeLine: true,
                        onTap: () => edit(p, e),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Ações de ${p.name}',
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await edit(p, e);
                            }
                            if (v == 'map') {
                              coordinator.resetFilters();
                              coordinator.savedOnly(false);
                              coordinator.focus(p.point, 14);
                              if (context.mounted) {
                                Navigator.pop(context, true);
                              }
                            }
                            if (v == 'restore' && e != null) {
                              await restore(e, seeds.containsKey(p.id));
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Editar cadastro'),
                            ),
                            if (currentStatus == CatalogStatus.visible)
                              const PopupMenuItem(
                                value: 'map',
                                child: Text('Ver no mapa'),
                              ),
                            if (e != null)
                              PopupMenuItem(
                                value: 'restore',
                                child: Text(
                                  seeds.containsKey(p.id)
                                      ? 'Restaurar referência'
                                      : 'Excluir cadastro local',
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }
}

class CatalogEditor extends ConsumerStatefulWidget {
  const CatalogEditor({super.key, this.place, this.entry});
  final TourismPlace? place;
  final CatalogEntry? entry;
  @override
  ConsumerState<CatalogEditor> createState() => _CatalogEditorState();
}

class _CatalogEditorState extends ConsumerState<CatalogEditor> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late CatalogKind kind;
  late CatalogStatus status;
  late PlaceCategory category;
  bool reference = true, saving = false, dirty = false;
  String? error;
  TextEditingController c(String key) => fields[key]!;
  @override
  void initState() {
    super.initState();
    final p = widget.place;
    kind =
        widget.entry?.kind ??
        (p?.category == PlaceCategory.destination
            ? CatalogKind.point
            : CatalogKind.attraction);
    status =
        widget.entry?.status ??
        (p == null ? CatalogStatus.draft : CatalogStatus.visible);
    category = p?.category ?? PlaceCategory.nature;
    reference = p?.referenceLocation ?? true;
    final values = {
      'name': p?.name,
      'city': p?.city,
      'description': p?.description,
      'area': p?.area,
      'address': p?.address,
      'tags': p?.tags,
      'hours': p?.hours,
      'phone': p?.phone,
      'whatsapp': p?.whatsapp,
      'website': p?.website,
      'sourceUrl': p?.sourceUrl,
      'photoUrl': p?.photoUrl,
      'lat': p?.point.lat.toString(),
      'lng': p?.point.lng.toString(),
    };
    for (final e in values.entries) {
      fields[e.key] = TextEditingController(text: e.value ?? '')
        ..addListener(() {
          if (!dirty && mounted) {
            setState(() => dirty = true);
          }
        });
    }
  }

  @override
  void dispose() {
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  String? optional(String key) =>
      c(key).text.trim().isEmpty ? null : c(key).text.trim();
  double? coordinate(String key) =>
      double.tryParse(c(key).text.trim().replaceAll(',', '.'));
  Future<void> close() async {
    if (saving) {
      return;
    }
    if (!dirty) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('As alterações ainda não foram salvas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) {
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final p = TourismPlace(
        id:
            widget.place?.id ??
            'local:${DateTime.now().microsecondsSinceEpoch}',
        name: c('name').text.trim(),
        city: c('city').text.trim(),
        point: GeoPoint(coordinate('lat')!, coordinate('lng')!),
        category: category,
        description: c('description').text.trim(),
        municipalityId: widget.place?.municipalityId,
        dataSource: 'MaraPass • cadastro local',
        checkedAt: DateTime.now().toIso8601String().substring(0, 10),
        area: optional('area'),
        address: optional('address'),
        tags: optional('tags'),
        hours: optional('hours'),
        phone: optional('phone'),
        whatsapp: optional('whatsapp'),
        website: optional('website'),
        sourceUrl: optional('sourceUrl'),
        photoUrl: optional('photoUrl'),
        referenceLocation: reference,
      );
      validatePlace(p);
      await ref
          .read(mapStateProvider.notifier)
          .saveEntry(
            CatalogEntry(
              place: p,
              kind: kind,
              status: status,
              updatedAt: DateTime.now(),
            ),
          );
      if (!mounted) {
        return;
      }
      dirty = false;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == CatalogStatus.visible
                ? 'Cadastro salvo e visível no seu mapa.'
                : 'Cadastro salvo como ${status.label.toLowerCase()}.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : 'Não foi possível salvar. Tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Widget field(
    String key,
    String label, {
    int lines = 1,
    int max = 300,
    String? hint,
    bool required = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c(key),
      maxLines: lines,
      maxLength: max,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        counterText: '',
      ),
      validator: (value) {
        if (required && (value?.trim().isEmpty ?? true)) {
          return 'Preencha este campo.';
        }
        if (key == 'lat' || key == 'lng') {
          final n = coordinate(key);
          if (n == null || !n.isFinite) {
            return 'Informe uma coordenada válida.';
          }
          if (key == 'lat' && (n < -10.3 || n > -1) ||
              key == 'lng' && (n < -48.6 || n > -41.7)) {
            return 'Coordenada fora da área do Maranhão.';
          }
        }
        if (key == 'name' && (value?.trim().length ?? 0) < 3) {
          return 'Use pelo menos 3 caracteres.';
        }
        if (key == 'city' && (value?.trim().length ?? 0) < 2) {
          return 'Informe o município.';
        }
        return null;
      },
    ),
  );
  Widget heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: _teal,
          ),
        ),
        const SizedBox(height: 5),
        Text(subtitle),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !saving,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        close();
      }
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: close,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(widget.place == null ? 'Novo cadastro' : 'Editar cadastro'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                heading(
                  'Identificação',
                  'Os dados salvos aparecerão na pesquisa e nos detalhes do ponto.',
                ),
                DropdownButtonFormField<CatalogKind>(
                  initialValue: kind,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de cadastro',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final v in CatalogKind.values)
                      DropdownMenuItem(value: v, child: Text(v.label)),
                  ],
                  onChanged: (v) => setState(() {
                    kind = v!;
                    dirty = true;
                  }),
                ),
                const SizedBox(height: 16),
                field('name', 'Nome', required: true, max: 160),
                field('city', 'Município', required: true, max: 100),
                DropdownButtonFormField<PlaceCategory>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final v in PlaceCategory.values)
                      DropdownMenuItem(value: v, child: Text(v.label)),
                  ],
                  onChanged: (v) => setState(() {
                    category = v!;
                    dirty = true;
                  }),
                ),
                const SizedBox(height: 16),
                field('description', 'Descrição', lines: 4, max: 5000),
                field(
                  'area',
                  'Região de exploração (opcional)',
                  hint: 'Ex.: Balaiada',
                  max: 120,
                ),
                const Text(
                  'Este campo é editorial. Ele não altera a composição oficial dos polos turísticos.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                field(
                  'tags',
                  'Palavras-chave',
                  hint: 'Ex.: trilha, família, pôr do sol',
                  max: 500,
                ),
                heading(
                  'Localização',
                  'Use latitude e longitude em graus decimais. Confira a entrada ou o acesso do local antes de confirmar a posição.',
                ),
                field('address', 'Endereço / orientação de acesso'),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    SizedBox(
                      width: 230,
                      child: field(
                        'lat',
                        'Latitude',
                        required: true,
                        max: 24,
                        hint: '-2.5307',
                        keyboard: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 230,
                      child: field(
                        'lng',
                        'Longitude',
                        required: true,
                        max: 24,
                        hint: '-44.3068',
                        keyboard: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    final state = ref.read(mapStateProvider);
                    final p = GeoPoint(
                      (state.bounds.south + state.bounds.north) / 2,
                      (state.bounds.west + state.bounds.east) / 2,
                    );
                    c('lat').text = p.lat.toStringAsFixed(6);
                    c('lng').text = p.lng.toStringAsFixed(6);
                    setState(() {
                      reference = true;
                    });
                  },
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Usar centro da área visível do mapa'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Localização aproximada'),
                  subtitle: const Text(
                    'Desative somente depois de conferir o acesso exato.',
                  ),
                  value: reference,
                  onChanged: (v) => setState(() {
                    reference = v;
                    dirty = true;
                  }),
                ),
                heading(
                  'Informações e contatos',
                  'Preencha apenas informações públicas e verificadas. Links devem começar com https://.',
                ),
                field('hours', 'Horários e observações', lines: 2, max: 500),
                field(
                  'phone',
                  'Telefone público',
                  max: 25,
                  keyboard: TextInputType.phone,
                ),
                field(
                  'whatsapp',
                  'WhatsApp com código do país',
                  max: 25,
                  hint: '+55 98 99999-9999',
                  keyboard: TextInputType.phone,
                ),
                field(
                  'website',
                  'Site oficial',
                  max: 2000,
                  keyboard: TextInputType.url,
                ),
                field(
                  'photoUrl',
                  'URL pública da foto',
                  max: 2000,
                  keyboard: TextInputType.url,
                ),
                field(
                  'sourceUrl',
                  'Fonte para conferência',
                  max: 2000,
                  keyboard: TextInputType.url,
                ),
                heading(
                  'Visibilidade',
                  'Rascunhos e arquivados ficam apenas na central. Empresas cadastradas aqui não recebem selo de parceiro nem ofertas.',
                ),
                DropdownButtonFormField<CatalogStatus>(
                  initialValue: status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Situação do cadastro',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final v in CatalogStatus.values)
                      DropdownMenuItem(value: v, child: Text(v.label)),
                  ],
                  onChanged: (v) => setState(() {
                    status = v!;
                    dirty = true;
                  }),
                ),
                const SizedBox(height: 20),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.save_outlined),
                  label: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(saving ? 'Salvando…' : 'Salvar cadastro'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class CatalogImport extends ConsumerStatefulWidget {
  const CatalogImport({super.key});
  @override
  ConsumerState<CatalogImport> createState() => _CatalogImportState();
}

class _CatalogImportState extends ConsumerState<CatalogImport> {
  final input = TextEditingController();
  List<CatalogEntry>? preview;
  String? error;
  bool saving = false;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Importar catálogo')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Restaure seu backup',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cole o JSON exportado pela central. Cadastros com o mesmo identificador serão atualizados; os demais serão preservados. Limite: 1.000 registros e 2 MB.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: input,
              maxLines: 12,
              maxLength: 2000000,
              decoration: const InputDecoration(
                labelText: 'JSON do catálogo',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onChanged: (_) => setState(() {
                preview = null;
                error = null;
              }),
            ),
            const SizedBox(height: 16),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            OutlinedButton(
              onPressed: saving
                  ? null
                  : () {
                      try {
                        final parsed = CatalogWorkspace.decode(input.text);
                        setState(() {
                          preview = parsed;
                          error = null;
                        });
                      } catch (e) {
                        setState(() {
                          preview = null;
                          error = e is FormatException
                              ? e.message
                              : 'JSON inválido.';
                        });
                      }
                    },
              child: const Text('Conferir importação'),
            ),
            if (preview case final rows?) ...[
              const SizedBox(height: 16),
              Text(
                '${rows.length} cadastros válidos • ${rows.where((e) => e.status == CatalogStatus.visible).length} visíveis no seu mapa',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final e in rows.take(8))
                ListTile(
                  title: Text(e.place.name),
                  subtitle: Text('${e.place.city} • ${e.status.label}'),
                ),
              if (rows.length > 8) Text('E mais ${rows.length - 8} registros.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: saving || rows.isEmpty
                    ? null
                    : () async {
                        setState(() => saving = true);
                        try {
                          final count = await ref
                              .read(mapStateProvider.notifier)
                              .importEntries(input.text);
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$count cadastros importados.'),
                            ),
                          );
                        } catch (e) {
                          if (mounted) {
                            setState(
                              () => error = e is FormatException
                                  ? e.message
                                  : 'Não foi possível importar.',
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => saving = false);
                          }
                        }
                      },
                child: Text(saving ? 'Importando…' : 'Confirmar importação'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
