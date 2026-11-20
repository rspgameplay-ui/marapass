import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'repository.dart';

/// Implementação real. As telas falam com o servidor pela camada mvp_*
/// (remote.dart); aqui fica só a exclusão de conta.
class SupabaseMvpRepository implements MvpRepository {
  SupabaseMvpRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<void> deleteMyAccount() async {
    if (_client.auth.currentUser == null) {
      throw const MvpException('Entre na sua conta para continuar.');
    }
    try {
      await _client.rpc('delete_my_account');
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' || e.code == '42883') {
        throw const MvpException(
          'A exclusão automática ainda não está ativa. Escreva para o suporte e removemos seus dados.',
        );
      }
      throw translateError(e);
    } catch (e) {
      throw translateError(e);
    }
    await _client.auth.signOut();
  }
}

/// Converte falhas técnicas em mensagens que dizem o que aconteceu e o que fazer.
MvpException translateError(Object e) {
  final raw =
      (e is PostgrestException ? '${e.message} ${e.details ?? ''}' : '$e')
          .toLowerCase();
  // Regras de negócio do banco já vêm com a mensagem em português.
  if (e is PostgrestException && e.code == 'P0001' && e.message.isNotEmpty) {
    return MvpException(e.message);
  }
  if (e is AuthException) {
    if (raw.contains('expired') || raw.contains('invalid')) {
      return const MvpException(
        'Código inválido ou vencido. Peça um novo código.',
      );
    }
    if (raw.contains('rate') || raw.contains('seconds')) {
      return const MvpException(
        'Aguarde um instante antes de pedir outro código.',
      );
    }
    return const MvpException(
      'Não foi possível entrar. Confira o e-mail e tente de novo.',
    );
  }
  if (raw.contains('jwt') ||
      raw.contains('not authenticated') ||
      raw.contains('permission denied') ||
      (e is PostgrestException && e.code == '42501')) {
    return const MvpException(
      'Sua sessão expirou. Entre de novo para continuar.',
    );
  }
  if (raw.contains('capacity') ||
      raw.contains('full') ||
      raw.contains('no seats') ||
      raw.contains('vaga')) {
    return const MvpException(
      'Esse horário não tem mais vagas. Escolha outro.',
    );
  }
  if (raw.contains('issue limit')) {
    return const MvpException('Os cupons desta oferta esgotaram.');
  }
  if (raw.contains('limit') || raw.contains('already')) {
    return const MvpException('Você já atingiu o limite desta oferta.');
  }
  if (raw.contains('expired') ||
      raw.contains('ended') ||
      raw.contains('window')) {
    return const MvpException('Esta oferta já terminou.');
  }
  if (raw.contains('not published') ||
      raw.contains('unavailable') ||
      raw.contains('paused') ||
      raw.contains('not found')) {
    return const MvpException('Esta oferta não está mais disponível.');
  }
  if (e is TimeoutException ||
      raw.contains('socket') ||
      raw.contains('clientexception') ||
      raw.contains('failed host') ||
      raw.contains('network') ||
      raw.contains('connection')) {
    return const MvpException(
      'Sem conexão. Confira a internet e tente de novo.',
    );
  }
  return const MvpException(
    'Não foi possível concluir agora. Tente de novo em instantes.',
  );
}
