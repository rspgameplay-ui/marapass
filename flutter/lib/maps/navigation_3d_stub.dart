import 'package:flutter/widgets.dart';

bool get navigation3dSupported => false;

class Navigation3DCanvas extends StatelessWidget {
  const Navigation3DCanvas({
    super.key,
    required this.frame,
    required this.onGesture,
    required this.onPlace,
    required this.onUnavailable,
  });

  final Map<String, dynamic> frame;
  final VoidCallback onGesture, onUnavailable;
  final ValueChanged<String> onPlace;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
