-- =====================================================================
-- EcoSegura - Borra la estructura para reconstruirla con schema.sql.
-- ATENCIÓN: elimina todos los datos de la cooperativa.
-- No borra las cuentas de Supabase Auth.
-- =====================================================================
drop trigger if exists al_crear_usuario on auth.users;

drop policy if exists fotos_ver on storage.objects;
drop policy if exists fotos_subir on storage.objects;
drop policy if exists comprobantes_ver on storage.objects;
drop policy if exists comprobantes_subir on storage.objects;

drop view if exists public.v_registros;
drop table if exists public.movimientos cascade;
drop table if exists public.actas cascade;
drop table if exists public.informes cascade;
drop table if exists public.reciclables cascade;
drop table if exists public.registros_residuos cascade;
drop table if exists public.lugares cascade;
drop table if exists public.perfiles cascade;

drop function if exists public.asignar_perfil(uuid, text, text, text, boolean, text, text);
drop function if exists public.actualizar_mis_datos(text, text);
drop function if exists public.nombres_integrantes();
drop function if exists public.crear_perfil_usuario();
drop function if exists public.preparar_alta();
drop function if exists public.marcar_actualizacion();
drop function if exists public.validar_registro();
drop function if exists public.validar_anulacion();
drop function if exists public.validar_informe();
drop function if exists public.controlar_fecha();
drop function if exists public.es_integrante();
drop function if exists public.tiene_perfil(text[]);
drop function if exists public.mi_perfil();
drop function if exists public.hoy();
-- Los buckets 'fotos' y 'comprobantes' se vacían y borran desde el panel de Storage.
