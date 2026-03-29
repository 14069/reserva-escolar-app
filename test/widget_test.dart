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
import 'package:reserva_escolar_app/screens/booking_admin_screen.dart';
import 'package:reserva_escolar_app/screens/home_screen.dart';
import 'package:reserva_escolar_app/screens/lesson_slot_admin_screen.dart';
import 'package:reserva_escolar_app/screens/reports_admin_screen.dart';
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

  testWidgets('Filtra agendamentos administrativos por busca e status', (
    WidgetTester tester,
  ) async {
    await _runWithFakeHttp(() async {
      tester.view.physicalSize = const Size(1440, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpAuthenticatedScreen(tester, const BookingAdminScreen());

      expect(find.text('Laboratorio 01'), findsOneWidget);
      expect(find.text('Projetor movel'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar agendamento'),
        'projetor',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Projetor movel'), findsOneWidget);
      expect(find.text('Laboratorio 01'), findsNothing);

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Status'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelado').last);
      await tester.pumpAndSettle();

      expect(find.text('Projetor movel'), findsOneWidget);
      expect(find.text('Cancelar'), findsNothing);
    });
  });

  testWidgets('Filtra professores por busca e status', (
    WidgetTester tester,
  ) async {
    await _runWithFakeHttp(() async {
      tester.view.physicalSize = const Size(1440, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpAuthenticatedScreen(tester, const TeacherAdminScreen());

      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.text('Bruno Lima'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Ordenar por'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nome (Z-A)').last);
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Bruno Lima')).dy,
        lessThan(tester.getTopLeft(find.text('Ana Souza')).dy),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar professor'),
        'bruno',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Bruno Lima'), findsOneWidget);
      expect(find.text('Ana Souza'), findsNothing);

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Status'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inativo').last);
      await tester.pumpAndSettle();

      expect(find.text('Bruno Lima'), findsOneWidget);
      expect(find.text('Ativo'), findsNothing);
    });
  });

  testWidgets('Carrega relatorios administrativos com resumo paginado', (
    WidgetTester tester,
  ) async {
    await _runWithFakeHttp(() async {
      tester.view.physicalSize = const Size(1440, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpAuthenticatedScreen(tester, const ReportsAdminScreen());

      expect(find.text('Projetor movel'), findsWidgets);
      expect(find.text('Laboratorio 01'), findsWidgets);
      expect(find.text('Exibindo todas as 2 reservas'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Professor'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bruno Lima').last);
      await tester.pumpAndSettle();

      expect(find.text('Projetor movel'), findsWidgets);
      expect(find.text('Laboratorio 01'), findsNothing);
      expect(find.text('Exibindo 1 de 2 reservas'), findsOneWidget);
    });
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
        ChangeNotifierProvider(create: (_) => AppPreferencesProvider()),
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
      if (url.path.contains('get_teachers.php')) {
        final teachers = [
          {
            'id': 1,
            'school_id': 1,
            'name': 'Ana Souza',
            'email': 'ana@escola.com',
            'role': 'teacher',
            'active': 1,
            'created_at': '2026-03-29 09:00:00',
          },
          {
            'id': 2,
            'school_id': 1,
            'name': 'Bruno Lima',
            'email': 'bruno@escola.com',
            'role': 'teacher',
            'active': 0,
            'created_at': '2026-03-29 09:10:00',
          },
        ];

        final search = (url.queryParameters['search'] ?? '').toLowerCase();
        final status = url.queryParameters['status'];
        final sort = url.queryParameters['sort'] ?? 'name_asc';
        final page = int.tryParse(url.queryParameters['page'] ?? '1') ?? 1;
        final pageSize =
            int.tryParse(url.queryParameters['page_size'] ?? '20') ?? 20;

        var filtered = teachers.where((teacher) {
          final matchesSearch =
              search.isEmpty ||
              (teacher['name'] as String).toLowerCase().contains(search) ||
              (teacher['email'] as String).toLowerCase().contains(search);
          final matchesStatus =
              status == null ||
              (status == 'active' && teacher['active'] == 1) ||
              (status == 'inactive' && teacher['active'] != 1);
          return matchesSearch && matchesStatus;
        }).toList();

        filtered.sort((a, b) {
          switch (sort) {
            case 'name_desc':
              return (b['name'] as String).compareTo(a['name'] as String);
            case 'status':
              final statusCompare = (b['active'] as int).compareTo(
                a['active'] as int,
              );
              if (statusCompare != 0) return statusCompare;
              return (a['name'] as String).compareTo(b['name'] as String);
            case 'name_asc':
            default:
              return (a['name'] as String).compareTo(b['name'] as String);
          }
        });

        final total = filtered.length;
        final start = (page - 1) * pageSize;
        final end = (start + pageSize).clamp(0, filtered.length);
        final pageItems = start >= filtered.length
            ? <Map<String, Object>>[]
            : filtered.sublist(start, end);

        return {
          'success': true,
          'data': pageItems,
          'meta': {
            'page': page,
            'page_size': pageSize,
            'total': total,
            'total_pages': total == 0 ? 0 : ((total - 1) ~/ pageSize) + 1,
            'has_next_page': end < total,
            'summary': {
              'active_count': filtered
                  .where((teacher) => teacher['active'] == 1)
                  .length,
              'inactive_count': filtered
                  .where((teacher) => teacher['active'] != 1)
                  .length,
            },
          },
        };
      }

      if (url.path.contains('get_all_bookings.php')) {
        final bookings = [
          {
            'id': 1,
            'booking_date': '2026-03-29',
            'purpose': 'Aula pratica',
            'status': 'scheduled',
            'cancelled_at': null,
            'resource_name': 'Laboratorio 01',
            'user_name': 'Ana Souza',
            'class_group_name': '1 Ano A',
            'subject_name': 'Ciencias',
            'lessons': [
              {'id': 1, 'lesson_number': 1, 'label': '1a Aula'},
            ],
          },
          {
            'id': 2,
            'booking_date': '2026-03-30',
            'purpose': 'Apresentacao final',
            'status': 'cancelled',
            'cancelled_at': '2026-03-29 10:00:00',
            'resource_name': 'Projetor movel',
            'user_name': 'Bruno Lima',
            'class_group_name': '2 Ano B',
            'subject_name': 'Historia',
            'lessons': [
              {'id': 2, 'lesson_number': 2, 'label': '2a Aula'},
            ],
          },
        ];

        final search = (url.queryParameters['search'] ?? '').toLowerCase();
        final dateFrom = url.queryParameters['date_from'];
        final dateTo = url.queryParameters['date_to'];
        final status = url.queryParameters['status'];
        final teacher = url.queryParameters['teacher'];
        final resource = url.queryParameters['resource'];
        final classGroup = url.queryParameters['class_group'];
        final sort = url.queryParameters['sort'] ?? 'date_desc';
        final page = int.tryParse(url.queryParameters['page'] ?? '1') ?? 1;
        final pageSize =
            int.tryParse(url.queryParameters['page_size'] ?? '20') ?? 20;

        var filtered = bookings.where((booking) {
          final matchesSearch =
              search.isEmpty ||
              (booking['resource_name'] as String).toLowerCase().contains(
                search,
              ) ||
              (booking['user_name'] as String).toLowerCase().contains(search) ||
              (booking['class_group_name'] as String).toLowerCase().contains(
                search,
              ) ||
              (booking['subject_name'] as String).toLowerCase().contains(
                search,
              ) ||
              (booking['purpose'] as String).toLowerCase().contains(search) ||
              '29/03/2026'.contains(search) ||
              '30/03/2026'.contains(search);
          final matchesStatus = status == null || booking['status'] == status;
          final matchesDateFrom =
              dateFrom == null ||
              (booking['booking_date'] as String).compareTo(dateFrom) >= 0;
          final matchesDateTo =
              dateTo == null ||
              (booking['booking_date'] as String).compareTo(dateTo) <= 0;
          final matchesTeacher =
              teacher == null || booking['user_name'] == teacher;
          final matchesResource =
              resource == null || booking['resource_name'] == resource;
          final matchesClassGroup =
              classGroup == null || booking['class_group_name'] == classGroup;
          return matchesSearch &&
              matchesDateFrom &&
              matchesDateTo &&
              matchesStatus &&
              matchesTeacher &&
              matchesResource &&
              matchesClassGroup;
        }).toList();

        filtered.sort((a, b) {
          switch (sort) {
            case 'date_asc':
              return (a['booking_date'] as String).compareTo(
                b['booking_date'] as String,
              );
            case 'teacher_asc':
              return (a['user_name'] as String).compareTo(
                b['user_name'] as String,
              );
            case 'resource_asc':
              return (a['resource_name'] as String).compareTo(
                b['resource_name'] as String,
              );
            case 'date_desc':
            default:
              return (b['booking_date'] as String).compareTo(
                a['booking_date'] as String,
              );
          }
        });

        final teacherOptions =
            filtered
                .map((booking) => booking['user_name'] as String)
                .toSet()
                .toList()
              ..sort();
        final resourceOptions =
            filtered
                .map((booking) => booking['resource_name'] as String)
                .toSet()
                .toList()
              ..sort();
        final classGroupOptions =
            filtered
                .map((booking) => booking['class_group_name'] as String)
                .toSet()
                .toList()
              ..sort();
        final statusOptions =
            filtered
                .map((booking) => booking['status'] as String)
                .toSet()
                .toList()
              ..sort();

        final total = filtered.length;
        List<Map<String, Object>> buildRanking(String key) {
          final counts = <String, int>{};
          for (final booking in filtered) {
            final label = (booking[key] as String?)?.trim() ?? '';
            if (label.isEmpty) continue;
            counts[label] = (counts[label] ?? 0) + 1;
          }

          final ranking = counts.entries.toList()
            ..sort((a, b) {
              final valueComparison = b.value.compareTo(a.value);
              if (valueComparison != 0) return valueComparison;
              return a.key.compareTo(b.key);
            });

          return ranking
              .take(5)
              .map(
                (entry) => {
                  'label': entry.key,
                  'value': entry.value,
                },
              )
              .toList();
        }

        final totalReservedLessons = filtered.fold<int>(
          0,
          (sum, booking) => sum + ((booking['lessons'] as List).length),
        );
        final start = (page - 1) * pageSize;
        final end = (start + pageSize).clamp(0, filtered.length);
        final pageItems = start >= filtered.length
            ? <Map<String, Object?>>[]
            : filtered.sublist(start, end);

        return {
          'success': true,
          'data': pageItems,
          'meta': {
            'page': page,
            'page_size': pageSize,
            'total': total,
            'total_pages': total == 0 ? 0 : ((total - 1) ~/ pageSize) + 1,
            'has_next_page': end < total,
            'summary': {
              'overall_count': bookings.length,
              'scheduled_count': filtered
                  .where((booking) => booking['status'] == 'scheduled')
                  .length,
              'cancelled_count': filtered
                  .where((booking) => booking['status'] != 'scheduled')
                  .length,
              'unique_teachers_count': filtered
                  .map((booking) => booking['user_name'] as String)
                  .toSet()
                  .length,
              'unique_resources_count': filtered
                  .map((booking) => booking['resource_name'] as String)
                  .toSet()
                  .length,
              'unique_class_groups_count': filtered
                  .map((booking) => booking['class_group_name'] as String)
                  .toSet()
                  .length,
              'unique_subjects_count': filtered
                  .map((booking) => booking['subject_name'] as String)
                  .toSet()
                  .length,
              'total_reserved_lessons': totalReservedLessons,
              'average_lessons_per_booking': total == 0
                  ? 0
                  : totalReservedLessons / total,
              'busiest_weekday_label': 'Segunda-feira',
              'teacher_options': teacherOptions,
              'resource_options': resourceOptions,
              'class_group_options': classGroupOptions,
              'status_options': statusOptions,
              'teacher_ranking': buildRanking('user_name'),
              'resource_ranking': buildRanking('resource_name'),
              'class_group_ranking': buildRanking('class_group_name'),
              'subject_ranking': buildRanking('subject_name'),
            },
          },
        };
      }

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
