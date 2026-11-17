-- =====================================================================
-- EcoSegura - Estructura de la base de datos (Supabase / PostgreSQL)
-- Ejecutar en el SQL Editor de Supabase sobre un proyecto vacío.
-- Para reconstruir: ejecutar reset.sql y luego este archivo.
-- =====================================================================

create extension if not exists pgcrypto;

-- Fecha de hoy en Argentina (el servidor de Supabase trabaja en UTC)
create or replace function public.hoy()
returns date
language sql stable
as $$ select (now() at time zone 'America/Argentina/Buenos_Aires')::date $$;

-- ---------------------------------------------------------------------
-- 1. Tablas
-- ---------------------------------------------------------------------

-- Usuarios del sistema. La cuenta y la contraseña (cifrada) las guarda
-- Supabase Auth en auth.users; acá se guardan los datos de la cooperativa.
create table public.perfiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text not null unique,
  nombre      text not null default '' check (char_length(nombre) <= 60),
  apellido    text not null default '' check (char_length(apellido) <= 60),
  curso       text check (curso is null or char_length(curso) <= 20),
  comision    text check (comision in ('tecnologia', 'ambiental', 'relevamiento',
                                       'comunicacion', 'administracion', 'consejo',
                                       'asesora')),
  perfil      text check (perfil in ('relevador', 'ambiental', 'administracion',
                                     'tecnologia', 'docente')),
  activo      boolean not null default true,
  creado_en   timestamptz not null default now()
);
comment on column public.perfiles.perfil is
  'Nulo hasta que Tecnología asigna el perfil. Sin perfil o inactivo no accede a ningún dato.';

-- Puntos de relevamiento (lista desplegable de la pantalla C)
create table public.lugares (
  id        bigint generated always as identity primary key,
  nombre    text not null unique check (char_length(nombre) between 3 and 60),
  activo    boolean not null default true
);

-- Registros de residuos cargados por los relevadores
create table public.registros_residuos (
  id               uuid primary key default gen_random_uuid(),
  fecha            date not null default public.hoy(),
  hora             time not null default (now() at time zone 'America/Argentina/Buenos_Aires')::time,
  lugar_id         bigint not null references public.lugares (id),
  tipo             text not null check (tipo in ('interno', 'externo')),
  descripcion      text not null check (char_length(descripcion) between 5 and 300),
  cantidad_bolsas  integer not null default 0 check (cantidad_bolsas between 0 and 50),
  critica          boolean generated always as (cantidad_bolsas >= 3) stored,
  clima            text check (clima in ('soleado', 'nublado', 'lluvia')),
  foto_path        text,
  estado           text not null default 'pendiente'
                   check (estado in ('pendiente', 'revisado', 'anulado')),
  motivo_anulacion text check (motivo_anulacion is null or char_length(motivo_anulacion) <= 200),
  creado_por       uuid references public.perfiles (id),
  revisado_por     uuid references public.perfiles (id),
  datos_prueba     boolean not null default false,
  creado_en        timestamptz not null default now(),
  actualizado_en   timestamptz not null default now(),
  constraint registro_anulado_con_motivo check (estado <> 'anulado' or motivo_anulacion is not null)
);

-- Reciclables recuperados en el punto verde
create table public.reciclables (
  id               uuid primary key default gen_random_uuid(),
  fecha            date not null default public.hoy(),
  material         text not null check (material in ('plastico', 'papel', 'vidrio', 'metal')),
  kilos            numeric(7, 2) not null check (kilos > 0 and kilos <= 1000),
  observacion      text check (observacion is null or char_length(observacion) <= 200),
  anulado          boolean not null default false,
  motivo_anulacion text check (motivo_anulacion is null or char_length(motivo_anulacion) <= 200),
  creado_por       uuid references public.perfiles (id),
  datos_prueba     boolean not null default false,
  creado_en        timestamptz not null default now(),
  actualizado_en   timestamptz not null default now(),
  constraint reciclable_anulado_con_motivo check (not anulado or motivo_anulacion is not null)
);

