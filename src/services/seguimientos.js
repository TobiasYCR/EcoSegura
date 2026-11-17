import { supabase } from '@/lib/supabase'
import { datos } from './util'

const CAMPOS =
  'id, titulo, periodo_desde, periodo_hasta, interpretacion, acciones, datos, consultado_en, ' +
  'creado_por, datos_prueba, creado_en, actualizado_en'

export async function listarSeguimientos() {
  return datos(
    await supabase
      .from('seguimientos')
      .select('id, titulo, periodo_desde, periodo_hasta, creado_por, datos_prueba, creado_en, actualizado_en')
      .order('periodo_hasta', { ascending: false })
      .order('creado_en', { ascending: false })
  )
}

export async function obtenerSeguimiento(id) {
  return datos(await supabase.from('seguimientos').select(CAMPOS).eq('id', id).single())
}

export async function crearSeguimiento(seguimiento) {
  return datos(await supabase.from('seguimientos').insert(seguimiento).select(CAMPOS).single())
}

export async function actualizarSeguimiento(id, cambios) {
  return datos(await supabase.from('seguimientos').update(cambios).eq('id', id).select(CAMPOS).single())
}

export async function eliminarSeguimiento(id) {
  const { error, count } = await supabase.from('seguimientos').delete({ count: 'exact' }).eq('id', id)
  if (error) throw error
  if (!count) throw new Error('No se pudo eliminar el seguimiento.')
}
