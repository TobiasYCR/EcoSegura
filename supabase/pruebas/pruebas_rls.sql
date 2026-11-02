-- =====================================================================
-- EcoSegura - Pruebas de permisos (RLS) y reglas de negocio
-- Se ejecuta dentro de una transacción que se deshace al final:
-- no deja usuarios ni datos. Requiere schema.sql y seed.sql cargados.
-- Cada prueba se ejecuta con el rol "authenticated" y el usuario indicado,
-- igual que las consultas que hace la aplicación con la clave publicable.
-- =====================================================================
begin;

create schema pruebas;
create table pruebas.resultados (n serial, usuario text, prueba text, ok boolean, detalle text);
create table pruebas.usuarios (nombre text primary key, id uuid);
grant usage on schema pruebas to authenticated, anon;
grant select, insert on all tables in schema pruebas to authenticated, anon;
grant usage on all sequences in schema pruebas to authenticated, anon;

-- Cambia el usuario actual (equivale al token de sesión de Supabase)
create function pruebas.como(p_nombre text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', (select id from pruebas.usuarios where nombre = p_nombre),
                      'role', 'authenticated')::text, true);
end $$;

-- Ejecuta una sentencia y compara con lo esperado:
--   'ok'        no debe fallar
--   'error'     debe ser rechazada
--   'filas:N'   debe modificar/devolver exactamente N filas
--   'verdadero' la consulta debe devolver true
create function pruebas.probar(p_prueba text, p_sql text, p_esperado text)
returns void language plpgsql as $$
declare
  v_filas int;
  v_bool boolean;
  v_ok boolean;
  v_detalle text := '';
  v_usuario text := (select nombre from pruebas.usuarios
                     where id::text = nullif(current_setting('request.jwt.claims', true), '')::json ->> 'sub');
begin
  begin
    if p_esperado = 'verdadero' then
      execute p_sql into v_bool;
      v_ok := coalesce(v_bool, false);
    elsif p_esperado like 'filas:%' then
      if p_sql ~* '^\s*select' then
        execute 'select count(*) from (' || p_sql || ') x' into v_filas;
      else
        execute p_sql;
        get diagnostics v_filas = row_count;
      end if;
      v_ok := v_filas = split_part(p_esperado, ':', 2)::int;
      v_detalle := 'filas: ' || v_filas;
    else
      execute p_sql;
      v_ok := p_esperado = 'ok';
      v_detalle := 'sin error';
    end if;
  exception when others then
    v_ok := p_esperado = 'error';
    v_detalle := sqlerrm;
  end;
  insert into pruebas.resultados (usuario, prueba, ok, detalle)
  values (coalesce(v_usuario, 'anónimo'), p_prueba, v_ok, v_detalle);
end $$;
grant execute on all functions in schema pruebas to authenticated, anon;

-- ---------------------------------------------------------------------
-- Preparación (como administrador de la base)
-- ---------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000001', 'relevador1@prueba.local', '{"nombre":"Rele","apellido":"Uno"}'),
  ('00000000-0000-0000-0000-000000000002', 'relevador2@prueba.local', '{"nombre":"Rele","apellido":"Dos"}'),
  ('00000000-0000-0000-0000-000000000003', 'ambiental@prueba.local',  '{"nombre":"Ambi","apellido":"Ental"}'),
  ('00000000-0000-0000-0000-000000000004', 'admin@prueba.local',      '{"nombre":"Admi","apellido":"Nistra"}'),
  ('00000000-0000-0000-0000-000000000005', 'tecno@prueba.local',      '{"nombre":"Tecno","apellido":"Logía"}'),
  ('00000000-0000-0000-0000-000000000006', 'docente@prueba.local',    '{"nombre":"Doce","apellido":"Nte"}'),
  ('00000000-0000-0000-0000-000000000007', 'nuevo@prueba.local',      '{"nombre":"Sin","apellido":"Perfil"}'),
  ('00000000-0000-0000-0000-000000000008', 'inactivo@prueba.local',   '{"nombre":"Ina","apellido":"Ctivo"}');