-- Informes al municipio
create table public.informes (
  id                    uuid primary key default gen_random_uuid(),
  titulo                text not null check (char_length(titulo) between 5 and 120),
  periodo_desde         date not null,
  periodo_hasta         date not null,
  introduccion          text check (introduccion is null or char_length(introduccion) <= 2000),
  incluye_fotos         boolean not null default true,
  estado                text not null default 'borrador'
                        check (estado in ('borrador', 'en_revision', 'aprobado', 'enviado')),
  observaciones_docente text check (observaciones_docente is null or char_length(observaciones_docente) <= 2000),
  revisado_por          uuid references public.perfiles (id),
  fecha_envio           date,
  respuesta_municipio   text not null default 'sin_respuesta'
                        check (respuesta_municipio in ('sin_respuesta', 'si', 'no')),
  respuesta_detalle     text check (respuesta_detalle is null or char_length(respuesta_detalle) <= 2000),
  creado_por            uuid references public.perfiles (id),
  datos_prueba          boolean not null default false,
  creado_en             timestamptz not null default now(),
  actualizado_en        timestamptz not null default now(),
  constraint informe_periodo_valido check (periodo_desde <= periodo_hasta),
  constraint informe_envio_con_fecha check (estado <> 'enviado' or fecha_envio is not null)
);

-- Informes de seguimiento del piloto. Los datos calculados se guardan como
-- una instantánea para que el documento histórico no cambie si luego se
-- corrigen registros, pesajes o gastos del período.
create table public.seguimientos (
  id               uuid primary key default gen_random_uuid(),
  titulo           text not null check (char_length(titulo) between 5 and 120),
  periodo_desde    date not null,
  periodo_hasta    date not null,
  interpretacion   text check (interpretacion is null or char_length(interpretacion) <= 4000),
  acciones         text check (acciones is null or char_length(acciones) <= 3000),
  datos            jsonb not null check (jsonb_typeof(datos) = 'object'),
  consultado_en    timestamptz not null,
  creado_por       uuid references public.perfiles (id),
  datos_prueba     boolean not null default false,
  creado_en        timestamptz not null default now(),
  actualizado_en   timestamptz not null default now(),
  constraint seguimiento_periodo_valido check (
    periodo_desde <= periodo_hasta and periodo_hasta <= public.hoy()
  )
);

