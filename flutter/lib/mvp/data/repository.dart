/// Erro já traduzido para o turista: explica a causa e indica o que fazer.
class MvpException implements Exception {
  const MvpException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Operações de conta que não passam pela camada mvp_* (remote.dart).
/// A implementação real fala com o Supabase; a de demonstração não faz nada.
abstract class MvpRepository {
  Future<void> deleteMyAccount();
}
