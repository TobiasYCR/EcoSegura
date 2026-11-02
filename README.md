# EcoSegura

Sistema de gestión ambiental de la Cooperativa Escolar EcoSegura.
Vue 3 + Vite + Vue Router en el frontend; Supabase (PostgreSQL, Auth y Storage) como backend.

## Puesta en marcha

1. Crear un proyecto en Supabase. En **SQL Editor** ejecutar, en orden:
   - `supabase/schema.sql`
   - `supabase/seed.sql` (datos de prueba, opcional)
2. En **Authentication > Sign In / Providers > Email**: desactivar **Confirm email** (Tecnología crea las cuentas desde la app).
3. Crear la primera cuenta en **Authentication > Users > Add user** (marcar *Auto Confirm User*) y asignarle el perfil de Tecnología:
   ```sql
   update public.perfiles
      set perfil = 'tecnologia', comision = 'tecnologia', activo = true
    where email = 'tecnologia@ejemplo.com';
   ```
4. Configurar y levantar la app:
   ```bash
   cp .env.example .env   # completar URL y clave publicable (Project Settings > API)
   npm install
   npm run dev
   ```

## Scripts

| Comando | Uso |
|---|---|
| `npm run dev` | Servidor de desarrollo |
| `npm run build` | Compilación de producción en `dist/` |
| `npm run lint` | Revisión de código con ESLint |

## Base de datos

| Archivo | Uso |
|---|---|
| `supabase/schema.sql` | Estructura completa: tablas, triggers, vista, políticas RLS y buckets |
| `supabase/seed.sql` | Datos ficticios marcados con `datos_prueba = true` |
| `supabase/reset.sql` | Borra la estructura para reconstruirla |
| `supabase/pruebas/pruebas_rls.sql` | Pruebas de permisos por perfil; se deshacen al terminar |
| `supabase/pruebas/supabase_local.sql` | Solo para PostgreSQL local: simula `auth` y `storage` de Supabase |

## Estructura

| Carpeta | Contenido |
|---|---|
| `src/views/` | Pantallas, una por ruta |
| `src/components/` | Layout, componentes comunes e informe |
| `src/router/` | Rutas y guardas por perfil |
| `src/services/` | Consultas a Supabase, un archivo por entidad |
| `src/composables/` | Sesión, perfil y estado de las operaciones |
| `src/utils/` | Validaciones, catálogos, fechas, errores y menú |
| `docs/` | Informe de diseño del sistema |
