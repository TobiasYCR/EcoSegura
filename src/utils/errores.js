// Traduce los errores de Supabase a mensajes en español para la interfaz.
export function traducirError(error) {
  if (!error) return ''
  const msj = error.message || String(error)
  const codigo = error.code || ''

  if (/Failed to fetch|NetworkError|fetch failed|Load failed/i.test(msj)) {
    return 'No hay conexión con el servidor. Revisá tu conexión a internet.'
  }
  if (/Invalid login credentials/i.test(msj)) return 'Email o contraseña incorrectos.'
  if (/Email not confirmed/i.test(msj)) return 'La cuenta todavía no fue confirmada.'
  if (/User already registered|already been registered/i.test(msj)) return 'Ya existe una cuenta con ese email.'
  if (/Password should be at least/i.test(msj)) return 'La contraseña debe tener al menos 8 caracteres.'
  if (/rate limit/i.test(msj)) return 'Demasiados intentos. Esperá unos minutos.'
  if (/JWT expired|invalid JWT/i.test(msj)) return 'La sesión expiró. Volvé a ingresar.'
  if (codigo === '42501' || /row-level security|permission denied/i.test(msj)) {
    return 'Tu perfil no tiene permiso para esta operación.'
  }
  if (codigo === '23505') return 'Ya existe un registro con esos datos.'
  if (codigo === '23503') return 'El dato está relacionado con otros registros.'
  if (codigo === '23514') return 'Algún valor no cumple las reglas permitidas.'
  if (/Payload too large|exceeded the maximum/i.test(msj)) return 'El archivo es demasiado grande.'
  if (/mime type|invalid_mime/i.test(msj)) return 'Formato de archivo no permitido.'
  // Mensajes de las reglas de la base (triggers): ya están en español
  if (codigo === 'P0001') return msj
  return msj
}
