import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../domain/municipality.dart';
import 'environment_data.dart';
import 'map_appearance.dart';

class EnvironmentControl extends ConsumerStatefulWidget {
  const EnvironmentControl({
    super.key,
    required this.city,
    this.service,
    this.compact = false,
  });
  final bool compact;
  final Municipality city;
  final EnvironmentService? service;
  @override
  ConsumerState<EnvironmentControl> createState() => _EnvironmentControlState();
}

class _EnvironmentControlState extends ConsumerState<EnvironmentControl> {
  Future<EnvironmentalForecast>? future;
  Timer? debounce, refresh;
  @override
  void initState() {
    super.initState();
    schedule();
    refresh = Timer.periodic(const Duration(minutes: 10), (_) => schedule());
  }

  @override
  void didUpdateWidget(EnvironmentControl old) {
    super.didUpdateWidget(old);
    if (old.city.id != widget.city.id) {
      future = null;
      schedule();
    }
  }

  void schedule() {
    debounce?.cancel();
    if (widget.service == null && AppConfig.supabaseUrl.isEmpty) return;
    debounce = Timer(const Duration(milliseconds: 900), () {
      if (mounted)
        setState(() {
          future = (widget.service ?? EnvironmentService.shared).load(
            widget.city.id,
          );
        });
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    refresh?.cancel();
    super.dispose();
  }

  String value(dynamic n, String unit) => n is num
      ? '${n.toStringAsFixed(n % 1 == 0 ? 0 : 1)}$unit'
      : 'Não informado';
  String date(dynamic iso) {
    final d = DateTime.tryParse('$iso')
        ?.toUtc()
        .subtract(const Duration(hours: 3));
    return d == null
        ? 'não informado'
        : '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} (UTC−3)';
  }

  void details(EnvironmentalForecast? data, Map<String, dynamic>? point) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .66,
          minChildSize: .35,
          maxChildSize: .94,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
            children: [
              Text(
                'Tempo e paisagem',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                widget.city.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              const Text(
                'Previsão por modelo para a sede municipal. As condições podem variar no trajeto.',
              ),
              if (point != null) ...[
                const SizedBox(height: 16),
                Text(
                  '${value(point['temperature'], ' °C')} · ${weatherDescription('${point['symbol']}')}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('Válida para ${date(point['time'])}'),
                Text(
                  'Modelo atualizado: ${date(data?.json['modelUpdatedAt'])}',
                ),
                if (data?.json['stale'] == true)
                  const Text(
                    'Última previsão disponível. Atualização temporariamente indisponível.',
                  ),
                const Divider(height: 28),
                Wrap(
                  spacing: 22,
                  runSpacing: 16,
                  children: [
                    metric('Vento a 10 m', value(point['windKmh'], ' km/h')),
                    metric(
                      'Origem do vento',
                      point['windFrom'] is num
                          ? '${windCompass(point['windFrom'])} · ${value(point['windFrom'], '°')}'
                          : 'Não informada',
                    ),
                    metric('Rajadas', value(point['gustKmh'], ' km/h')),
                    metric('Umidade', value(point['humidity'], '%')),
                    metric(
                      'Chuva / ${point['rainHours'] ?? '—'} h',
                      value(point['rainMm'], ' mm'),
                    ),
                  ],
                ),
                if (point['windFrom'] is num)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(
                      children: [
                        WindGlyph(from: (point['windFrom'] as num).toDouble()),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('A seta indica para onde o vento sopra.'),
                        ),
                      ],
                    ),
                  ),
                link(
                  'MET Norway · ECMWF — fonte da previsão',
                  'https://api.met.no/',
                ),
                link(
                  'Licença CC BY 4.0',
                  'https://creativecommons.org/licenses/by/4.0/',
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Previsão indisponível neste momento. Nenhuma condição foi estimada pelo aplicativo.',
                  ),
                ),
              const Divider(height: 28),
              Text(
                'Aparência do mapa',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final mode in MapAppearance.values)
                    ChoiceChip(
                      label: Text(switch (mode) {
                        MapAppearance.automatic => 'Automático',
                        MapAppearance.day => 'Dia',
                        MapAppearance.night => 'Noite',
                      }),
                      selected: ref.watch(mapAppearanceProvider) == mode,
                      onSelected: (_) =>
                          ref.read(mapAppearanceProvider.notifier).state = mode,
                    ),
                ],
              ),
              const Text('Automático: dia das 6h às 18h no Maranhão (UTC−3).'),
              const Divider(height: 28),
              Text(
                'Marés e ondas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                'Consulte a estação correspondente ao embarque. A maré de um porto não representa todas as ilhas. Altura das ondas ainda sem feed numérico integrado nesta versão.',
              ),
              link(
                'Tábuas de marés · Marinha do Brasil',
                'https://www.marinha.mil.br/chm/tabuas-de-mare-6',
              ),
              link(
                'Previsão de ondas · Marinha do Brasil',
                'https://pam.marinha.mil.br/ww3.html',
              ),
              const Text(
                'Antes de embarcar, confirme as condições e a operação com o transportador. A previsão turística não substitui cartas náuticas ou avisos oficiais.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget metric(String title, String text) => SizedBox(
    width: 145,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
  Widget link(String text, String url) => TextButton(
    style: TextButton.styleFrom(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 10),
    ),
    onPressed: () async {
      try {
        if (await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        ))
          return;
      } catch (_) {}
      if (mounted)
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir a fonte. Verifique a conexão.',
            ),
          ),
        );
    },
    child: Text(text),
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<EnvironmentalForecast>(
    future: future,
    builder: (context, snapshot) {
      final data = snapshot.data?.json['city']?['code'] == widget.city.id
          ? snapshot.data
          : null;
      final point = data?.at(DateTime.now());
      if (widget.compact)
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          elevation: 2,
          shadowColor: Colors.black12,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => details(data, point),
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    WeatherMark(
                      rain: '${point?["symbol"]}'.contains("rain"),
                      cloud: '${point?["symbol"]}'.contains("cloud"),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      point == null ? "—°" : value(point["temperature"], "°"),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      return Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(18),
        elevation: 2,
        shadowColor: const Color(0x18000000),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => details(data, point),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                WeatherMark(
                  rain: '${point?['symbol']}'.contains('rain'),
                  cloud: '${point?['symbol']}'.contains('cloud'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.city.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        point == null
                            ? (snapshot.connectionState ==
                                      ConnectionState.waiting
                                  ? 'Consultando previsão…'
                                  : 'Tempo e aparência')
                            : '${value(point['temperature'], '°')} · ${value(point['windKmh'], ' km/h')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (point?['windFrom'] is num)
                  Transform.rotate(
                    angle: ((point!['windFrom'] as num) + 180) * math.pi / 180,
                    child: CustomPaint(
                      size: const Size(14, 18),
                      painter: _ArrowPainter(),
                    ),
                  ),
                const Icon(Icons.expand_more, size: 16),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class WindGlyph extends StatefulWidget {
  const WindGlyph({super.key, required this.from});
  final double from;
  @override
  State<WindGlyph> createState() => _WindGlyphState();
}

class _WindGlyphState extends State<WindGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      pulse.stop();
    } else {
      pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pulse,
    builder: (context, _) => Opacity(
      opacity: .65 + .35 * pulse.value,
      child: Transform.rotate(
        angle: (widget.from + 180) * math.pi / 180,
        child: CustomPaint(size: const Size(24, 30), painter: _ArrowPainter()),
      ),
    ),
  );
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawPath(
      Path()
        ..moveTo(s.width * .5, 0)
        ..lineTo(s.width, s.height)
        ..lineTo(s.width * .5, s.height * .75)
        ..lineTo(0, s.height)
        ..close(),
      Paint()..color = const Color(0xff54777a),
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}

class WeatherMark extends StatelessWidget {
  const WeatherMark({super.key, this.rain = false, this.cloud = false});
  final bool rain, cloud;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(25, 25),
    painter: _WeatherPainter(rain, cloud),
  );
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter(this.rain, this.cloud);
  final bool rain, cloud;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xffa08355)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    c.drawCircle(const Offset(11, 10), 5, p);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawLine(
        Offset(11 + 8 * math.cos(a), 10 + 8 * math.sin(a)),
        Offset(11 + 10 * math.cos(a), 10 + 10 * math.sin(a)),
        p,
      );
    }
    if (cloud || rain) {
      p.color = const Color(0xff54777a);
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(7, 12, 17, 8),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xffedf1ef),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(7, 12, 17, 8),
          const Radius.circular(4),
        ),
        p,
      );
    }
    if (rain) {
      for (var x = 10.0; x < 24; x += 5)
        c.drawLine(Offset(x, 22), Offset(x - 1, 25), p);
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter old) =>
      rain != old.rain || cloud != old.cloud;
}
