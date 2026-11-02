const ZONA = 'America/Argentina/Buenos_Aires'

// Fecha local en formato AAAA-MM-DD
export function hoyISO() {
  return new Intl.DateTimeFormat('en-CA', { timeZone: ZONA }).format(new Date())
}

export function horaActual() {
  return new Intl.DateTimeFormat('es-AR', {
    timeZone: ZONA, hour: '2-digit', minute: '2-digit', hour12: false
  }).format(new Date())
}

export function sumarDias(iso, dias) {
  const d = new Date(iso + 'T12:00:00')
  d.setDate(d.getDate() + dias)
  return d.toISOString().slice(0, 10)
}

export function formatoFecha(iso) {
  if (!iso) return '—'
  const [a, m, d] = String(iso).slice(0, 10).split('-')
  return `${d}/${m}/${a}`
}

export function formatoFechaCorta(iso) {
  if (!iso) return '—'
  const [, m, d] = String(iso).slice(0, 10).split('-')
  return `${d}/${m}`
}

export function formatoHora(hora) {
  return hora ? String(hora).slice(0, 5) : '—'
}

export function formatoMoneda(n) {
  return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS' }).format(Number(n) || 0)
}

export function formatoKilos(n) {
  return new Intl.NumberFormat('es-AR', { maximumFractionDigits: 2 }).format(Number(n) || 0) + ' kg'
}

// Lunes de la semana de una fecha (para agrupar por semana)
export function inicioSemana(iso) {
  const d = new Date(String(iso).slice(0, 10) + 'T12:00:00')
  const dia = (d.getDay() + 6) % 7
  d.setDate(d.getDate() - dia)
  return d.toISOString().slice(0, 10)
}
