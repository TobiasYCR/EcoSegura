-- =====================================================================
-- EcoSegura - Datos ficticios para pruebas (datos_prueba = true)
-- Ejecutar después de schema.sql. Las fechas se calculan desde hoy,
-- así los datos siempre caen en los últimos 30 días.
-- =====================================================================

-- Lugares de relevamiento
insert into public.lugares (nombre) values
  ('Puerta principal'),
  ('Patio trasero'),
  ('Esquina norte'),
  ('Esquina sur'),
  ('Vereda del gimnasio'),
  ('Parada de colectivo')
on conflict (nombre) do nothing;

-- Registros de residuos: 30 días de relevamiento en franjas fijas
-- (entrada 8 h, recreos 10 h y 12 h, salida 14 h y 16 h).
-- Valores pseudoaleatorios reproducibles: el mismo script da los mismos datos.
with dias as (
  select d::date as fecha
  from generate_series(public.hoy() - 29, public.hoy() - 1, interval '1 day') d
  where extract(isodow from d) between 1 and 5
),
franjas as (
  select unnest(array['08:05', '10:15', '12:20', '14:10', '16:05'])::time as hora
),
base as (
  select f.fecha, fr.hora,
         abs(hashtext(f.fecha::text || fr.hora::text)) as h
  from dias f cross join franjas fr
),
elegidos as (
  -- no en todas las franjas hay acumulación
  select *, (h % 6) + 1 as lugar_n
  from base
  where h % 100 < 38
     or (hora = '12:20' and h % 100 < 65)
     or (extract(isodow from fecha) = 1 and hora = '12:20')
)
insert into public.registros_residuos
  (fecha, hora, lugar_id, tipo, descripcion, cantidad_bolsas, clima, estado,
   datos_prueba, creado_en)
select e.fecha,
       e.hora + make_interval(mins => (e.h % 9)::int),
       l.id,
       case when l.nombre in ('Patio trasero', 'Vereda del gimnasio') and (e.h / 7) % 3 <> 0
            then 'interno' else 'externo' end,
       (array['Bolsas rotas en el piso',
              'Bolsas apiladas junto al cesto',
              'Restos de comida y envases',
              'Escombros y bolsas de consorcio',
              'Botellas y latas sueltas',
              'Bolsas abiertas con mal olor'])[(e.h % 6) + 1],
       case
         -- El informe enviado a mitad del piloto consiguió un retiro extra los lunes
         -- al mediodía. Desde la respuesta quedan casos, pero dejan de ser críticos.
         when extract(isodow from e.fecha) = 1 and e.hora = '12:20'
              and e.fecha < public.hoy() - 14 then 3 + (e.h % 3)::int
         when extract(isodow from e.fecha) = 1 and e.hora = '12:20' then 1 + (e.h % 2)::int
         when l.nombre = 'Esquina norte' then 2 + (e.h % 3)::int
         else (e.h % 4)::int
       end,
       (array['soleado', 'soleado', 'nublado', 'lluvia'])[(e.h % 4) + 1],
       case when e.fecha < public.hoy() - 7 then 'revisado' else 'pendiente' end,
       true,
       (e.fecha + e.hora)::timestamptz
from elegidos e
join public.lugares l
  on l.nombre = case when extract(isodow from e.fecha) = 1 and e.hora = '12:20'
                     then 'Esquina norte'
                     else (array['Puerta principal', 'Patio trasero', 'Esquina norte',
                                 'Esquina sur', 'Vereda del gimnasio',
                                 'Parada de colectivo'])[e.lugar_n] end;

-- Un duplicado anulado, para ver el historial
insert into public.registros_residuos
  (fecha, hora, lugar_id, tipo, descripcion, cantidad_bolsas, clima, estado,
   motivo_anulacion, datos_prueba)
select public.hoy() - 3, '10:20', id, 'externo', 'Bolsas apiladas junto al cesto', 2,
       'nublado', 'anulado', 'Duplicado: el mismo caso se cargó dos veces.', true
from public.lugares where nombre = 'Puerta principal';

-- Reciclables del punto verde: un pesaje por material dos veces por semana
insert into public.reciclables (fecha, material, kilos, datos_prueba)
select d::date, m.material,
       round((m.base + (abs(hashtext(d::text || m.material)) % 40) / 10.0
              + (29 - (public.hoy() - d::date)) * m.mejora)::numeric, 2),
       true
