import { supabase } from '@/lib/supabase'
import { datos, patron } from './util'
import { subirArchivo } from './archivos'

export async function listarMovimientos({ busqueda = '', tipo = '', desde = '', hasta = '', incluirAnulados = false } = {}) {
  let q = supabase
    .from('movimientos')
    .select('id, fecha, concepto, tipo, monto, comprobante_path, anulado, motivo_anulacion, datos_prueba, creado_por')
    .order('fecha', { ascending: false })
    .order('creado_en', { ascending: false })
  if (busqueda) q = q.ilike('concepto', patron(busqueda))
  if (tipo) q = q.eq('tipo', tipo)
  if (desde) q = q.gte('fecha', desde)
  if (hasta) q = q.lte('fecha', hasta)
  if (!incluirAnulados) q = q.eq('anulado', false)
  return datos(await q)
}

export async function guardarMovimiento(mov, comprobante = null, id = null) {
  const fila = { ...mov }
  if (comprobante) fila.comprobante_path = await subirArchivo('comprobantes', 'movimientos', comprobante)
  const q = id
    ? supabase.from('movimientos').update(fila).eq('id', id)
    : supabase.from('movimientos').insert(fila)
  return datos(await q.select('id').single())
}

export async function anularMovimiento(id, motivo) {
  return datos(
    await supabase.from('movimientos').update({ anulado: true, motivo_anulacion: motivo }).eq('id', id).select('id').single()
  )
}
