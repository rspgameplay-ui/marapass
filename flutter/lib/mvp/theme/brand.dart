import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logo original do MaraPass (protótipo aprovado): cata-vento e nome.
/// `white` usa a versão para fundos escuros e fotos.
class MpLogo extends StatelessWidget {
  const MpLogo({super.key, this.width = 84, this.white = false});
  final double width;
  final bool white;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'MaraPass',
    image: true,
    child: SvgPicture.asset(
      white ? 'assets/brand/logo_white.svg' : 'assets/brand/logo.svg',
      width: width,
      excludeFromSemantics: true,
    ),
  );
}