insert into pruebas.usuarios values
  ('relevador1', '00000000-0000-0000-0000-000000000001'),
  ('relevador2', '00000000-0000-0000-0000-000000000002'),
  ('ambiental',  '00000000-0000-0000-0000-000000000003'),
  ('admin',      '00000000-0000-0000-0000-000000000004'),
  ('tecno',      '00000000-0000-0000-0000-000000000005'),
  ('docente',    '00000000-0000-0000-0000-000000000006'),
  ('sinperfil',  '00000000-0000-0000-0000-000000000007'),
  ('inactivo',   '00000000-0000-0000-0000-000000000008');

update public.perfiles p set perfil = v.perfil, activo = v.activo
from (values
  ('00000000-0000-0000-0000-000000000001'::uuid, 'relevador', true),
  ('00000000-0000-0000-0000-000000000002'::uuid, 'relevador', true),
  ('00000000-0000-0000-0000-000000000003'::uuid, 'ambiental', true),
  ('00000000-0000-0000-0000-000000000004'::uuid, 'administracion', true),
  ('00000000-0000-0000-0000-000000000005'::uuid, 'tecnologia', true),
  ('00000000-0000-0000-0000-000000000006'::uuid, 'docente', true),
  ('00000000-0000-0000-0000-000000000008'::uuid, 'relevador', false)
) v(id, perfil, activo) where p.id = v.id;

-- Registros con id conocido
insert into public.registros_residuos (id, fecha, hora, lugar_id, tipo, descripcion, cantidad_bolsas, estado, creado_por)
select v.id, public.hoy() - 1, '12:00', (select min(id) from public.lugares), 'externo', v.descr, 2, v.estado, v.autor
from (values
  ('10000000-0000-0000-0000-000000000001'::uuid, 'Registro pendiente de relevador1', 'pendiente', '00000000-0000-0000-0000-000000000001'::uuid),
  ('10000000-0000-0000-0000-000000000002'::uuid, 'Registro revisado de relevador1', 'revisado', '00000000-0000-0000-0000-000000000001'::uuid),
  ('10000000-0000-0000-0000-000000000003'::uuid, 'Registro pendiente de relevador2', 'pendiente', '00000000-0000-0000-0000-000000000002'::uuid)
) v(id, descr, estado, autor);

insert into public.informes (id, titulo, periodo_desde, periodo_hasta, estado, fecha_envio) values
  ('20000000-0000-0000-0000-000000000001', 'Informe de prueba en revisión', public.hoy() - 10, public.hoy() - 1, 'en_revision', null),
  ('20000000-0000-0000-0000-000000000002', 'Informe de prueba enviado', public.hoy() - 20, public.hoy() - 11, 'enviado', public.hoy() - 5);

insert into public.movimientos (id, fecha, concepto, tipo, monto) values
  ('30000000-0000-0000-0000-000000000001', public.hoy() - 1, 'Movimiento de prueba', 'gasto', 100);

insert into public.reciclables (id, fecha, material, kilos) values
  ('40000000-0000-0000-0000-000000000001', public.hoy() - 1, 'papel', 3);

-- ---------------------------------------------------------------------
-- Pruebas con el rol de la aplicación
-- ---------------------------------------------------------------------
set local role authenticated;

-- Relevador
select pruebas.como('relevador1');
select pruebas.probar('Ve los registros de residuos', $$select count(*) > 0 from public.registros_residuos$$, 'verdadero');
select pruebas.probar('Crea un registro', $$insert into public.registros_residuos (id, lugar_id, tipo, descripcion, cantidad_bolsas, fecha, hora)
  values ('10000000-0000-0000-0000-000000000009', (select min(id) from public.lugares), 'externo', 'Bolsas en la vereda', 3, public.hoy(), '10:00')$$, 'ok');
