import { listarRegistros } from './registros'
import { listarReciclables } from './reciclables'
import { listarMovimientos } from './movimientos'
import { FRANJAS, franjaDe } from '@/utils/catalogos'
import { formatoFechaCorta, inicioSemana, semanasCompletas } from '@/utils/fechas'

const redondear = (n, decimales = 1) => Number(Number(n || 0).toFixed(decimales))
const sumar = (lista, valor) => lista.reduce((total, item) => total + Number(valor(item) || 0), 0)

function agrupar(lista, clave, valor = () => 1) {
  const resultado = {}
  for (const item of lista) {
    const k = clave(item)
    resultado[k] = (resultado[k] || 0) + Number(valor(item) || 0)
  }
  return resultado
}

function estadoKpi(calculable, cumple) {
  if (!calculable) return 'no_calculable'
  return cumple ? 'cumplida' : 'no_cumplida'
}

export async function cargarIndicadores({ desde, hasta, lugarId = '' }) {
  const [{ data: registros }, reciclables, movimientos] = await Promise.all([
    listarRegistros({ desde, hasta, lugarId, estado: 'activos', limite: 5000 }),
    listarReciclables({ desde, hasta }),
    listarMovimientos({ desde, hasta, tipo: 'gasto' })
  ])
  return calcularIndicadores({ desde, hasta, registros, reciclables, movimientos })
}

export function calcularIndicadores({ desde, hasta, registros, reciclables, movimientos }) {
  const semanas = semanasCompletas(desde, hasta)
  const clavesSemana = semanas.map((s) => s.desde)
  const registrosExternos = registros.filter((r) => r.tipo === 'externo')
  const criticasExternas = registrosExternos.filter((r) => r.critica)
  const criticasAgrupadas = agrupar(criticasExternas, (r) => inicioSemana(r.fecha))
  const externasAgrupadas = agrupar(registrosExternos, (r) => inicioSemana(r.fecha))
  const kilosAgrupados = agrupar(reciclables, (r) => inicioSemana(r.fecha), (r) => r.kilos)
  const gastosAgrupados = agrupar(movimientos, (r) => inicioSemana(r.fecha), (r) => r.monto)

  const criticasSemana = clavesSemana.map((clave, i) => ({
    clave,
    etiqueta: `Sem. ${i + 1}`,
    valor: criticasAgrupadas[clave] || 0
  }))
  const kilosSemana = clavesSemana.map((clave, i) => ({
    clave,
    etiqueta: `Sem. ${i + 1}`,
    valor: redondear(kilosAgrupados[clave] || 0, 2)
  }))

  const primera = criticasSemana[0]?.valor
  const ultima = criticasSemana.at(-1)?.valor
  const reduccionCalculable = semanas.length >= 2 && primera > 0
  const reduccion = reduccionCalculable ? redondear(((primera - ultima) / primera) * 100) : null

  const kilosUltima = kilosSemana.at(-1)?.valor || 0
  const kilosCalculable = semanas.length > 0 && kilosUltima > 0
  const kilosTotales = redondear(sumar(reciclables, (r) => r.kilos), 2)
  const gastosTotales = redondear(sumar(movimientos, (m) => m.monto), 2)
  const costoCalculable = kilosTotales > 0 && gastosTotales > 0
  const costo = costoCalculable ? redondear(gastosTotales / kilosTotales, 0) : null

  const lugaresTotales = agrupar(registrosExternos, (r) => r.lugar)
  const lugaresCriticos = agrupar(criticasExternas, (r) => r.lugar)
  const lugares = Object.entries(lugaresTotales)
    .map(([etiqueta, valor]) => ({ etiqueta, valor, extra: lugaresCriticos[etiqueta] || 0 }))
    .sort((a, b) => b.valor - a.valor || a.etiqueta.localeCompare(b.etiqueta))
  const porFranja = agrupar(registros, (r) => franjaDe(r.hora))
  const franjas = FRANJAS.map((etiqueta) => ({ etiqueta, valor: porFranja[etiqueta] || 0 }))

  const kpis = [
    {
      id: 'reduccion',
      titulo: 'Reducción de acumulaciones externas críticas',
      resultado: reduccionCalculable ? `${reduccion.toLocaleString('es-AR')} %` : '—',
      meta: '30 % o más',
      estado: estadoKpi(reduccionCalculable, reduccion >= 30),
      calculo: reduccionCalculable
        ? `De ${primera} en la semana 1 a ${ultima} en la semana ${semanas.length}`
        : semanas.length < 2
          ? 'Se necesitan al menos dos semanas completas.'
          : 'La primera semana no tuvo críticas; no hay base de comparación.'
    },
    {
      id: 'kilos',
      titulo: 'Kilos de reciclables recuperados en la última semana',
      resultado: kilosCalculable ? `${kilosUltima.toLocaleString('es-AR')} kg` : '—',
      meta: '55 kg o más',
      estado: estadoKpi(kilosCalculable, kilosUltima >= 55),
      calculo: kilosCalculable
        ? `Semana ${formatoFechaCorta(semanas.at(-1).desde)} al ${formatoFechaCorta(semanas.at(-1).hasta)}`
        : 'No hay pesajes en una semana completa.'
    },
    {
      id: 'costo',
      titulo: 'Costo de insumos por kilo recuperado',
      resultado: costoCalculable ? `$ ${costo.toLocaleString('es-AR')} por kg` : '—',
      meta: '$ 300 o menos',
      estado: estadoKpi(costoCalculable, costo <= 300),
      calculo: costoCalculable
        ? `$ ${gastosTotales.toLocaleString('es-AR')} ÷ ${kilosTotales.toLocaleString('es-AR')} kg`
        : kilosTotales <= 0 ? 'No hay kilos para calcular el costo.' : 'No hay gastos cargados en el período.'
    },
    {
      id: 'recorridos',
      titulo: 'Cumplimiento de recorridos de control',
      resultado: '—',
      meta: '90 % o más',
      estado: 'no_calculable',
      calculo: 'El sistema todavía no registra recorridos planificados y realizados.'
    }
  ]

  const resultadosSemana = semanas.map((semana, i) => ({
    numero: i + 1,
    desde: semana.desde,
    hasta: semana.hasta,
    externas: externasAgrupadas[semana.desde] || 0,
    criticas: criticasAgrupadas[semana.desde] || 0,
    kilos: redondear(kilosAgrupados[semana.desde] || 0, 2),
    gastos: redondear(gastosAgrupados[semana.desde] || 0, 2)
  }))

  return {
    desde,
    hasta,
    kpis,
    criticasSemana,
    kilosSemana,
    lugares,
    franjas,
    resultadosSemana,
    totales: {
      registros: registros.length,
      externos: registrosExternos.length,
      criticas: criticasExternas.length,
      pesajes: reciclables.length,
      kilos: kilosTotales,
      gastos: gastosTotales,
      movimientos: movimientos.length
    },
    hayDatos: registros.length > 0 || reciclables.length > 0,
    hayPrueba: [...registros, ...reciclables, ...movimientos].some((x) => x.datos_prueba)
  }
}
