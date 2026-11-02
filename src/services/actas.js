import { supabase } from '@/lib/supabase'
import { datos, patron } from './util'

export async function listarActas({ busqueda = '', desde = '', hasta = '' } = {}) {
  let q = supabase
    .from('actas')
    .select('id, fecha, participantes, temas, decisiones, responsables, datos_prueba, creado_por, actualizado_en')
    .order('fecha', { ascending: false })
  if (busqueda) {
    const p = patron(busqueda)
    q = q.or(`temas.ilike.${p},decisiones.ilike.${p},participantes.ilike.${p},responsables.ilike.${p}`)
  }
  if (desde) q = q.gte('fecha', desde)
  if (hasta) q = q.lte('fecha', hasta)
  return datos(await q)
}

export async function guardarActa(acta, id = null) {
  const q = id
    ? supabase.from('actas').update(acta).eq('id', id)
    : supabase.from('actas').insert(acta)
  return datos(await q.select('id').single())
}