select pruebas.probar('El autor del registro lo pone la base', $$select creado_por = auth.uid() from public.registros_residuos where id = '10000000-0000-0000-0000-000000000009'$$, 'verdadero');
select pruebas.probar('3 bolsas se marca como crítica', $$select critica from public.registros_residuos where id = '10000000-0000-0000-0000-000000000009'$$, 'verdadero');
select pruebas.probar('Intenta crear un registro revisado y marcado de prueba', $$insert into public.registros_residuos (id, lugar_id, tipo, descripcion, estado, datos_prueba)
  values ('10000000-0000-0000-0000-000000000010', (select min(id) from public.lugares), 'interno', 'Intento de saltear reglas', 'revisado', true)$$, 'ok');
select pruebas.probar('...la base lo guarda pendiente y sin marca de prueba', $$select estado = 'pendiente' and not datos_prueba from public.registros_residuos where id = '10000000-0000-0000-0000-000000000010'$$, 'verdadero');
select pruebas.probar('No puede cargar fecha futura', $$insert into public.registros_residuos (lugar_id, tipo, descripcion, fecha) values ((select min(id) from public.lugares), 'externo', 'Fecha futura', public.hoy() + 1)$$, 'error');
select pruebas.probar('No acepta más de 50 bolsas', $$insert into public.registros_residuos (lugar_id, tipo, descripcion, cantidad_bolsas) values ((select min(id) from public.lugares), 'externo', 'Demasiadas bolsas', 51)$$, 'error');
select pruebas.probar('Corrige su registro pendiente', $$update public.registros_residuos set descripcion = 'Corregido por relevador1' where id = '10000000-0000-0000-0000-000000000001'$$, 'filas:1');
select pruebas.probar('No corrige registros de otro relevador', $$update public.registros_residuos set descripcion = 'Intento' where id = '10000000-0000-0000-0000-000000000003'$$, 'filas:0');
select pruebas.probar('No corrige su registro ya revisado', $$update public.registros_residuos set descripcion = 'Intento' where id = '10000000-0000-0000-0000-000000000002'$$, 'error');
select pruebas.probar('No cambia el estado de su registro', $$update public.registros_residuos set estado = 'revisado' where id = '10000000-0000-0000-0000-000000000001'$$, 'error');
select pruebas.probar('No borra registros', $$delete from public.registros_residuos where id = '10000000-0000-0000-0000-000000000001'$$, 'error');
select pruebas.probar('Sube fotos en su carpeta', $$insert into storage.objects (bucket_id, name) values ('fotos', '00000000-0000-0000-0000-000000000001/foto.jpg')$$, 'ok');
select pruebas.probar('No sube fotos en la carpeta de otro', $$insert into storage.objects (bucket_id, name) values ('fotos', '00000000-0000-0000-0000-000000000002/foto.jpg')$$, 'error');
select pruebas.probar('No ve informes', $$select * from public.informes$$, 'filas:0');
select pruebas.probar('No carga reciclables', $$insert into public.reciclables (material, kilos) values ('papel', 1)$$, 'error');
select pruebas.probar('Ve actas y movimientos (artículo 3)', $$select (select count(*) from public.actas) > 0 and (select count(*) from public.movimientos) > 0$$, 'verdadero');
select pruebas.probar('No carga actas', $$insert into public.actas (fecha, participantes, temas, decisiones) values (public.hoy(), 'abc', 'abc', 'abc')$$, 'error');
select pruebas.probar('Solo ve su propio perfil', $$select * from public.perfiles$$, 'filas:1');
select pruebas.probar('No se asigna otro perfil', $$select public.asignar_perfil(auth.uid(), 'tecnologia', '', '', true)$$, 'error');
select pruebas.probar('No modifica su perfil directamente', $$update public.perfiles set perfil = 'tecnologia' where id = auth.uid()$$, 'error');

