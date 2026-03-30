-- Rode estas consultas no MySQL antes da migracao e no Supabase depois da importacao.

-- Contagem por tabela da base atual:
-- schools             3
-- users               7
-- resources           34
-- bookings            11
-- booking_lessons     25
-- class_groups        29
-- subjects            18
-- lesson_slots        23
-- resource_categories 3

select 'schools' as table_name, count(*) as total from public.schools
union all
select 'users', count(*) from public.users
union all
select 'resources', count(*) from public.resources
union all
select 'bookings', count(*) from public.bookings
union all
select 'booking_lessons', count(*) from public.booking_lessons
union all
select 'class_groups', count(*) from public.class_groups
union all
select 'subjects', count(*) from public.subjects
union all
select 'lesson_slots', count(*) from public.lesson_slots
union all
select 'resource_categories', count(*) from public.resource_categories;

-- Verifica orfaos relevantes.
select count(*) as orphan_completed_by
from public.bookings b
left join public.users u on u.id = b.completed_by_user_id
where b.completed_by_user_id is not null
  and u.id is null;

select count(*) as orphan_cancelled_by
from public.bookings b
left join public.users u on u.id = b.cancelled_by_user_id
where b.cancelled_by_user_id is not null
  and u.id is null;

-- Confirma seeds de categorias.
select id, name
from public.resource_categories
order by id;

-- Confirma que as sequences continuam alinhadas depois de importar dados com IDs manuais.
select
    'schools' as table_name,
    (select max(id) from public.schools) as max_id,
    nextval(pg_get_serial_sequence('public.schools', 'id')) as next_id;
