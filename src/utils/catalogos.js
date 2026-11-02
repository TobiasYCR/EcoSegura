export const PERFILES = {
  relevador: 'Relevador',
  ambiental: 'Ambiental',
  administracion: 'Administración y Consejo',
  tecnologia: 'Tecnología',
  docente: 'Docente asesor'
}

export const COMISIONES = {
  relevamiento: 'Comisión de Relevamiento',
  ambiental: 'Comisión Ambiental',
  administracion: 'Comisión de Administración',
  consejo: 'Consejo de Administración',
  tecnologia: 'Comisión de Tecnología',
  comunicacion: 'Comisión de Comunicación',
  asesora: 'Comisión asesora / Sindicatura'
}

export const TIPOS_RESIDUO = { interno: 'Interno', externo: 'Externo' }
export const CLIMAS = { soleado: 'Soleado', nublado: 'Nublado', lluvia: 'Lluvia' }
export const MATERIALES = { plastico: 'Plástico', papel: 'Papel', vidrio: 'Vidrio', metal: 'Metal' }
export const TIPOS_MOVIMIENTO = { ingreso: 'Ingreso', gasto: 'Gasto' }

export const ESTADOS_REGISTRO = { pendiente: 'Pendiente', revisado: 'Revisado', anulado: 'Anulado' }
export const ESTADOS_INFORME = {
  borrador: 'Borrador',
  en_revision: 'En revisión',
  aprobado: 'Aprobado',
  enviado: 'Enviado'
}
export const RESPUESTAS_MUNICIPIO = { sin_respuesta: 'Sin respuesta', si: 'Sí', no: 'No' }

export const DIAS = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo']

// Franjas de relevamiento: entrada, recreos y salida
export const FRANJAS = ['8 h', '10 h', '12 h', '14 h', '16 h']
export function franjaDe(hora) {
  const h = Number(String(hora).slice(0, 2))
  if (h < 9) return '8 h'
  if (h < 11) return '10 h'
  if (h < 13) return '12 h'
  if (h < 15) return '14 h'
  return '16 h'
}

export const BOLSAS_CRITICA = 3