-- Cuenta creada pero sin perfil asignado
select pruebas.como('sinperfil');
select pruebas.probar('Cuenta sin perfil no ve registros', $$select * from public.registros_residuos$$, 'filas:0');
select pruebas.probar('Cuenta sin perfil no ve actas', $$select * from public.actas$$, 'filas:0');
select pruebas.probar('Cuenta sin perfil ve su propio perfil', $$select * from public.perfiles$$, 'filas:1');

-- Comisión Ambiental
select pruebas.como('ambiental');
select pruebas.probar('Marca un registro como revisado', $$update public.registros_residuos set estado = 'revisado', tipo = 'interno' where id = '10000000-0000-0000-0000-000000000003'$$, 'filas:1');
select pruebas.probar('...y queda como revisor', $$select revisado_por = auth.uid() from public.registros_residuos where id = '10000000-0000-0000-0000-000000000003'$$, 'verdadero');
select pruebas.probar('No cambia la descripción de un registro', $$update public.registros_residuos set descripcion = 'Otra cosa' where id = '10000000-0000-0000-0000-000000000001'$$, 'error');
select pruebas.probar('No anula registros', $$update public.registros_residuos set estado = 'anulado', motivo_anulacion = 'Prueba' where id = '10000000-0000-0000-0000-000000000001'$$, 'error');
select pruebas.probar('No crea registros de residuos', $$insert into public.registros_residuos (lugar_id, tipo, descripcion) values ((select min(id) from public.lugares), 'externo', 'Intento ambiental')$$, 'error');
select pruebas.probar('Carga reciclables', $$insert into public.reciclables (material, kilos) values ('plastico', 2.5)$$, 'ok');
select pruebas.probar('No acepta kilos negativos', $$insert into public.reciclables (material, kilos) values ('plastico', -1)$$, 'error');
select pruebas.probar('No acepta materiales fuera de la lista', $$insert into public.reciclables (material, kilos) values ('carton', 1)$$, 'error');
select pruebas.probar('Corrige un reciclable', $$update public.reciclables set kilos = 3.5 where id = '40000000-0000-0000-0000-000000000001'$$, 'filas:1');
select pruebas.probar('No anula reciclables', $$update public.reciclables set anulado = true, motivo_anulacion = 'Prueba' where id = '40000000-0000-0000-0000-000000000001'$$, 'error');
select pruebas.probar('Ve informes', $$select count(*) > 0 from public.informes$$, 'verdadero');
select pruebas.probar('No crea informes', $$insert into public.informes (titulo, periodo_desde, periodo_hasta) values ('Informe ambiental', public.hoy() - 5, public.hoy() - 1)$$, 'error');
select pruebas.probar('No ve la lista de usuarios', $$select * from public.perfiles$$, 'filas:1');

