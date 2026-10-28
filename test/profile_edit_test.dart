import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soma_ai/core/providers/session_provider.dart';
import 'package:soma_ai/features/profile/domain/profile_service.dart';
import 'package:soma_ai/features/profile/presentation/providers/profile_provider.dart';
import 'package:soma_ai/features/profile/presentation/widgets/edit_profile_sheet.dart';

class _FakeProfileService extends ProfileService {
  _FakeProfileService({this.error});

  final Object? error;
  int calls = 0;
  String? lastDisplayName;
  Uint8List? lastAvatarBytes;

  @override
  Future<ProfileUpdateResult> updateProfile({
    required String displayName,
    Uint8List? avatarBytes,
    String? avatarContentType,
    String? avatarExtension,
  }) async {
    calls++;
    lastDisplayName = displayName;
    lastAvatarBytes = avatarBytes;
    if (error != null) throw error!;
    return ProfileUpdateResult(displayName: displayName.trim());
  }
}

Future<ProviderContainer> _guestContainer(
  String name, {
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: overrides);
  await container.read(guestSessionProvider.notifier).start(name);
  return container;
}

Future<void> _pumpSheet(
  WidgetTester tester,
  ProviderContainer container,
) async {
  tester.view.physicalSize = const Size(420, 940);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showEditProfileSheet(context),
                child: const Text('Abrir edição'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Abrir edição'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileController', () {
    test('visitante atualiza apenas o apelido local', () async {
      final fake = _FakeProfileService();
      final container = await _guestContainer(
        'Edu',
        overrides: [profileServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final error = await container
          .read(profileControllerProvider.notifier)
          .updateProfile(name: '  Edu Silva  ');

      expect(error, isNull);
      expect(container.read(guestSessionProvider)?.name, 'Edu Silva');
      expect(fake.calls, 0, reason: 'visitante nunca chama o Supabase');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(GuestSessionNotifier.storageKey), 'Edu Silva');
    });

    test('visitante não pode trocar a foto', () async {
      final container = await _guestContainer('Edu');
      addTearDown(container.dispose);

      final error = await container
          .read(profileControllerProvider.notifier)
          .updateProfile(
            name: 'Edu',
            avatarBytes: Uint8List.fromList([1, 2, 3]),
          );

      expect(error, contains('Crie uma conta'));
      expect(container.read(guestSessionProvider)?.name, 'Edu');
    });

    test('conta real salva no serviço e retorna sucesso', () async {
      final fake = _FakeProfileService();
      final container = ProviderContainer(
        overrides: [profileServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final error = await container
          .read(profileControllerProvider.notifier)
          .updateProfile(name: 'Maria Souza');

      expect(error, isNull);
      expect(fake.calls, 1);
      expect(fake.lastDisplayName, 'Maria Souza');
      expect(
        container.read(profileControllerProvider),
        isA<AsyncData<void>>(),
      );
    });

    test('erro do serviço vira mensagem amigável', () async {
      final fake = _FakeProfileService(
        error: const ProfileUpdateException('Sem conexão com a internet.'),
      );
      final container = ProviderContainer(
        overrides: [profileServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final error = await container
          .read(profileControllerProvider.notifier)
          .updateProfile(name: 'Maria Souza');

      expect(error, 'Sem conexão com a internet.');
      expect(container.read(profileControllerProvider), isA<AsyncError<void>>());
    });
  });

  group('EditProfileSheet', () {
    testWidgets('pré-preenche, salva o apelido e fecha com snackbar verde',
        (tester) async {
      final container = await _guestContainer('Edu');
      addTearDown(container.dispose);

      await _pumpSheet(tester, container);

      expect(find.text('Editar perfil'), findsOneWidget);
      expect(find.text('Edu'), findsOneWidget);
      expect(find.text('Conta de visitante'), findsOneWidget);
      expect(
        find.text('Crie uma conta para vincular um e-mail.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField).first, 'Eduardo');
      await tester.tap(find.text('Salvar Alterações'));
      await tester.pumpAndSettle();

      expect(container.read(guestSessionProvider)?.name, 'Eduardo');
      expect(find.text('Editar perfil'), findsNothing);
      expect(find.text('Perfil atualizado com sucesso!'), findsOneWidget);
    });

    testWidgets('nome curto bloqueia o salvamento', (tester) async {
      final container = await _guestContainer('Edu');
      addTearDown(container.dispose);

      await _pumpSheet(tester, container);

      await tester.enterText(find.byType(TextFormField).first, 'E');
      await tester.tap(find.text('Salvar Alterações'));
      await tester.pumpAndSettle();

      expect(find.text('Informe pelo menos 2 caracteres.'), findsOneWidget);
      expect(container.read(guestSessionProvider)?.name, 'Edu');
      expect(find.text('Editar perfil'), findsOneWidget);
    });

    testWidgets('erro do Supabase mantém a modal aberta e mostra snackbar',
        (tester) async {
      final fake = _FakeProfileService(
        error: const ProfileUpdateException('Não foi possível salvar agora.'),
      );
      final container = ProviderContainer(
        overrides: [profileServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await _pumpSheet(tester, container);

      await tester.enterText(find.byType(TextFormField).first, 'Maria');
      await tester.tap(find.text('Salvar Alterações'));
      await tester.pumpAndSettle();

      expect(find.text('Editar perfil'), findsOneWidget);
      expect(find.text('Não foi possível salvar agora.'), findsOneWidget);
      expect(find.text('Perfil atualizado com sucesso!'), findsNothing);
    });
  });
}
