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

/// Logo original na versão horizontal: o símbolo e o nome "MaraPass" do
/// arquivo oficial, lado a lado (ocupa menos altura no topo das telas).
class MpLogoHorizontal extends StatelessWidget {
  const MpLogoHorizontal({super.key, this.height = 44, this.white = false});
  final double height;
  final bool white;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'MaraPass',
    image: true,
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/brand/logo_mark.svg', height: height),
          SizedBox(width: height * .22),
          SvgPicture.asset(
            white ? 'assets/brand/logo_word_white.svg' : 'assets/brand/logo_word.svg',
            height: height * .5,
          ),
        ],
      ),
    ),
  );
}
