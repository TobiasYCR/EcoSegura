import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const clave = import.meta.env.VITE_SUPABASE_ANON_KEY

export const configurado = Boolean(url && clave)

if (!configurado) {
  console.error('Faltan VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY en el archivo .env')
}

// Solo URL y clave publicable: los permisos los aplica la base (RLS).
export const supabase = createClient(url || 'http://localhost', clave || 'sin-clave')

// Cliente aparte para que Tecnología cree cuentas sin cerrar su propia sesión.
export function clienteSinSesion() {
  return createClient(url, clave, {
    auth: { persistSession: false, autoRefreshToken: false, storageKey: 'eco-alta-usuario' }
  })
}
