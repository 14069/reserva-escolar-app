import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_escolar_app/models/admin_list_metrics.dart';
import 'package:reserva_escolar_app/models/api_result.dart';
import 'package:reserva_escolar_app/models/api_summary_models.dart';
import 'package:reserva_escolar_app/models/resource_model.dart';

void main() {
  test('Tipa meta paginado e summary ativos/inativos', () {
    final response = ApiListResponse<ResourceModel, ActiveInactiveSummary>.fromJson(
      {
        'success': true,
        'data': [
          {
            'id': 1,
            'name': 'Laboratorio 01',
            'active': 1,
            'category_id': 2,
            'category_name': 'Espaço',
          },
        ],
        'meta': {
          'page': 2,
          'page_size': 20,
          'total': 31,
          'total_pages': 2,
          'has_next_page': false,
          'summary': {
            'active_count': 24,
            'inactive_count': 7,
          },
        },
      },
      itemParser: ResourceModel.fromJson,
      summaryParser: ActiveInactiveSummary.fromJson,
    );

    expect(response.success, isTrue);
    expect(response.meta.page, 2);
    expect(response.meta.pageSize, 20);
    expect(response.meta.total, 31);
    expect(response.meta.totalPages, 2);
    expect(response.meta.hasNextPage, isFalse);
    expect(response.summary?.activeCount, 24);
    expect(response.summary?.inactiveCount, 7);
    expect(response.items.single.name, 'Laboratorio 01');
  });

  test('Resolve totais ativos/inativos com fallback local quando summary nao vem', () {
    const meta = ApiListMeta<ActiveInactiveSummary>(
      page: 1,
      pageSize: 20,
      total: 0,
      totalPages: 0,
      hasNextPage: false,
    );

    final totals = ActiveInactiveTotals.resolve<ResourceModel>(
      meta: meta,
      items: [
        ResourceModel(
          id: 1,
          name: 'Laboratorio 01',
          active: 1,
          categoryId: 2,
          categoryName: 'Espaço',
        ),
        ResourceModel(
          id: 2,
          name: 'Projetor movel',
          active: 0,
          categoryId: 1,
          categoryName: 'Audiovisual',
        ),
      ],
      isActive: (resource) => resource.active == 1,
    );

    expect(totals.totalCount, 2);
    expect(totals.activeCount, 1);
    expect(totals.inactiveCount, 1);
  });

  test('Normaliza listas e rankings do resumo administrativo de reservas', () {
    final summary = BookingSummaryModel.fromJson({
      'overall_count': 8,
      'scheduled_count': 3,
      'completed_count': 2,
      'completed_today_count': 1,
      'cancelled_count': 3,
      'unique_teachers_count': 4,
      'unique_resources_count': 3,
      'unique_class_groups_count': 2,
      'unique_subjects_count': 5,
      'total_reserved_lessons': 12,
      'average_lessons_per_booking': '1.5',
      'busiest_weekday_label': '',
      'teacher_options': ['Bruno Lima', 'Ana Souza', 'Bruno Lima', ''],
      'resource_options': ['Projetor movel', 'Laboratorio 01'],
      'class_group_options': ['2 Ano B', '1 Ano A', '1 Ano A'],
      'status_options': ['cancelled', 'scheduled', 'scheduled'],
      'teacher_ranking': [
        {'label': 'Ana Souza', 'value': 3},
        {'label': 'Bruno Lima', 'value': 2},
      ],
      'resource_ranking': [
        {'label': 'Laboratorio 01', 'value': 4},
      ],
      'class_group_ranking': [
        {'label': '1 Ano A', 'value': 5},
      ],
      'subject_ranking': [
        {'label': 'Ciencias', 'value': 6},
      ],
    });

    expect(summary.averageLessonsPerBooking, 1.5);
    expect(summary.busiestWeekdayLabel, 'Sem dados');
    expect(summary.teacherOptions, ['Ana Souza', 'Bruno Lima']);
    expect(summary.classGroupOptions, ['1 Ano A', '2 Ano B']);
    expect(summary.statusOptions, ['cancelled', 'scheduled']);
    expect(summary.teacherRanking.first.label, 'Ana Souza');
    expect(summary.subjectRanking.single.value, 6);
  });
}
