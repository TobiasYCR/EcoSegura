import { supabase } from '@/lib/supabase'
import { datos } from './util'

export async function listarReciclables({ material = '', desde = '', hasta = '', incluirAnulados = false } = {}) {
  let q = supabase
    .from('reciclables')
    .select('id, fecha, material, kilos, observacion, anulado, motivo_anulacion, creado_por, datos_prueba')
    .order('fecha', { ascending: false })
    .order('creado_en', { ascending: false })
  if (material) q = q.eq('material', material)
  if (desde) q = q.gte('fecha', desde)
  if (hasta) q = q.lte('fecha', hasta)
  if (!incluirAnulados) q = q.eq('anulado', false)
  return datos(await q)
}

export async function crearReciclable(r) {
  return datos(await supabase.from('reciclables').insert(r).select('id').single())
}

export async function actualizarReciclable(id, cambios) {
  return datos(await supabase.from('reciclables').update(cambios).eq('id', id).select('id').single())
}
