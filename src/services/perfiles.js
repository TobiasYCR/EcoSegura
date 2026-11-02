import { supabase, clienteSinSesion } from '@/lib/supabase'
import { datos, patron } from './util'

export async function listarUsuarios({ busqueda = '', perfil = '', estado = 'activos' } = {}) {
  let q = supabase
    .from('perfiles')
    .select('id, email, nombre, apellido, curso, comision, perfil, activo, creado_en')
    .order('apellido')
  if (busqueda) {
    const p = patron(busqueda)
    q = q.or(`nombre.ilike.${p},apellido.ilike.${p},email.ilike.${p}`)
  }
  if (perfil === 'sin_perfil') q = q.is('perfil', null)
  else if (perfil) q = q.eq('perfil', perfil)
  if (estado === 'activos') q = q.eq('activo', true)
  if (estado === 'inactivos') q = q.eq('activo', false)
  return datos(await q)
}

// Mapa id -> "Nombre Apellido" para mostrar quién cargó cada dato
export async function mapaNombres() {
  const lista = datos(await supabase.rpc('nombres_integrantes'))
  return Object.fromEntries(lista.map((p) => [p.id, `${p.nombre} ${p.apellido}`.trim()]))
}

// Tecnología crea la cuenta y luego le asigna el perfil
export async function crearUsuario({ email, clave, nombre, apellido, perfil, comision, curso }) {
  const cliente = clienteSinSesion()
  const { data, error } = await cliente.auth.signUp({
    email: email.trim(),
    password: clave,
    options: { data: { nombre: nombre.trim(), apellido: apellido.trim() } }
  })
  if (error) throw error
  const id = data.user?.id
  if (!id || data.user?.identities?.length === 0) {
    throw new Error('User already registered')
  }
  await asignarPerfil({ id, perfil, comision, curso, activo: true, nombre, apellido })
  return id
}

export async function asignarPerfil({ id, perfil, comision, curso, activo, nombre = null, apellido = null }) {
  return datos(
    await supabase.rpc('asignar_perfil', {
      p_usuario: id,
      p_perfil: perfil || null,
      p_comision: comision || '',
      p_curso: curso || '',
      p_activo: activo,
      p_nombre: nombre,
      p_apellido: apellido
    })
  )
}

export async function actualizarMisDatos(nombre, apellido) {
  return datos(await supabase.rpc('actualizar_mis_datos', { p_nombre: nombre, p_apellido: apellido }))
}
