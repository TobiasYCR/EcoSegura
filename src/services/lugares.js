import { supabase } from '@/lib/supabase'
import { datos } from './util'

export async function listarLugares({ soloActivos = true } = {}) {
  let q = supabase.from('lugares').select('id, nombre, activo').order('nombre')
  if (soloActivos) q = q.eq('activo', true)
  return datos(await q)
}

export async function crearLugar(nombre) {
  return datos(await supabase.from('lugares').insert({ nombre: nombre.trim() }).select().single())
}

export async function actualizarLugar(id, cambios) {
  return datos(await supabase.from('lugares').update(cambios).eq('id', id).select().single())
}
