import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reserva_escolar_app/main.dart';
import 'package:reserva_escolar_app/models/user_model.dart';
import 'package:reserva_escolar_app/providers/app_preferences_provider.dart';
import 'package:reserva_escolar_app/providers/auth_provider.dart';
import 'package:reserva_escolar_app/screens/home_screen.dart';
import 'package:reserva_escolar_app/screens/lesson_slot_admin_screen.dart';
import 'package:reserva_escolar_app/screens/teacher_admin_screen.dart';
import 'package:reserva_escolar_app/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.clearAuthToken();
  });

  testWidgets('Exibe tela de login quando nao autenticado', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ReservaEscolarApp());
    await tester.pumpAndSettle();

    expect(find.text('Reserva Escolar'), findsOneWidget);
    expect(find.text('Acesso'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.byIcon(Icons.school), findsOneWidget);
  });

  testWidgets('Exibe erros de validacao ao tentar login invalido', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ReservaEscolarApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.enterText(find.byType(TextFormField).at(1), '');
    await tester.enterText(find.byType(TextFormField).at(2), '');

    final loginButton = find.text('Entrar');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Informe o código da escola'), findsOneWidget);
    expect(find.text('Informe o email'), findsOneWidget);
    expect(find.text('Informe a senha'), findsOneWidget);
  });

  testWidgets('Restaura sessao salva e abre a tela inicial', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final savedUser = UserModel(
      id: 1,
      schoolId: 1,
      name: 'Tecnico Teste',
      email: 'tecnico@escola.com',
      role: 'technician',
      schoolName: 'Escola Teste',
      schoolCode: 'ESC001',
      authToken: 'test-token',
      authTokenExpiresAt: '2099-12-31 23:59:59',
    );

    SharedPreferences.setMockInitialValues({
      'auth_session_user': jsonEncode(savedUser.toJson()),
    });

    await tester.pumpWidget(const ReservaEscolarApp());
    await tester.pumpAndSettle();

    expect(find.text('Painel técnico'), findsOneWidget);
    expect(find.text('Escola Teste'), findsWidgets);
  });

  testWidgets('Valida troca de senha na area da conta', (
    WidgetTester tester,
  ) async {
    await _pumpAuthenticatedScreen(tester, const HomeScreen());

    await tester.tap(find.byTooltip('Abrir menu da conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alterar senha'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atualizar senha'));
    await tester.pump();

    expect(find.text('Informe a senha atual'), findsOneWidget);
    expect(find.text('Informe a nova senha'), findsOneWidget);
    expect(find.text('Confirme a nova senha'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha atual'),
      '123456',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nova senha'),
      '123456',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar nova senha'),
      '654321',
    );

    await tester.tap(find.text('Atualizar senha'));
    await tester.pump();

    expect(
      find.text('A nova senha deve ser diferente da atual'),
      findsOneWidget,
    );
    expect(find.text('As senhas não conferem'), findsOneWidget);
  });

  testWidgets('Valida email e senha no dialogo de professor', (
    WidgetTester tester,
  ) async {
    await _runWithFakeHttp(() async {
      await _pumpAuthenticatedScreen(tester, const TeacherAdminScreen());

      await tester.tap(find.text('Novo professor'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'Ana');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'email-invalido',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha inicial'),
        '123',
      );

      await tester.tap(find.text('Criar'));
      await tester.pump();

      expect(find.text('Informe um email válido'), findsOneWidget);
      expect(find.text('Use ao menos 6 caracteres'), findsOneWidget);
    });
  });

  testWidgets('Valida numero, rotulo e horario no dialogo de aula', (
    WidgetTester tester,
  ) async {
    await _runWithFakeHttp(() async {
      await _pumpAuthenticatedScreen(tester, const LessonSlotAdminScreen());

      await tester.tap(find.text('Nova aula'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Número da aula'),
        '0',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Rótulo'), '');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Hora inicial (HH:MM:SS)'),
        '08:00',
      );

      await tester.tap(find.text('Criar'));
      await tester.pump();

      expect(find.text('Informe um número de aula válido'), findsOneWidget);
      expect(find.text('Informe o rótulo da aula'), findsOneWidget);
      expect(find.text('Use o formato HH:MM:SS'), findsOneWidget);
    });
  });
}

Future<void> _pumpAuthenticatedScreen(
  WidgetTester tester,
  Widget screen,
) async {
  ApiService.setAuthToken('test-token');
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuthProvider()),
        ChangeNotifierProvider(
          create: (_) => AppPreferencesProvider(),
        ),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _runWithFakeHttp(Future<void> Function() body) async {
  final previous = HttpOverrides.current;
  HttpOverrides.global = _FakeHttpOverrides();
  try {
    await body();
  } finally {
    HttpOverrides.global = previous;
  }
}

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider() : super(restoreSessionOnInit: false);

  static final UserModel _testUser = UserModel(
    id: 1,
    schoolId: 1,
    name: 'Tecnico Teste',
    email: 'tecnico@escola.com',
    role: 'technician',
    schoolName: 'Escola Teste',
    schoolCode: 'ESC001',
    authToken: 'test-token',
    authTokenExpiresAt: '2099-12-31 23:59:59',
  );

  @override
  UserModel? get user => _testUser;

  @override
  bool get isAuthenticated => true;

  @override
  Future<void> logout() async {}
}

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _FakeHttpClientRequest(method, url);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.method, this._uri);

  @override
  final String method;
  final Uri _uri;
  final HttpHeaders _headers = _FakeHttpHeaders();
  final BytesBuilder _body = BytesBuilder();

  @override
  Uri get uri => _uri;

  @override
  HttpHeaders get headers => _headers;

  @override
  Encoding encoding = utf8;

  @override
  Future<HttpClientResponse> close() async {
    final payload = _buildPayload(method, uri, _body.toBytes());
    return _FakeHttpClientResponse(payload);
  }

  Map<String, dynamic> _buildPayload(
    String method,
    Uri url,
    List<int> bodyBytes,
  ) {
    if (method == 'GET') {
      return {'success': true, 'data': []};
    }

    return {
      'success': true,
      'message': 'Operação concluída.',
      'data': [],
      if (bodyBytes.isNotEmpty) 'request_body': utf8.decode(bodyBytes),
    };
  }

  @override
  void add(List<int> data) {
    _body.add(data);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _body.add(chunk);
    }
  }

  @override
  Future<void> flush() async {}

  @override
  void write(Object? obj) {
    _body.add(encoding.encode(obj?.toString() ?? ''));
  }

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) {
    write(String.fromCharCode(charCode));
  }

  @override
  void writeln([Object? obj = '']) {
    write('${obj ?? ''}\n');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(Map<String, dynamic> payload)
    : _bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));

  final Uint8List _bytes;

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => const [];

  @override
  Future<Socket> detachSocket() {
    throw UnimplementedError();
  }

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void clear() {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  void noFolding(String name) {}

  @override
  void remove(String name, Object value) {}

  @override
  void removeAll(String name) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  String? value(String name) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
