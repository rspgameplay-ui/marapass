import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/map_state.dart';
import '../maps/road_map.dart';
import 'track_recorder.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});
  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen>
    with WidgetsBindingObserver {
  late final TrackRecorder recorder;
  final name = TextEditingController();
  String mode = 'Caminhada';
  RecordedTrack? viewing;
  CameraRequest? camera;
  bool following = true;

  @override
  void initState() {
    super.initState();
    recorder = TrackRecorder(ref.read(repositoryProvider).preferences)
      ..addListener(refresh);
    WidgetsBinding.instance.addObserver(this);
  }

  void refresh() {
    if (!mounted) return;
    if (recorder.active && following && recorder.position != null) {
      camera = CameraRequest(recorder.position!, 16, (camera?.serial ?? 0) + 1);
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        (recorder.active ||
            (recorder.busy && state != AppLifecycleState.inactive))) {
      unawaited(
        recorder.pause(
          reason: 'Gravação pausada ao sair da tela. Toque em Continuar para retomar.',
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    recorder.removeListener(refresh);
    recorder.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final base = ref.watch(mapStateProvider);
    final track = viewing ?? recorder.draft;
    final first = track?.points.firstOrNull;
    final request =
        camera ??
        CameraRequest(
          first ?? base.request.target,
          first == null ? base.request.zoom : 15,
          0,
        );
    final seconds = viewing?.seconds ?? recorder.seconds;
    final duration =
        '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: const Text('Meus percursos')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: RoadMap(
                    state: base.copy(
                      places: [],
                      request: request,
                      clearSelection: true,
                    ),
                    reference: repo.roads,
                    creditTop: 8,
                    follow: viewing == null && following,
                    live: viewing == null ? recorder.position : null,
                    recordedSegments: track?.segments ?? [],
                    onGesture: () => setState(() => following = false),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                viewing?.name ??
                    (recorder.active
                        ? 'Gravando seu percurso'
                        : recorder.draft != null
                        ? 'Percurso em pausa'
                        : 'Grave sua experiência'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${(track?.kilometers ?? 0).toStringAsFixed(2)} km · $duration',
              ),
              if (viewing == null && recorder.accuracy != null)
                Text('Precisão do GPS ±${recorder.accuracy!.round()} m'),
              const SizedBox(height: 12),
              const Text(
                'Piloto em primeiro plano. Mantenha a página aberta e a tela ligada. Ao sair, a gravação é pausada. Os traçados ficam privados neste navegador/aparelho; limpar os dados do site pode apagá-los.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              if (recorder.message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(recorder.message!),
                ),
              const SizedBox(height: 12),
              if (viewing != null)
                OutlinedButton(
                  onPressed: () => setState(() {
                    viewing = null;
                    camera = null;
                  }),
                  child: const Text('Voltar à gravação'),
                )
              else ...[
                if (recorder.draft == null)
                  DropdownButtonFormField<String>(
                    initialValue: mode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Modalidade',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final value in [
                        'Caminhada',
                        'Corrida',
                        'Bicicleta',
                        'Passeio',
                      ])
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: recorder.busy
                        ? null
                        : (value) => setState(() => mode = value!),
                  ),
                const SizedBox(height: 12),
                if (recorder.active)
                  FilledButton.icon(
                    onPressed: () => recorder.pause(),
                    icon: const Icon(Icons.pause),
                    label: const Text('Pausar'),
                  )
                else
                  FilledButton.icon(
                    onPressed: recorder.busy || recorder.damaged
                        ? null
                        : () {
                            following = true;
                            unawaited(recorder.start(mode: mode));
                          },
                    icon: const Icon(Icons.fiber_manual_record),
                    label: Text(
                      recorder.busy
                          ? 'Aguarde o GPS…'
                          : recorder.draft != null
                          ? 'Continuar'
                          : 'Iniciar gravação',
                    ),
                  ),
                if (recorder.busy)
                  TextButton(
                    onPressed: () => recorder.pause(),
                    child: const Text('Cancelar busca de GPS'),
                  ),
                if (recorder.draft != null &&
                    !recorder.active &&
                    !recorder.busy) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Nome do percurso',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: recorder.canSave
                        ? () async {
                            if (await recorder.save(name.text)) name.clear();
                          }
                        : null,
                    child: const Text('Finalizar e salvar'),
                  ),
                  if (!recorder.canSave)
                    const Text(
                      'Caminhe alguns metros com o GPS ativo para registrar o traçado.',
                    ),
                  TextButton(
                    onPressed: () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (dialog) => AlertDialog(
                          title: const Text('Descartar este rascunho?'),
                          content: const Text(
                            'Os pontos desta gravação serão removidos do aparelho.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialog, false),
                              child: const Text('Manter'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dialog, true),
                              child: const Text('Descartar'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true && mounted) await recorder.discard();
                    },
                    child: const Text('Descartar rascunho'),
                  ),
                ],
              ],
              const SizedBox(height: 20),
              Text(
                'Salvos neste aparelho',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (recorder.saved.isEmpty)
                const Text('Seus percursos aparecerão aqui depois de salvar.'),
              for (final saved in recorder.saved)
                ListTile(
                  enabled: !recorder.active && !recorder.busy,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.route_outlined),
                  title: Text(saved.name),
                  subtitle: Text(
                    '${saved.mode} · ${saved.kilometers.toStringAsFixed(2)} km · ${saved.started.day}/${saved.started.month}/${saved.started.year}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() {
                    viewing = saved;
                    camera = CameraRequest(
                      saved.points.first,
                      15,
                      (camera?.serial ?? 0) + 1,
                    );
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
