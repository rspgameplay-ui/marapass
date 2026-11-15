import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/map_state.dart';
import '../core/config.dart';
import 'brand.dart';
import 'catalog_center.dart';

class ControlCenter extends ConsumerWidget {
  const ControlCenter({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(mapStateProvider);
    final catalog = ref.read(repositoryProvider).publishedCatalog;
    final checked = catalog.checkedAt?.toLocal();
    return Scaffold(
      appBar: AppBar(title: const Text('Central do mapa')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            size: 52,
            color: MaraColors.navy,
          ),
          const SizedBox(height: 20),
          const Text(
            'Um catálogo. Todos os dispositivos.',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'No painel MaraPass, crie um rascunho compartilhado, confira a prévia e publique. Cada alteração mantém responsável, motivo e versão anterior.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final success = await launchUrl(
                Uri.parse(AppConfig.controlCenterUrl),
                mode: LaunchMode.externalApplication,
              );
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Não foi possível abrir o painel. Confira a conexão.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir painel compartilhado'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Use sua conta MaraPass autorizada e confirme o segundo fator. O acesso privado desta prévia também exige sua conta ChatGPT.',
            style: TextStyle(fontSize: 13),
          ),
          const Divider(height: 40),
          Text(
            catalog.offline
                ? 'Sem atualização confirmada. Exibindo o último catálogo recebido.'
                : checked == null
                ? 'Consulta de publicações ainda não confirmada.'
                : 'Publicações sincronizadas pelo aplicativo.',
          ),
          if (checked != null)
            Text(
              'Última consulta: ${checked.day.toString().padLeft(2, '0')}/${checked.month.toString().padLeft(2, '0')}/${checked.year} ${checked.hour.toString().padLeft(2, '0')}:${checked.minute.toString().padLeft(2, '0')}',
            ),
          OutlinedButton.icon(
            onPressed: ref.watch(mapStateProvider).loading
                ? null
                : () async {
                    await ref.read(mapStateProvider.notifier).refresh();
                  },
            icon: const Icon(Icons.sync),
            label: const Text('Buscar publicações agora'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Com conexão, o mapa consulta publicações a cada 30 segundos e ao voltar para o aplicativo. Rascunhos e histórico privado não são enviados aos visitantes.',
            style: TextStyle(fontSize: 13),
          ),
          const Divider(height: 40),
          ExpansionTile(
            title: const Text('Área de trabalho deste aparelho'),
            subtitle: const Text('Cadastros locais e backups anteriores'),
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Esta área continua disponível para recuperar cadastros anteriores. Ela não publica para outros aparelhos. Pontos já administrados pelo painel usam a versão pública compartilhada.',
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CatalogCenter(),
                  ),
                ),
                child: const Text('Abrir cadastros locais'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