from generate_series(public.hoy() - 29, public.hoy() - 1, interval '1 day') d
cross join (values ('plastico', 3.0, 0.08), ('papel', 4.5, 0.05),
                   ('vidrio', 2.0, 0.03), ('metal', 0.8, 0.01)) as m(material, base, mejora)
where extract(isodow from d) in (2, 4);

-- Informes al municipio en distintos estados
insert into public.informes
  (titulo, periodo_desde, periodo_hasta, introduccion, incluye_fotos, estado,
   observaciones_docente, fecha_envio, respuesta_municipio, respuesta_detalle, datos_prueba)
values
  ('Acumulaciones en la Esquina norte - primera quincena',
   public.hoy() - 29, public.hoy() - 16,
   'La Cooperativa Escolar EcoSegura informa las acumulaciones de residuos registradas en los alrededores de la escuela durante el período indicado.',
   true, 'enviado', 'Datos revisados. Se puede enviar.',
   public.hoy() - 14, 'si', 'La oficina de limpieza agregó un retiro los lunes al mediodía.', true),
  ('Seguimiento de la segunda quincena',
   public.hoy() - 15, public.hoy() - 2,
   'Segundo informe con los datos de la segunda quincena de relevamiento.',
   true, 'en_revision', null, null, 'sin_respuesta', null, true),
  ('Informe mensual de reciclaje',
   public.hoy() - 29, public.hoy() - 1,
   'Kilos recuperados en el punto verde por material.',
   false, 'borrador', null, null, 'sin_respuesta', null, true);

-- Actas de reuniones
insert into public.actas (fecha, participantes, temas, decisiones, responsables, datos_prueba) values
  (public.hoy() - 28,
   'Presidencia, Secretaría, Tesorería, Comisión de Tecnología, Comisión Ambiental, docente asesor',
   'Inicio del relevamiento de 30 días. Puntos y franjas a recorrer.',
   'Se relevan 6 puntos en 5 franjas fijas. Se considera crítica una acumulación de 3 o más bolsas.',
   'Comisión de Relevamiento: recorridos. Comisión de Tecnología: alta de usuarios.', true),
  (public.hoy() - 14,
   'Consejo de Administración, Comisión de Comunicación, docente asesor',
   'Primer informe al municipio. Campaña de separación en recreos.',
   'Se envía el primer informe. Se arma una campaña de afiches para el punto verde.',
   'Secretaría: envío del informe. Comunicación: afiches.', true),
  (public.hoy() - 3,
   'Consejo de Administración, Comisión Ambiental',
   'Respuesta del municipio. Compra de bolsas para el punto verde.',
   'Se registra la respuesta. Se aprueba la compra de bolsas.',
   'Tesorería: compra. Comisión Ambiental: reposición.', true);

-- Recursos y gastos
insert into public.movimientos (fecha, concepto, tipo, monto, anulado, motivo_anulacion, datos_prueba) values
  (public.hoy() - 27, 'Aporte inicial de los socios', 'ingreso', 30000, false, null, true),
  (public.hoy() - 25, 'Guantes y bolsas para el relevamiento', 'gasto', 8500, false, null, true),
  (public.hoy() - 20, 'Venta de material reciclable', 'ingreso', 12400, false, null, true),
  (public.hoy() - 12, 'Impresión de afiches', 'gasto', 6200, false, null, true),
  (public.hoy() - 12, 'Impresión de afiches', 'gasto', 6200, true, 'Cargado dos veces.', true),
  (public.hoy() - 2, 'Bolsas para el punto verde', 'gasto', 4800, false, null, true);

-- ---------------------------------------------------------------------
-- Primer usuario de Tecnología
-- 1) Crear la cuenta en el panel de Supabase: Authentication > Users >
--    Add user (con "Auto Confirm User" marcado).
-- 2) Ejecutar (reemplazando el email):
--
-- update public.perfiles
--    set perfil = 'tecnologia', comision = 'tecnologia', activo = true
--  where email = 'tecnologia@ejemplo.com';
--
-- Desde ahí, Tecnología crea los demás usuarios en la pantalla Usuarios.
-- ---------------------------------------------------------------------
