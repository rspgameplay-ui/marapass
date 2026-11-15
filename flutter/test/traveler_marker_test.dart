import 'package:flutter_test/flutter_test.dart';
import 'package:marapass_mapa/navigation/traveler_marker.dart';
void main(){
 test('heading interpolation crosses north using the shortest arc',(){expect(headingDelta(359,1),2);expect(headingDelta(1,359),-2);});
 test('Portuguese cardinal labels',(){expect(directionLabel(0),'norte');expect(directionLabel(90),'leste');expect(directionLabel(359),'norte');});
}