-- Actas de reuniones (artículo 7 del reglamento)
create table public.actas (
  id             uuid primary key default gen_random_uuid(),
  fecha          date not null,
  participantes  text not null check (char_length(participantes) between 3 and 1000),
  temas          text not null check (char_length(temas) between 3 and 2000),
  decisiones     text not null check (char_length(decisiones) between 3 and 2000),
  responsables   text check (responsables is null or char_length(responsables) <= 1000),
  creado_por     uuid references public.perfiles (id),
  datos_prueba   boolean not null default false,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

-- Recursos y gastos (artículo 8 del reglamento)
create table public.movimientos (
  id               uuid primary key default gen_random_uuid(),
  fecha            date not null,
  concepto         text not null check (char_length(concepto) between 3 and 120),
  tipo             text not null check (tipo in ('ingreso', 'gasto')),
  monto            numeric(12, 2) not null check (monto > 0),
  comprobante_path text,
  anulado          boolean not null default false,
  motivo_anulacion text check (motivo_anulacion is null or char_length(motivo_anulacion) <= 200),
  creado_por       uuid references public.perfiles (id),
  datos_prueba     boolean not null default false,
  creado_en        timestamptz not null default now(),
  actualizado_en   timestamptz not null default now(),
  constraint movimiento_anulado_con_motivo check (not anulado or motivo_anulacion is not null)
);

create index registros_fecha_idx on public.registros_residuos (fecha desc, hora desc);
create index registros_lugar_idx on public.registros_residuos (lugar_id);
create index registros_creado_por_idx on public.registros_residuos (creado_por);
create index reciclables_fecha_idx on public.reciclables (fecha desc);
create index informes_estado_idx on public.informes (estado);
create index seguimientos_periodo_idx on public.seguimientos (periodo_hasta desc, periodo_desde desc);
create index seguimientos_creado_por_idx on public.seguimientos (creado_por);
create index actas_fecha_idx on public.actas (fecha desc);
create index movimientos_fecha_idx on public.movimientos (fecha desc);

-- ---------------------------------------------------------------------
-- 2. Funciones auxiliares
-- ---------------------------------------------------------------------

-- Perfil del usuario actual, solo si está activo. Nulo = sin acceso.
create or replace function public.mi_perfil()
returns text
language sql stable security definer
set search_path = public
as $$
  select perfil from public.perfiles where id = auth.uid() and activo
$$;

create or replace function public.tiene_perfil(variadic perfiles text[])
returns boolean
language sql stable
set search_path = public
as $$
  select coalesce(public.mi_perfil() = any (perfiles), false)
$$;

create or replace function public.es_integrante()
returns boolean
language sql stable
set search_path = public
as $$
  select public.mi_perfil() is not null
$$;

-- Nombres de los integrantes: los listados muestran quién cargó cada dato
-- sin exponer el resto de la tabla perfiles.
create or replace function public.nombres_integrantes()
returns table (id uuid, nombre text, apellido text)
language sql stable security definer
set search_path = public
as $$
  select p.id, p.nombre, p.apellido
  from public.perfiles p
  where public.es_integrante()
$$;

-- Al crear la cuenta en Supabase Auth se crea el perfil, sin rol asignado.
create or replace function public.crear_perfil_usuario()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.perfiles (id, email, nombre, apellido)
  values (
    new.id,
    new.email,
    left(coalesce(new.raw_user_meta_data ->> 'nombre', ''), 60),
    left(coalesce(new.raw_user_meta_data ->> 'apellido', ''), 60)
  );
  return new;
end;
$$;

create trigger al_crear_usuario
  after insert on auth.users
  for each row execute function public.crear_perfil_usuario();

-- Tecnología asigna perfil, comisión, curso y estado a un usuario.
create or replace function public.asignar_perfil(
  p_usuario  uuid,
  p_perfil   text,
  p_comision text,
  p_curso    text,
  p_activo   boolean,
  p_nombre   text default null,
  p_apellido text default null
)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.tiene_perfil('tecnologia') then
    raise exception 'Solo la Comisión de Tecnología puede asignar perfiles.'
      using errcode = '42501';
  end if;
  if p_usuario = auth.uid() and (p_perfil is distinct from 'tecnologia' or not p_activo) then
    raise exception 'No podés quitarte tu propio perfil de Tecnología ni desactivarte.';
  end if;
  update public.perfiles
     set perfil   = p_perfil,
         comision = nullif(p_comision, ''),
         curso    = nullif(trim(p_curso), ''),
         activo   = p_activo,
         nombre   = coalesce(nullif(trim(p_nombre), ''), nombre),
         apellido = coalesce(nullif(trim(p_apellido), ''), apellido)
   where id = p_usuario;
  if not found then
    raise exception 'El usuario no existe.';
  end if;
end;
$$;

-- El usuario puede corregir su nombre y apellido, nada más.
create or replace function public.actualizar_mis_datos(p_nombre text, p_apellido text)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if char_length(trim(p_nombre)) < 2 or char_length(trim(p_apellido)) < 2 then
    raise exception 'Nombre y apellido deben tener al menos 2 letras.';
  end if;
  update public.perfiles set nombre = trim(p_nombre), apellido = trim(p_apellido)
   where id = auth.uid();
end;
$$;

-- ---------------------------------------------------------------------
-- 3. Reglas de negocio (triggers)
-- ---------------------------------------------------------------------

-- Autor, marca de prueba y fecha de actualización los pone la base.
create or replace function public.preparar_alta()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is not null then
    new.creado_por := auth.uid();
    new.datos_prueba := false;
  end if;
  return new;
end;
$$;

create or replace function public.marcar_actualizacion()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.actualizado_en := now();
  -- autor, alta y marca de prueba no se modifican
  new.creado_por := old.creado_por;
  new.creado_en := old.creado_en;
  new.datos_prueba := old.datos_prueba;
  return new;
end;
$$;

-- Registros de residuos: qué puede cambiar cada perfil
create or replace function public.validar_registro()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_perfil text := public.mi_perfil();
begin
  if auth.uid() is null then
    return new; -- carga por SQL (administrador de la base)
  end if;

  if tg_op = 'INSERT' then
    new.estado := 'pendiente';
    new.revisado_por := null;
    new.motivo_anulacion := null;
    return new;
  end if;

  if old.estado = 'anulado' then
    raise exception 'El registro está anulado y no se puede modificar.';
  end if;

  if v_perfil = 'relevador' then
    if old.creado_por is distinct from auth.uid() then
      raise exception 'Solo podés corregir tus propios registros.';
    end if;
    if old.estado <> 'pendiente' then
      raise exception 'El registro ya fue revisado y no se puede corregir.';
    end if;
    if new.estado <> old.estado then
      raise exception 'El relevador no puede cambiar el estado del registro.';
    end if;
    new.revisado_por := old.revisado_por;
    new.motivo_anulacion := old.motivo_anulacion;
  elsif v_perfil = 'ambiental' then
    -- revisa y clasifica: estado (pendiente/revisado) y tipo
    if new.estado = 'anulado' then
      raise exception 'Solo Tecnología puede anular registros.';
    end if;
    if (new.fecha, new.hora, new.lugar_id, new.descripcion, new.cantidad_bolsas,
        new.clima, new.foto_path)
       is distinct from
       (old.fecha, old.hora, old.lugar_id, old.descripcion, old.cantidad_bolsas,
        old.clima, old.foto_path) then
      raise exception 'La Comisión Ambiental solo puede cambiar el tipo y el estado.';
    end if;
    new.revisado_por := case when new.estado = 'revisado' then auth.uid() else null end;
  elsif v_perfil = 'tecnologia' then
    -- solo anula (duplicados o errores); el registro se conserva
    if new.estado <> 'anulado' or row(new.fecha, new.hora, new.lugar_id, new.tipo,
        new.descripcion, new.cantidad_bolsas, new.clima, new.foto_path)
       is distinct from row(old.fecha, old.hora, old.lugar_id, old.tipo,
        old.descripcion, old.cantidad_bolsas, old.clima, old.foto_path) then
      raise exception 'Tecnología solo puede anular registros, indicando el motivo.';
    end if;
  else
    raise exception 'Tu perfil no puede modificar registros.' using errcode = '42501';
  end if;

  return new;
end;
$$;

-- Fechas: ningún registro puede tener fecha futura
create or replace function public.controlar_fecha()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.fecha > public.hoy() then
    raise exception 'La fecha no puede ser posterior a hoy.';
  end if;
  return new;
end;
$$;

-- Reciclables y movimientos: la anulación conserva el registro.
-- Reciclables: Ambiental corrige, Tecnología anula (borrado lógico).
-- Movimientos: Administración corrige o anula con motivo.
create or replace function public.validar_anulacion()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_perfil text := public.mi_perfil();
begin
  if auth.uid() is null then
    return new;
  end if;
  if old.anulado then
    raise exception 'El registro está anulado y no se puede modificar.';
  end if;
  if tg_table_name = 'reciclables' then
    if v_perfil = 'ambiental' and new.anulado then
      raise exception 'Solo Tecnología puede anular reciclables.';
    end if;
    if v_perfil = 'tecnologia' and (not new.anulado or
       (new.fecha, new.material, new.kilos, new.observacion)
       is distinct from (old.fecha, old.material, old.kilos, old.observacion)) then
      raise exception 'Tecnología solo puede anular el registro, indicando el motivo.';
    end if;
  end if;
  return new;
end;
$$;

-- Informes: circuito borrador -> en revisión -> aprobado -> enviado
create or replace function public.validar_informe()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_perfil text := public.mi_perfil();
begin
  if auth.uid() is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.estado := 'borrador';
    new.observaciones_docente := null;
    new.revisado_por := null;
    new.fecha_envio := null;
    new.respuesta_municipio := 'sin_respuesta';
    new.respuesta_detalle := null;
    if new.periodo_hasta > public.hoy() then
      raise exception 'El período no puede terminar en una fecha futura.';
    end if;
    return new;
  end if;

  if v_perfil = 'docente' then
    if old.estado <> 'en_revision' then
      raise exception 'El docente solo puede revisar informes enviados a revisión.';
    end if;
    if new.estado not in ('en_revision', 'aprobado', 'borrador') then
      raise exception 'Cambio de estado no permitido.';
    end if;
    if (new.titulo, new.periodo_desde, new.periodo_hasta, new.introduccion,
        new.incluye_fotos, new.fecha_envio, new.respuesta_municipio, new.respuesta_detalle)
       is distinct from
       (old.titulo, old.periodo_desde, old.periodo_hasta, old.introduccion,
        old.incluye_fotos, old.fecha_envio, old.respuesta_municipio, old.respuesta_detalle) then
      raise exception 'El docente solo puede dejar observaciones y aprobar o devolver el informe.';
    end if;
    if new.estado = 'borrador' and coalesce(trim(new.observaciones_docente), '') = '' then
      raise exception 'Para devolver el informe tenés que dejar una observación.';
    end if;
    new.revisado_por := auth.uid();
    return new;
  end if;

  if v_perfil = 'administracion' then
    if new.observaciones_docente is distinct from old.observaciones_docente then
      raise exception 'Las observaciones las escribe el docente asesor.';
    end if;
    -- contenido editable solo en borrador
    if old.estado <> 'borrador' and
       (new.titulo, new.periodo_desde, new.periodo_hasta, new.introduccion, new.incluye_fotos)
       is distinct from
       (old.titulo, old.periodo_desde, old.periodo_hasta, old.introduccion, old.incluye_fotos) then
      raise exception 'El informe solo se puede editar en borrador.';
    end if;
    if new.periodo_hasta > public.hoy() and new.periodo_hasta is distinct from old.periodo_hasta then
      raise exception 'El período no puede terminar en una fecha futura.';
    end if;
    if new.estado <> old.estado then
      if not ((old.estado = 'borrador' and new.estado = 'en_revision')
           or (old.estado = 'aprobado' and new.estado = 'enviado')) then
        raise exception 'Cambio de estado no permitido: de % a %.', old.estado, new.estado;
      end if;
      if new.estado = 'enviado' then
        new.fecha_envio := coalesce(new.fecha_envio, public.hoy());
      end if;
    end if;
    if (new.respuesta_municipio, new.respuesta_detalle)
       is distinct from (old.respuesta_municipio, old.respuesta_detalle)
       and new.estado <> 'enviado' then
      raise exception 'La respuesta del municipio se registra después de enviar el informe.';
    end if;
    new.revisado_por := old.revisado_por;
    return new;
  end if;

  raise exception 'Tu perfil no puede modificar informes.' using errcode = '42501';
end;
$$;

create trigger registros_alta before insert on public.registros_residuos
  for each row execute function public.preparar_alta();
create trigger registros_reglas before insert or update on public.registros_residuos
  for each row execute function public.validar_registro();
create trigger registros_actualizacion before update on public.registros_residuos
  for each row execute function public.marcar_actualizacion();

create trigger registros_fecha before insert or update on public.registros_residuos
  for each row execute function public.controlar_fecha();
create trigger reciclables_fecha before insert or update on public.reciclables
  for each row execute function public.controlar_fecha();
create trigger actas_fecha before insert or update on public.actas
  for each row execute function public.controlar_fecha();
create trigger movimientos_fecha before insert or update on public.movimientos
  for each row execute function public.controlar_fecha();

create trigger reciclables_alta before insert on public.reciclables
  for each row execute function public.preparar_alta();
create trigger reciclables_reglas before update on public.reciclables
  for each row execute function public.validar_anulacion();
create trigger reciclables_actualizacion before update on public.reciclables
  for each row execute function public.marcar_actualizacion();

create trigger informes_alta before insert on public.informes
  for each row execute function public.preparar_alta();
create trigger informes_reglas before insert or update on public.informes
  for each row execute function public.validar_informe();
create trigger informes_actualizacion before update on public.informes
  for each row execute function public.marcar_actualizacion();

create trigger seguimientos_alta before insert on public.seguimientos
  for each row execute function public.preparar_alta();
create trigger seguimientos_actualizacion before update on public.seguimientos
  for each row execute function public.marcar_actualizacion();

create trigger actas_alta before insert on public.actas
  for each row execute function public.preparar_alta();
create trigger actas_actualizacion before update on public.actas
  for each row execute function public.marcar_actualizacion();

create trigger movimientos_alta before insert on public.movimientos
  for each row execute function public.preparar_alta();
create trigger movimientos_reglas before update on public.movimientos
  for each row execute function public.validar_anulacion();
create trigger movimientos_actualizacion before update on public.movimientos
  for each row execute function public.marcar_actualizacion();

-- ---------------------------------------------------------------------
-- 4. Vistas para los listados (respetan los permisos de quien consulta)
-- ---------------------------------------------------------------------

create view public.v_registros with (security_invoker = true) as
select r.*,
       l.nombre as lugar,
       extract(isodow from r.fecha)::int as dia_semana
from public.registros_residuos r
join public.lugares l on l.id = r.lugar_id;

-- ---------------------------------------------------------------------
-- 5. Permisos sobre los datos (Row Level Security)
--    V ver · C crear · M modificar · B borrar (anular)
-- ---------------------------------------------------------------------

alter table public.perfiles            enable row level security;
alter table public.lugares             enable row level security;
alter table public.registros_residuos  enable row level security;
alter table public.reciclables         enable row level security;
alter table public.informes            enable row level security;
alter table public.seguimientos        enable row level security;
alter table public.actas               enable row level security;
alter table public.movimientos         enable row level security;

-- Usuarios: cada uno ve el suyo; Admin., Tecnología y Docente ven todos.
-- Los cambios se hacen solo con asignar_perfil() y actualizar_mis_datos().
create policy perfiles_ver on public.perfiles for select to authenticated
  using (id = auth.uid() or public.tiene_perfil('administracion', 'tecnologia', 'docente'));

-- Lugares: todos ven; Tecnología administra
create policy lugares_ver on public.lugares for select to authenticated
  using (public.es_integrante());
create policy lugares_crear on public.lugares for insert to authenticated
  with check (public.tiene_perfil('tecnologia'));
create policy lugares_modificar on public.lugares for update to authenticated
  using (public.tiene_perfil('tecnologia')) with check (public.tiene_perfil('tecnologia'));

-- Registros de residuos: todos ven; Relevador crea y corrige los suyos;
-- Ambiental revisa; Tecnología anula.
create policy registros_ver on public.registros_residuos for select to authenticated
  using (public.es_integrante());
create policy registros_crear on public.registros_residuos for insert to authenticated
  with check (public.tiene_perfil('relevador'));
create policy registros_modificar on public.registros_residuos for update to authenticated
  using (
    (public.tiene_perfil('relevador') and creado_por = auth.uid())
    or public.tiene_perfil('ambiental', 'tecnologia')
  )
  with check (
    (public.tiene_perfil('relevador') and creado_por = auth.uid())
    or public.tiene_perfil('ambiental', 'tecnologia')
  );

-- Reciclables: todos ven; Ambiental crea y modifica; Tecnología anula.
create policy reciclables_ver on public.reciclables for select to authenticated
  using (public.es_integrante());
create policy reciclables_crear on public.reciclables for insert to authenticated
  with check (public.tiene_perfil('ambiental'));
create policy reciclables_modificar on public.reciclables for update to authenticated
  using (public.tiene_perfil('ambiental', 'tecnologia'))
  with check (public.tiene_perfil('ambiental', 'tecnologia'));

-- Informes: el Relevador no accede; Admin. crea y modifica; Docente observa y aprueba.
create policy informes_ver on public.informes for select to authenticated
  using (public.tiene_perfil('ambiental', 'administracion', 'tecnologia', 'docente'));
create policy informes_crear on public.informes for insert to authenticated
  with check (public.tiene_perfil('administracion'));
create policy informes_modificar on public.informes for update to authenticated
  using (public.tiene_perfil('administracion', 'docente'))
  with check (public.tiene_perfil('administracion', 'docente'));
create policy informes_borrar on public.informes for delete to authenticated
  using (public.tiene_perfil('administracion') and estado = 'borrador');

-- Seguimientos: los cuatro perfiles responsables pueden consultar, crear y
-- actualizar documentos. Administración puede eliminar un seguimiento.
create policy seguimientos_ver on public.seguimientos for select to authenticated
  using (public.tiene_perfil('ambiental', 'administracion', 'tecnologia', 'docente'));
create policy seguimientos_crear on public.seguimientos for insert to authenticated
  with check (public.tiene_perfil('ambiental', 'administracion', 'tecnologia', 'docente'));
create policy seguimientos_modificar on public.seguimientos for update to authenticated
  using (public.tiene_perfil('ambiental', 'administracion', 'tecnologia', 'docente'))
  with check (public.tiene_perfil('ambiental', 'administracion', 'tecnologia', 'docente'));
create policy seguimientos_borrar on public.seguimientos for delete to authenticated
  using (public.tiene_perfil('administracion'));

-- Actas y movimientos: todos ven (artículo 3); solo Administración carga.
create policy actas_ver on public.actas for select to authenticated
  using (public.es_integrante());
create policy actas_crear on public.actas for insert to authenticated
  with check (public.tiene_perfil('administracion'));
create policy actas_modificar on public.actas for update to authenticated
  using (public.tiene_perfil('administracion'))
  with check (public.tiene_perfil('administracion'));

create policy movimientos_ver on public.movimientos for select to authenticated
  using (public.es_integrante());
create policy movimientos_crear on public.movimientos for insert to authenticated
  with check (public.tiene_perfil('administracion'));
create policy movimientos_modificar on public.movimientos for update to authenticated
  using (public.tiene_perfil('administracion'))
  with check (public.tiene_perfil('administracion'));

-- Privilegios de tabla: el visitante anónimo no accede a nada.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all functions in schema public from anon;
grant usage on schema public to authenticated;
grant select on all tables in schema public to authenticated;
grant insert, update on public.lugares, public.registros_residuos, public.reciclables,
  public.informes, public.seguimientos, public.actas, public.movimientos to authenticated;
grant delete on public.informes, public.seguimientos to authenticated;
grant execute on function public.mi_perfil(), public.tiene_perfil(text[]),
  public.es_integrante(), public.nombres_integrantes(),
  public.asignar_perfil(uuid, text, text, text, boolean, text, text),
  public.actualizar_mis_datos(text, text) to authenticated;
grant execute on function public.crear_perfil_usuario(), public.preparar_alta(),
  public.marcar_actualizacion(), public.validar_registro(), public.validar_anulacion(),
  public.validar_informe(), public.controlar_fecha(), public.hoy() to authenticated;

-- ---------------------------------------------------------------------
-- 6. Archivos (Supabase Storage): fotos de registros y comprobantes
--    Buckets privados; se acceden con URLs firmadas.
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('fotos', 'fotos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('comprobantes', 'comprobantes', false, 5242880, array['image/jpeg', 'image/png', 'application/pdf'])
on conflict (id) do nothing;

create policy fotos_ver on storage.objects for select to authenticated
  using (bucket_id = 'fotos' and public.es_integrante());
-- cada relevador sube dentro de una carpeta con su id
create policy fotos_subir on storage.objects for insert to authenticated
  with check (bucket_id = 'fotos' and public.tiene_perfil('relevador')
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy comprobantes_ver on storage.objects for select to authenticated
  using (bucket_id = 'comprobantes' and public.es_integrante());
create policy comprobantes_subir on storage.objects for insert to authenticated
  with check (bucket_id = 'comprobantes' and public.tiene_perfil('administracion'));
