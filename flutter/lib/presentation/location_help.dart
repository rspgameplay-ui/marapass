import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../location/location_service.dart';

Future<void> showLocationHelp(
  BuildContext context, {
  LocationFailure? failure,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheet) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Usar minha localização',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (failure != null) Text(failure.message),
          const SizedBox(height: 16),
          const Text(
            '1. Abra o link diretamente no Safari ou Chrome. Uma janela interna do ChatGPT pode limitar a localização.\n\n2. Nas permissões do site, permita Localização. No iPhone, confira Ajustes → Privacidade e Segurança → Serviços de Localização → Sites do Safari e habilite Localização Precisa. Os nomes podem variar conforme a versão do sistema.\n\n3. Volte ao mapa e toque em Iniciar com meu GPS. Aguarde até 30 segundos em local aberto.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Sua posição é usada para centralizar e acompanhar o percurso. As coordenadas necessárias ao cálculo são enviadas ao serviço OSRM/FOSSGIS. A navegação funciona em primeiro plano; simular não utiliza seu GPS.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final url = Uri.parse(AppConfig.controlCenterUrl)
                  .replace(path: '/', queryParameters: {})
                  .toString();
              await Clipboard.setData(ClipboardData(text: url));
              if (sheet.mounted)
                ScaffoldMessenger.of(sheet).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Link copiado. Cole na barra do Safari ou Chrome.',
                    ),
                  ),
                );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar link do mapa'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(sheet),
            child: const Text('Voltar ao mapa'),
          ),
        ],
      ),
    ),
  ),
);
