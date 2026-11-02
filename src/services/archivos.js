import { supabase } from '@/lib/supabase'

function extension(archivo) {
  const partes = archivo.name.split('.')
  return partes.length > 1 ? partes.pop().toLowerCase() : 'bin'
}

// Sube un archivo a un bucket privado dentro de la carpeta indicada
export async function subirArchivo(bucket, carpeta, archivo) {
  const ruta = `${carpeta}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${extension(archivo)}`
  const { error } = await supabase.storage.from(bucket).upload(ruta, archivo, {
    contentType: archivo.type,
    upsert: false
  })
  if (error) throw error
  return ruta
}

// URL temporal (1 hora) para ver un archivo privado
export async function urlFirmada(bucket, ruta) {
  if (!ruta) return null
  const { data, error } = await supabase.storage.from(bucket).createSignedUrl(ruta, 3600)
  if (error) return null
  return data.signedUrl
}

// Varias URLs firmadas en una sola consulta (miniaturas de los listados)
export async function urlsFirmadas(bucket, rutas) {
  const lista = [...new Set(rutas.filter(Boolean))]
  if (!lista.length) return {}
  const { data, error } = await supabase.storage.from(bucket).createSignedUrls(lista, 3600)
  if (error) return {}
  return Object.fromEntries(data.filter((d) => d.signedUrl).map((d) => [d.path, d.signedUrl]))
}
