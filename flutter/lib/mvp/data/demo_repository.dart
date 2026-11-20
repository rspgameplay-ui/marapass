import 'repository.dart';

/// Repositório em memória: usado nos testes e no modo demonstração
/// (`--dart-define=MVP_DEMO=true` ou quando o Supabase não está configurado).
class DemoMvpRepository implements MvpRepository {
  @override
  Future<void> deleteMyAccount() async {}
}
