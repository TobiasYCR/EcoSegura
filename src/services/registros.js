import { supabase } from '@/lib/supabase'
import { datos, patron } from './util'
import { subirArchivo } from './archivos'

const CAMPOS =
  'id, fecha, hora, lugar_id, lugar, tipo, descripcion, cantidad_bolsas, critica, clima, ' +
  'foto_path, estado, motivo_anulacion, creado_por, revisado_por, datos_prueba, creado_en, dia_semana'

export async function listarRegistros({
  busqueda = '', tipo = '', estado = '', lugarId = '', desde = '', hasta = '',
  soloMios = null, limite = 200
} = {}) {
  let q = supabase
    .from('v_registros')
    .select(CAMPOS, { count: 'exact' })
    .order('fecha', { ascending: false })
    .order('hora', { ascending: false })
    .limit(limite)
  if (busqueda) {
    const p = patron(busqueda)
    q = q.or(`descripcion.ilike.${p},lugar.ilike.${p}`)
  }
  if (tipo) q = q.eq('tipo', tipo)
  if (estado === 'activos') q = q.neq('estado', 'anulado')
  else if (estado) q = q.eq('estado', estado)
  if (lugarId) q = q.eq('lugar_id', lugarId)
  if (desde) q = q.gte('fecha', desde)
  if (hasta) q = q.lte('fecha', hasta)
  if (soloMios) q = q.eq('creado_por', soloMios)
  return datos(await q)
}

export async function obtenerRegistro(id) {
  return datos(await supabase.from('v_registros').select(CAMPOS).eq('id', id).single())
}

export async function crearRegistro(registro, foto, usuarioId) {
  const foto_path = foto ? await subirArchivo('fotos', usuarioId, foto) : null
  return datos(
    await supabase.from('registros_residuos').insert({ ...registro, foto_path }).select('id').single()
  )
}

export async function actualizarRegistro(id, cambios) {
  return datos(await supabase.from('registros_residuos').update(cambios).eq('id', id).select('id').single())
}

export async function anularRegistro(id, motivo) {
  return actualizarRegistro(id, { estado: 'anulado', motivo_anulacion: motivo })
}
