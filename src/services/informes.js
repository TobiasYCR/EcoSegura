import { supabase } from '@/lib/supabase'
import { datos, patron } from './util'

const CAMPOS =
  'id, titulo, periodo_desde, periodo_hasta, introduccion, incluye_fotos, estado, ' +
  'observaciones_docente, revisado_por, fecha_envio, respuesta_municipio, respuesta_detalle, ' +
  'creado_por, datos_prueba, creado_en, actualizado_en'

export async function listarInformes({ busqueda = '', estado = '' } = {}) {
  let q = supabase.from('informes').select(CAMPOS).order('periodo_hasta', { ascending: false })
  if (busqueda) q = q.ilike('titulo', patron(busqueda))
  if (estado) q = q.eq('estado', estado)
  return datos(await q)
}

export async function obtenerInforme(id) {
  return datos(await supabase.from('informes').select(CAMPOS).eq('id', id).single())
}

export async function crearInforme(inf) {
  return datos(await supabase.from('informes').insert(inf).select('id').single())
}

export async function actualizarInforme(id, cambios) {
  return datos(await supabase.from('informes').update(cambios).eq('id', id).select(CAMPOS).single())
}

export async function eliminarInforme(id) {
  const { error, count } = await supabase.from('informes').delete({ count: 'exact' }).eq('id', id)
  if (error) throw error
  if (!count) throw new Error('Solo se pueden eliminar informes en borrador.')
}

// Conteos para el panel de inicio
export async function contar(tabla, filtros = {}) {
  let q = supabase.from(tabla).select('id', { count: 'exact', head: true })
  for (const [campo, valor] of Object.entries(filtros)) {
    if (campo.endsWith('>=')) q = q.gte(campo.slice(0, -2), valor)
    else q = q.eq(campo, valor)
  }
  const { count, error } = await q
  if (error) throw error
  return count || 0
}
