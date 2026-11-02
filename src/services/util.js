// Lanza el error de Supabase para que lo capture useOperacion
export function datos({ data, error, count }) {
  if (error) throw error
  return count !== undefined && count !== null ? { data, count } : data
}

// Escapa comodines para búsquedas con ilike
export function patron(texto) {
  return `%${String(texto).trim().replace(/[%_,()]/g, ' ')}%`
}