-- Administración y Consejo
select pruebas.como('admin');
select pruebas.probar('Crea un informe', $$insert into public.informes (id, titulo, periodo_desde, periodo_hasta, estado) values ('20000000-0000-0000-0000-000000000009', 'Informe nuevo de prueba', public.hoy() - 5, public.hoy() - 1, 'enviado')$$, 'ok');
select pruebas.probar('...el informe nuevo arranca en borrador', $$select estado = 'borrador' from public.informes where id = '20000000-0000-0000-0000-000000000009'$$, 'verdadero');
select pruebas.probar('No crea informes con período futuro', $$insert into public.informes (titulo, periodo_desde, periodo_hasta) values ('Informe a futuro', public.hoy(), public.hoy() + 3)$$, 'error');
select pruebas.probar('Pide la revisión del docente', $$update public.informes set estado = 'en_revision' where id = '20000000-0000-0000-0000-000000000009'$$, 'filas:1');
select pruebas.probar('No aprueba informes', $$update public.informes set estado = 'aprobado' where id = '20000000-0000-0000-0000-000000000001'$$, 'error');
select pruebas.probar('No escribe observaciones del docente', $$update public.informes set observaciones_docente = 'Todo bien' where id = '20000000-0000-0000-0000-000000000001'$$, 'error');
select pruebas.probar('No edita un informe en revisión', $$update public.informes set titulo = 'Cambio de título' where id = '20000000-0000-0000-0000-000000000001'$$, 'error');
select pruebas.probar('Registra la respuesta del municipio', $$update public.informes set respuesta_municipio = 'no' where id = '20000000-0000-0000-0000-000000000002'$$, 'filas:1');
select pruebas.probar('No borra un informe enviado', $$delete from public.informes where id = '20000000-0000-0000-0000-000000000002'$$, 'filas:0');
select pruebas.probar('Carga un acta', $$insert into public.actas (fecha, participantes, temas, decisiones) values (public.hoy(), 'Consejo', 'Tema de prueba', 'Decisión de prueba')$$, 'ok');
select pruebas.probar('Carga un movimiento', $$insert into public.movimientos (fecha, concepto, tipo, monto) values (public.hoy(), 'Compra de prueba', 'gasto', 500)$$, 'ok');
select pruebas.probar('No anula un movimiento sin motivo', $$update public.movimientos set anulado = true where id = '30000000-0000-0000-0000-000000000001'$$, 'error');
select pruebas.probar('Anula un movimiento con motivo', $$update public.movimientos set anulado = true, motivo_anulacion = 'Cargado dos veces' where id = '30000000-0000-0000-0000-000000000001'$$, 'filas:1');
select pruebas.probar('No modifica un movimiento anulado', $$update public.movimientos set monto = 1 where id = '30000000-0000-0000-0000-000000000001'$$, 'error');
select pruebas.probar('No borra movimientos', $$delete from public.movimientos$$, 'error');
select pruebas.probar('No crea registros de residuos', $$insert into public.registros_residuos (lugar_id, tipo, descripcion) values ((select min(id) from public.lugares), 'externo', 'Intento admin')$$, 'error');
select pruebas.probar('Ve la lista de usuarios', $$select count(*) > 1 from public.perfiles$$, 'verdadero');
select pruebas.probar('No asigna perfiles', $$select public.asignar_perfil('00000000-0000-0000-0000-000000000007', 'relevador', '', '', true)$$, 'error');

-- Docente asesor
select pruebas.como('docente');
select pruebas.probar('No devuelve un informe sin observación', $$update public.informes set estado = 'borrador' where id = '20000000-0000-0000-0000-000000000001'$$, 'error');
select pruebas.probar('No cambia el título de un informe', $$update public.informes set titulo = 'Título del docente' where id = '20000000-0000-0000-0000-000000000001'$$, 'error');
select pruebas.probar('Aprueba un informe con observaciones', $$update public.informes set estado = 'aprobado', observaciones_docente = 'Correcto' where id = '20000000-0000-0000-0000-000000000001'$$, 'filas:1');
select pruebas.probar('No marca un informe como enviado', $$update public.informes set estado = 'enviado', fecha_envio = public.hoy() where id = '20000000-0000-0000-0000-000000000001'$$, 'error');
select pruebas.probar('Devuelve un informe con observación', $$update public.informes set estado = 'borrador', observaciones_docente = 'Falta la introducción' where id = '20000000-0000-0000-0000-000000000009'$$, 'filas:1');
select pruebas.probar('No carga actas', $$insert into public.actas (fecha, participantes, temas, decisiones) values (public.hoy(), 'abc', 'abc', 'abc')$$, 'error');
select pruebas.probar('No modifica registros de residuos', $$update public.registros_residuos set tipo = 'interno' where id = '10000000-0000-0000-0000-000000000001'$$, 'filas:0');

