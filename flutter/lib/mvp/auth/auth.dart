import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repository.dart';
import '../data/supabase_repository.dart' show translateError;

class AuthUser {
  const AuthUser({required this.id, this.email});
  final String id;
  final String? email;
}

/// Acesso à autenticação. Login sem senha: código de uso único por e-mail.
abstract class AuthGateway {
  AuthUser? get current;
  Stream<AuthUser?> get changes;
  Future<void> sendCode(String email);
  Future<void> verifyCode(String email, String code);
  Future<void> signOut();
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);
  final SupabaseClient _client;

  AuthUser? _map(User? u) =>
      u == null ? null : AuthUser(id: u.id, email: u.email);

  @override
  AuthUser? get current => _map(_client.auth.currentUser);

  @override
  Stream<AuthUser?> get changes =>
      _client.auth.onAuthStateChange.map((s) => _map(s.session?.user));

  @override
  Future<void> sendCode(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: true,
      );
    } catch (e) {
      throw translateError(e);
    }
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    try {
      await _client.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: OtpType.email,
      );
    } catch (e) {
      throw translateError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw translateError(e);
    }
  }
}

/// Gateway de demonstração e de testes: o código é sempre 123456.
class DemoAuthGateway implements AuthGateway {
  final _ctrl = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;
  int sendCalls = 0;

  static const demoCode = '123456';

  @override
  AuthUser? get current => _user;

  @override
  Stream<AuthUser?> get changes => _ctrl.stream;

  @override
  Future<void> sendCode(String email) async {
    sendCalls++;
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    if (code.trim() != demoCode) {
      throw const MvpException(
        'Código inválido ou vencido. Peça um novo código.',
      );
    }
    _user = AuthUser(id: 'demo-user', email: email.trim());
    _ctrl.add(_user);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _ctrl.add(null);
  }
}

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => throw UnimplementedError('authGatewayProvider precisa de override'),
);

/// Usuário atual. `null` = visitante (pode explorar, não pode emitir nem reservar).
class AuthNotifier extends Notifier<AuthUser?> {
  @override
  AuthUser? build() {
    final gw = ref.watch(authGatewayProvider);
    final sub = gw.changes.listen((u) => state = u);
    ref.onDispose(sub.cancel);
    return gw.current;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthUser?>(
  AuthNotifier.new,
);
