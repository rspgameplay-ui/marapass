import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/application/navigation_session.dart';
import 'package:marapass_mapa/data/routing_repository.dart';
import 'navigation_test.dart' show road;
void main(){test('simulação inicia sem GPS e parar cancela o avanço',()async{
 final repo=RoutingRepository();final n=NavigationSession(repo)..routes=[road()]..phase=NavigationPhase.preview;
 n.startSimulation();expect(n.simulating,isTrue);expect(n.active,isTrue);
 await Future<void>.delayed(const Duration(milliseconds:950));expect(n.meters,greaterThan(0));
 await n.pause();expect(n.simulating,isFalse);expect(n.active,isFalse);final m=n.meters;
 await Future<void>.delayed(const Duration(milliseconds:950));expect(n.meters,m);n.dispose();repo.client.close();
});}