-- Administración envía el informe aprobado
select pruebas.como('admin');
select pruebas.probar('Marca como enviado un informe aprobado', $$update public.informes set estado = 'enviado' where id = '20000000-0000-0000-0000-000000000001'$$, 'filas:1');
select pruebas.probar('...la fecha de envío la completa la base', $$select fecha_envio = public.hoy() from public.informes where id = '20000000-0000-0000-0000-000000000001'$$, 'verdadero');
select pruebas.probar('Borra un informe en borrador', $$delete from public.informes where id = '20000000-0000-0000-0000-000000000009'$$, 'filas:1');

-- Comisión de Tecnología
select pruebas.como('tecno');
select pruebas.probar('No anula sin motivo', $$update public.registros_residuos set estado = 'anulado' where id = '10000000-0000-0000-0000-000000000001'$$, 'error');
select pruebas.probar('No cambia datos de un registro', $$update public.registros_residuos set descripcion = 'Cambio técnico' where id = '10000000-0000-0000-0000-000000000001'$$, 'error');
select pruebas.probar('Anula un registro duplicado con motivo', $$update public.registros_residuos set estado = 'anulado', motivo_anulacion = 'Duplicado' where id = '10000000-0000-0000-0000-000000000001'$$, 'filas:1');
select pruebas.probar('Anula un reciclable con motivo', $$update public.reciclables set anulado = true, motivo_anulacion = 'Duplicado' where id = '40000000-0000-0000-0000-000000000001'$$, 'filas:1');
select pruebas.probar('Asigna perfil a una cuenta nueva', $$select public.asignar_perfil('00000000-0000-0000-0000-000000000007', 'relevador', 'relevamiento', '5° 2°', true)$$, 'ok');
select pruebas.probar('No se quita su propio perfil', $$select public.asignar_perfil(auth.uid(), 'relevador', '', '', true)$$, 'error');
select pruebas.probar('Agrega un lugar', $$insert into public.lugares (nombre) values ('Lugar de prueba')$$, 'ok');
select pruebas.probar('No repite lugares', $$insert into public.lugares (nombre) values ('Lugar de prueba')$$, 'error');
select pruebas.probar('No crea informes', $$insert into public.informes (titulo, periodo_desde, periodo_hasta) values ('Informe tecno', public.hoy() - 5, public.hoy() - 1)$$, 'error');

-- Un registro anulado queda cerrado para todos
select pruebas.como('ambiental');
select pruebas.probar('No modifica un registro anulado', $$update public.registros_residuos set estado = 'revisado' where id = '10000000-0000-0000-0000-000000000001'$$, 'error');

-- Cuenta desactivada: no ve nada
select pruebas.como('inactivo');
select pruebas.probar('Usuario inactivo no ve registros', $$select * from public.registros_residuos$$, 'filas:0');
select pruebas.probar('Usuario inactivo no ve lugares', $$select * from public.lugares$$, 'filas:0');
select pruebas.probar('Usuario inactivo no carga registros', $$insert into public.registros_residuos (lugar_id, tipo, descripcion) values (1, 'externo', 'Intento inactivo')$$, 'error');
select pruebas.probar('Usuario inactivo no obtiene nombres', $$select * from public.nombres_integrantes()$$, 'filas:0');

-- Visitante sin sesión (clave publicable sin iniciar sesión)
reset role;
set local role anon;
select set_config('request.jwt.claims', '', true);
select pruebas.probar('Sin sesión no ve registros', $$select * from public.registros_residuos$$, 'error');
select pruebas.probar('Sin sesión no ve actas', $$select * from public.actas$$, 'error');

reset role;

-- ---------------------------------------------------------------------
-- Resultado
-- ---------------------------------------------------------------------
select n, usuario, prueba, case when ok then 'OK' else 'FALLA' end as resultado, detalle
from pruebas.resultados order by n;

select count(*) filter (where ok) as correctas, count(*) as total
from pruebas.resultados;

rollback;
