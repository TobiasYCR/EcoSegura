import { listarRegistros } from './registros'
import { listarReciclables } from './reciclables'
import { DIAS, FRANJAS, franjaDe, MATERIALES } from '@/utils/catalogos'
import { inicioSemana } from '@/utils/fechas'

function agrupar(lista, clave, valor = () => 1) {
  const m = {}
  for (const x of lista) {
    const k = clave(x)
    m[k] = (m[k] || 0) + valor(x)
  }
  return m
}

// Datos de los gráficos a partir de los registros del período
export async function calcularEstadisticas({ desde, hasta, tipo = '', lugarId = '' }) {
  const [{ data: registros }, reciclables] = await Promise.all([
    listarRegistros({ desde, hasta, tipo, lugarId, estado: 'activos', limite: 5000 }),
    listarReciclables({ desde, hasta })
  ])

  const porFranja = agrupar(registros, (r) => franjaDe(r.hora))
  const porLugar = agrupar(registros, (r) => r.lugar)
  const porDia = agrupar(registros, (r) => r.dia_semana)
  const criticasPorLugar = agrupar(registros.filter((r) => r.critica), (r) => r.lugar)
  const kilosMaterial = agrupar(reciclables, (r) => r.material, (r) => Number(r.kilos))
  const kilosSemana = agrupar(reciclables, (r) => inicioSemana(r.fecha), (r) => Number(r.kilos))
  const criticasSemana = agrupar(
    registros.filter((r) => r.tipo === 'externo' && r.critica),
    (r) => inicioSemana(r.fecha)
  )

  return {
    total: registros.length,
    criticas: registros.filter((r) => r.critica).length,
    externos: registros.filter((r) => r.tipo === 'externo').length,
    bolsas: registros.reduce((s, r) => s + r.cantidad_bolsas, 0),
    kilos: reciclables.reduce((s, r) => s + Number(r.kilos), 0),
    franjas: FRANJAS.map((f) => ({ etiqueta: f, valor: porFranja[f] || 0 })),
    lugares: Object.entries(porLugar)
      .map(([etiqueta, valor]) => ({ etiqueta, valor, extra: criticasPorLugar[etiqueta] || 0 }))
      .sort((a, b) => b.valor - a.valor),
    dias: [1, 2, 3, 4, 5].map((d) => ({ etiqueta: DIAS[d], valor: porDia[d] || 0 })),
    materiales: Object.keys(MATERIALES).map((m) => ({
      etiqueta: MATERIALES[m], valor: Math.round((kilosMaterial[m] || 0) * 100) / 100
    })),
    semanas: Object.keys(kilosSemana).sort().map((s) => ({
      etiqueta: s, valor: Math.round(kilosSemana[s] * 100) / 100
    })),
    criticasSemana: Object.keys(criticasSemana).sort().map((s) => ({
      etiqueta: s, valor: criticasSemana[s]
    })),
    registros,
    reciclables
  }
}
