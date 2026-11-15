import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/map_state.dart';
import '../domain/municipality.dart';
import '../domain/tourism.dart';
import 'brand.dart';

class CityDirectory extends ConsumerStatefulWidget {
  const CityDirectory({super.key});
  @override
  ConsumerState<CityDirectory> createState() => _CityDirectoryState();
}

class _CityDirectoryState extends ConsumerState<CityDirectory> {
  String query = '';
  String? region;
  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final all = repo.municipalities;
    final regions = all.map((m) => m.intermediateRegion).toSet().toList()
      ..sort();
    final cities =
        all
            .where(
              (m) =>
                  (region == null || m.intermediateRegion == region) &&
                  normalize('${m.name} ${m.region} ${m.id}')
                      .contains(normalize(query)),
            )
            .toList()
          ..sort((a, b) => normalize(a.name).compareTo(normalize(b.name)));
    return Scaffold(
      appBar: AppBar(title: const Text('Cidade por cidade')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Todo o Maranhão.\nSeu próximo destino.',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: MaraColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${all.length} municípios • sedes e limites oficiais do IBGE',
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      onChanged: (v) => setState(() => query = v),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Buscar município ou código IBGE',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: region,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Região Geográfica Intermediária (IBGE)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Todo o estado'),
                        ),
                        for (final r in regions)
                          DropdownMenuItem(
                            value: r,
                            child: Text(r, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => region = v == '' ? null : v),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: cities.length,
                  itemBuilder: (context, i) {
                    final m = cities[i];
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xffe9eff9),
                          child: Icon(
                            Icons.location_city,
                            color: MaraColors.navy,
                          ),
                        ),
                        title: Text(
                          m.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${m.mappedPlaces} pontos na extração OSM • IBGE ${m.id}\nRegião imediata: ${m.region}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop<Municipality>(context, m),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
