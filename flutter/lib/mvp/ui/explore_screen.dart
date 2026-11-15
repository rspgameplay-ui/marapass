import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'cards.dart';
import 'experience_screens.dart';
import 'home_screen.dart' show openOffer;

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});
  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int _segment = 0; // 0 passeios, 1 ofertas

  @override
  void initState() {
    super.initState();
    ref.listenManual(exploreSeedProvider, (_, next) {
      if (next != _ctrl.text) {
        _ctrl.text = next;
        setState(() => _query = next);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explorar')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s3),
            child: Column(
              children: [
                TextField(
                  key: const Key('explore-search'),
                  controller: _ctrl,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar passeios e ofertas',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _ctrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar busca',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: MP.s3),
                SegmentedButton<int>(
                  key: const Key('explore-segments'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Passeios'),
                      icon: Icon(Icons.explore_outlined),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Ofertas'),
                      icon: Icon(Icons.local_activity_outlined),
                    ),
                  ],
                  selected: {_segment},
                  onSelectionChanged: (s) => setState(() => _segment = s.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: MP.green,
                    selectedForegroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(MP.minTap),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _segment == 0
                ? _Experiences(query: _query)
                : _Offers(query: _query),
          ),
        ],
      ),
    );
  }
}

class _Experiences extends ConsumerWidget {
  const _Experiences({required this.query});
  final String query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = (query: query, category: '');
    final async = ref.watch(experiencesProvider(q));
    return async.when(
      loading: () => const MpLoading(),
      error: (e, _) => MpError(
        message: '$e',
        onRetry: () => ref.invalidate(experiencesProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return MpEmpty(
            icon: Icons.search_off_rounded,
            title: query.isEmpty
                ? 'Ainda não há passeios'
                : 'Nada encontrado para "$query"',
            message: query.isEmpty
                ? 'Os parceiros estão sendo cadastrados. Volte em breve.'
                : 'Tente outra palavra, como o nome do destino.',
          );
        }
        return RefreshIndicator(
          color: MP.green,
          onRefresh: () async {
            ref.invalidate(experiencesProvider);
            await ref.read(experiencesProvider(q).future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s8),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: MP.s3),
            itemBuilder: (_, i) => ExperienceCard(
              experience: list[i],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExperienceDetailScreen(experience: list[i]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Offers extends ConsumerWidget {
  const _Offers({required this.query});
  final String query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(offersProvider(query));
    return async.when(
      loading: () => const MpLoading(),
      error: (e, _) =>
          MpError(message: '$e', onRetry: () => ref.invalidate(offersProvider)),
      data: (List<Offer> list) {
        if (list.isEmpty) {
          return MpEmpty(
            icon: Icons.local_activity_outlined,
            title: query.isEmpty
                ? 'Nenhuma oferta no momento'
                : 'Nada encontrado para "$query"',
            message: 'As ofertas publicadas pelos parceiros aparecem aqui.',
          );
        }
        return RefreshIndicator(
          color: MP.green,
          onRefresh: () async {
            ref.invalidate(offersProvider);
            await ref.read(offersProvider(query).future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s8),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: MP.s3),
            itemBuilder: (_, i) => OfferCard(
              offer: list[i],
              onTap: () => openOffer(context, list[i]),
            ),
          ),
        );
      },
    );
  }
}
