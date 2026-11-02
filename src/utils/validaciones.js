import { hoyISO } from './fechas'

// Cada regla devuelve el mensaje de error o '' si el valor es válido.
export const reglas = {
  obligatorio: (v) => (v === null || v === undefined || String(v).trim() === '' ? 'Campo obligatorio.' : ''),
  largo: (min, max) => (v) => {
    const n = String(v ?? '').trim().length
    if (n && n < min) return `Mínimo ${min} caracteres.`
    if (n > max) return `Máximo ${max} caracteres.`
    return ''
  },
  email: (v) => (!v || /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(String(v).trim()) ? '' : 'Email con formato inválido.'),
  entero: (min, max) => (v) => {
    if (v === '' || v === null || v === undefined) return ''
    if (!/^-?\d+$/.test(String(v))) return 'Debe ser un número entero.'
    const n = Number(v)
    if (n < min || n > max) return `Debe estar entre ${min} y ${max}.`
    return ''
  },
  decimal: (min, max) => (v) => {
    if (v === '' || v === null || v === undefined) return ''
    if (!/^\d+([.,]\d{1,2})?$/.test(String(v))) return 'Número con hasta 2 decimales.'
    const n = Number(String(v).replace(',', '.'))
    if (n <= min) return `Debe ser mayor a ${min}.`
    if (n > max) return `No puede superar ${max}.`
    return ''
  },
  noFutura: (v) => (v && v > hoyISO() ? 'La fecha no puede ser posterior a hoy.' : ''),
  hora: (v) => (!v || /^([01]\d|2[0-3]):[0-5]\d/.test(v) ? '' : 'Hora inválida.'),
  enLista: (lista) => (v) => (!v || Object.keys(lista).includes(v) ? '' : 'Valor no permitido.'),
  archivo: (tipos, maxMB) => (f) => {
    if (!f) return ''
    if (!tipos.includes(f.type)) return 'Formato no permitido.'
    if (f.size > maxMB * 1024 * 1024) return `El archivo supera ${maxMB} MB.`
    return ''
  }
}

// Valida un objeto con { campo: [reglas] } y devuelve { campo: mensaje }
export function validar(datos, esquema) {
  const errores = {}
  for (const [campo, lista] of Object.entries(esquema)) {
    for (const regla of lista) {
      const msj = regla(datos[campo], datos)
      if (msj) {
        errores[campo] = msj
        break
      }
    }
  }
  return errores
}

export const aNumero = (v) => Number(String(v).replace(',', '.'))
