import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../i18n.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/png_download.dart';
import '../data/content.dart';
import '../theme/brand.dart';
import '../theme/tokens.dart';
import '../theme/widgets.dart';
import 'checkin.dart';

/// Conteúdo do QR da placa de um local (lido pelo leitor do app).
/// Com o token secreto da placa (impresso só na placa física), o servidor
/// aceita o check-in sem GPS.
String plateQr(Item i, {String? token}) =>
    'marapass:plate:${plateCode(i)}${token == null ? '' : ':$token'}';

/// Conteúdo do QR de uma oferta de parceiro (vira cupom ao ser lido).
String offerQr(String cupomId) => 'marapass:offer:$cupomId';

/// Gera um PNG em alta resolução a partir de um RepaintBoundary e baixa.
Future<void> savePng(BuildContext context, GlobalKey key, String fileName) async {
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final image = await boundary.toImage(pixelRatio: 4);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null || !context.mounted) return;
  final ok = downloadPng(data.buffer.asUint8List(), fileName);
  showMpSnack(
    context,
    ok ? '${tr('Placa baixada')}: $fileName' : tr('Para baixar e imprimir, abra o painel pela versão web.'),
  );
}

/// Placa MaraPass para imprimir (A6, retrato) e fixar no balcão ou na entrada.
class PlateArt extends StatelessWidget {
  const PlateArt({super.key, required this.item});
  final Item item;
  @override
  Widget build(BuildContext context) => MediaQuery(
    // A placa é impressa: tamanho fixo, sem a "Letra grande" do app.
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
    child: SizedBox(
    width: 300,
    height: 425,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MP.border),
      ),
      child: Column(
        children: [
          Container(
            height: 78,
            decoration: const BoxDecoration(
              color: MP.navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                MpLogo(width: 64, white: true),
                Spacer(),
                Text(
                  tr('Registre\nsua visita'),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: MP.yellow, fontWeight: FontWeight.w800, fontSize: 15, height: 1.15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          QrImageView(
            data: plateQr(item),
            size: 180,
            padding: EdgeInsets.zero,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: MP.navy),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: MP.ink),
          ),
          const SizedBox(height: 8),
          Text(
            plateCode(item),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 3, color: MP.ink),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              item.titulo,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: MP.navy, height: 1.2),
            ),
          ),
          Text(item.cidade, style: const TextStyle(fontSize: 13, color: MP.textSecondary)),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: MP.soft,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(17)),
                ),
                child: Text(
                  tr('Abra o app MaraPass › Registrar visita e aponte a câmera para o QR. Ganhe pontos e o carimbo do polo.'),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: MP.text, height: 1.35),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    ),
  );
}

/// Lista de placas por local, para o parceiro baixar e imprimir.
class PlatesScreen extends StatefulWidget {
  const PlatesScreen({super.key});
  @override
  State<PlatesScreen> createState() => _PlatesScreenState();
}

class _PlatesScreenState extends State<PlatesScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = Content.items
        .where((i) => i.cat != Cat.transporte && i.cat != Cat.fotografia)
        .where((i) => _q.isEmpty || '${i.titulo} ${i.cidade}'.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s8),
          children: [
            MpHeader(tr('Placas MaraPass'), subtitle: tr('QR para o turista registrar a visita no seu local.')),
            Padding(
              padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s3),
              child: TextField(
                key: const Key('plates-search'),
                decoration: InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: tr('Buscar local')),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            for (final i in list)
              Padding(
                padding: const EdgeInsets.fromLTRB(MP.pageH, 0, MP.pageH, MP.s2),
                child: MpListTile(
                  key: Key('plate-${i.id}'),
                  icon: Icons.qr_code_2_rounded,
                  tint: MP.tintBlue,
                  color: MP.navy,
                  title: i.titulo,
                  subtitle: '${i.cidade} · ${plateCode(i)}',
                  onTap: () => push<void>(context, PlatePreviewScreen(item: i)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PlatePreviewScreen extends StatefulWidget {
  const PlatePreviewScreen({super.key, required this.item});
  final Item item;
  @override
  State<PlatePreviewScreen> createState() => _PlatePreviewState();
}

class _PlatePreviewState extends State<PlatePreviewScreen> {
  final _key = GlobalKey();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    return Scaffold(
      backgroundColor: MP.soft,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(MP.pageH, MP.s3, MP.pageH, MP.s3),
          child: MpPrimaryButton(
            key: const Key('plate-download'),
            label: tr('Baixar placa (PNG)'),
            icon: Icons.download_rounded,
            busy: _busy,
            onPressed: () async {
              setState(() => _busy = true);
              await savePng(context, _key, 'placa-${plateCode(i)}.png');
              if (mounted) setState(() => _busy = false);
            },
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: MP.s6),
          children: [
            MpHeader(tr('Placa do local'), subtitle: i.titulo),
            Center(child: RepaintBoundary(key: _key, child: PlateArt(item: i))),
            const SizedBox(height: MP.s4),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: MP.pageH),
              child: MpNotice(
                tr('Imprima em tamanho A6 (10,5 × 14,8 cm), de preferência plastificada, e fixe no balcão ou na entrada, em altura de leitura. O código embaixo do QR serve para quem não conseguir usar a câmera.'),
                icon: Icons.print_rounded,
                fg: MP.info,
                bg: MP.infoBg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// QR de uma oferta ativa, para o parceiro exibir no balcão.
class OfferQrCard extends StatefulWidget {
  const OfferQrCard({super.key, required this.cupomId, required this.title});
  final String cupomId, title;
  @override
  State<OfferQrCard> createState() => _OfferQrCardState();
}

class _OfferQrCardState extends State<OfferQrCard> {
  final _key = GlobalKey();
  @override
  Widget build(BuildContext context) => MpCard(
    key: const Key('offer-qr'),
    child: Column(
      children: [
        Text(tr('QR da oferta para o balcão'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: MP.s1),
        Text(
          tr('O turista lê no app e ativa o cupom na hora.'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: MP.textSecondary),
        ),
        const SizedBox(height: MP.s3),
        RepaintBoundary(
          key: _key,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: offerQr(widget.cupomId),
                  size: 180,
                  padding: EdgeInsets.zero,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: MP.navy),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: MP.ink),
                ),
                const SizedBox(height: 6),
                Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, color: MP.navy)),
              ],
            ),
          ),
        ),
        const SizedBox(height: MP.s3),
        OutlinedButton.icon(
          key: const Key('offer-qr-download'),
          onPressed: () => savePng(context, _key, 'oferta-${widget.cupomId.replaceAll(':', '-')}.png'),
          icon: const Icon(Icons.download_rounded),
          label: Text(tr('Baixar QR (PNG)')),
        ),
      ],
    ),
  );
}
