<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useOperacion } from '@/composables/useOperacion'
import { cargarIndicadores } from '@/services/indicadores'
import { formatoFecha, formatoFechaCorta, formatoMoneda, hoyISO, rangoUltimasSemanas } from '@/utils/fechas'
import { reglas } from '@/utils/validaciones'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'
import Cargando from '@/components/common/Cargando.vue'
import GraficoBarras from '@/components/common/GraficoBarras.vue'
import GraficoColumnas from '@/components/common/GraficoColumnas.vue'
import GraficoLinea from '@/components/common/GraficoLinea.vue'

const route = useRoute()
const { nombreCompleto } = useAuth()
const operacion = useOperacion()
const inicial = rangoUltimasSemanas(4)
const filtros = reactive({
  desde: route.query.desde || inicial.desde,
  hasta: route.query.hasta || inicial.hasta
})
const datos = ref(null)
const consultado = ref(null)
const interpretacion = ref('')
const acciones = ref('')
let montado = false

const errorPeriodo = computed(() => {
  if (!filtros.desde || !filtros.hasta) return 'Elegí las dos fechas del período.'
  if (filtros.desde > filtros.hasta) return 'La fecha "desde" debe ser anterior a "hasta".'
  return reglas.noFutura(filtros.hasta)
})
const periodo = computed(() => `${formatoFecha(filtros.desde)} al ${formatoFecha(filtros.hasta)}`)
const claveLocal = computed(() => `ecosegura.seguimiento.${filtros.desde}.${filtros.hasta}`)
const listaAcciones = computed(() => acciones.value.split('\n').map((x) => x.trim()).filter(Boolean))
const estados = { cumplida: 'Meta cumplida', no_cumplida: 'Meta no cumplida', no_calculable: 'No calculable' }
const imprimir = () => window.print()
const lecturaAutomatica = computed(() => {
  if (!datos.value) return []
  const lectura = []
  const franja = [...datos.value.franjas].sort((a, b) => b.valor - a.valor)[0]
  const lugar = datos.value.lugares[0]
  if (franja?.valor) lectura.push(`La franja con más acumulaciones fue ${franja.etiqueta} (${franja.valor} de ${datos.value.totales.registros}).`)
  if (lugar?.extra) lectura.push(`El lugar con más críticas externas fue ${lugar.etiqueta} (${lugar.extra} de ${datos.value.totales.criticas}).`)
  const noCalculables = datos.value.kpis.filter((k) => k.estado === 'no_calculable').map((k) => k.titulo.toLowerCase())
  if (noCalculables.length) lectura.push(`Indicadores no calculables: ${noCalculables.join(', ')}.`)
  return lectura
})

function cargarTextoLocal() {
  try {
    const guardado = JSON.parse(localStorage.getItem(claveLocal.value) || '{}')
    interpretacion.value = guardado.interpretacion || ''
    acciones.value = guardado.acciones || ''
  } catch {
    interpretacion.value = ''
    acciones.value = ''
  }
}

function guardarTextoLocal() {
  if (!montado) return
  try {
    localStorage.setItem(claveLocal.value, JSON.stringify({ interpretacion: interpretacion.value, acciones: acciones.value }))
  } catch {
    /* El informe sigue funcionando aunque el navegador no permita almacenamiento. */
  }
}

async function cargar() {
  if (errorPeriodo.value) return
  cargarTextoLocal()
  await operacion.ejecutar(async () => {
    datos.value = await cargarIndicadores(filtros)
    consultado.value = new Date()
  })
}

onMounted(async () => {
  cargarTextoLocal()
  await cargar()
  montado = true
})
watch([interpretacion, acciones], guardarTextoLocal)
</script>

<template>
  <div>
    <div class="encabezado-pagina no-imprimir">
      <div>
        <h1>Informe de seguimiento</h1>
        <p>Cierre del piloto para el Consejo, la Comisión Ambiental y el docente asesor.</p>
      </div>
      <div class="acciones">
        <button class="btn" :disabled="operacion.cargando.value || !!errorPeriodo" @click="cargar">Actualizar</button>
        <button class="btn btn-primario" :disabled="!datos" @click="imprimir">Imprimir o guardar PDF</button>
      </div>
    </div>

    <section class="panel no-imprimir controles-seguimiento">
      <div class="form-grid dos">
        <label class="campo">Desde
          <input v-model="filtros.desde" type="date" :max="hoyISO()" />
        </label>
        <label class="campo">Hasta
          <input v-model="filtros.hasta" type="date" :max="hoyISO()" />
        </label>
        <label class="campo ancho">Interpretación acordada
          <textarea v-model="interpretacion" maxlength="4000" placeholder="Explicá qué metas se cumplieron, los patrones y las dificultades..."></textarea>
          <span class="ayuda">Se guarda en este navegador para el período elegido.</span>
        </label>
        <label class="campo ancho">Acciones de mejora
          <textarea v-model="acciones" maxlength="3000" placeholder="Una acción por línea..."></textarea>
          <span class="ayuda">Cada línea se imprime como un punto de la lista.</span>
        </label>
      </div>
      <div v-if="errorPeriodo" class="aviso error" style="margin: 12px 0 0">{{ errorPeriodo }}</div>
    </section>

    <AvisoOperacion :error="operacion.error.value" @cerrar="operacion.limpiar" />
    <Cargando v-if="operacion.cargando.value && !datos" texto="Armando el informe..." />

    <article v-else-if="datos" class="hoja-informe hoja-seguimiento">
      <header class="membrete">
        <div>
          <strong>EcoSegura · Cooperativa Escolar</strong>
          <div>Informe de seguimiento del piloto de relevamiento y reciclaje</div>
        </div>
        <div class="datos-emision">
          <div>Período: {{ periodo }}</div>
          <div>Emitido: {{ formatoFecha(hoyISO()) }}</div>
          <div>Preparó: {{ nombreCompleto || 'Administración y Consejo' }}</div>
        </div>
      </header>

      <div v-if="datos.hayPrueba" class="aviso prueba">Informe armado con datos de prueba: los valores son ficticios.</div>

      <section>
        <h2>Objetivo</h2>
        <p>Mostrar al Consejo de Administración, a la Comisión Ambiental y al docente asesor si el piloto avanza hacia sus metas: menos acumulaciones críticas fuera de la escuela, más reciclables recuperados y un costo razonable por kilo.</p>
      </section>

      <section>
        <h2>Fuente de los datos</h2>
        <p>
          Base de datos de EcoSegura (Supabase): {{ datos.totales.registros }} registros de residuos no anulados,
          {{ datos.totales.pesajes }} pesajes del punto verde y {{ datos.totales.movimientos }} gastos no anulados.
          Consulta realizada {{ consultado ? new Intl.DateTimeFormat('es-AR', { dateStyle: 'short', timeStyle: 'short' }).format(consultado) : '' }}.
        </p>
      </section>

      <section>
        <h2>Indicadores</h2>
        <p>Se cumplieron {{ datos.kpis.filter((k) => k.estado === 'cumplida').length }} de {{ datos.kpis.filter((k) => k.estado !== 'no_calculable').length }} metas que se pudieron calcular.</p>
        <div class="tabla-contenedor">
          <table class="tabla tabla-informe">
            <thead><tr><th>Indicador</th><th>Meta</th><th>Resultado</th><th>Estado</th><th>Cálculo o motivo</th></tr></thead>
            <tbody>
              <tr v-for="kpi in datos.kpis" :key="kpi.id">
                <td data-label="Indicador">{{ kpi.titulo }}</td>
                <td data-label="Meta">{{ kpi.meta }}</td>
                <td data-label="Resultado"><strong>{{ kpi.resultado }}</strong></td>
                <td data-label="Estado"><span class="etiqueta" :class="{ verde: kpi.estado === 'cumplida', roja: kpi.estado === 'no_cumplida' }">{{ estados[kpi.estado] }}</span></td>
                <td data-label="Cálculo o motivo">{{ kpi.calculo }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2>Resultados por semana</h2>
        <div class="tabla-contenedor">
          <table class="tabla tabla-informe">
            <thead><tr><th>Semana</th><th>Fechas</th><th class="num">Acumulaciones externas</th><th class="num">Críticas externas</th><th class="num">Kilos</th><th class="num">Gastos</th></tr></thead>
            <tbody>
              <tr v-for="s in datos.resultadosSemana" :key="s.desde">
                <td data-label="Semana">{{ s.numero }}</td><td data-label="Fechas">{{ formatoFechaCorta(s.desde) }} al {{ formatoFechaCorta(s.hasta) }}</td>
                <td data-label="Acumulaciones externas" class="num">{{ s.externas }}</td><td data-label="Críticas externas" class="num">{{ s.criticas }}</td>
                <td data-label="Kilos" class="num">{{ s.kilos.toLocaleString('es-AR') }} kg</td><td data-label="Gastos" class="num">{{ formatoMoneda(s.gastos) }}</td>
              </tr>
              <tr class="total"><td colspan="2">Total del período</td><td data-label="Acumulaciones externas" class="num">{{ datos.totales.externos }}</td><td data-label="Críticas externas" class="num">{{ datos.totales.criticas }}</td><td data-label="Kilos" class="num">{{ datos.totales.kilos.toLocaleString('es-AR') }} kg</td><td data-label="Gastos" class="num">{{ formatoMoneda(datos.totales.gastos) }}</td></tr>
            </tbody>
          </table>
        </div>
      </section>

      <section class="graficos-informe">
        <div>
          <h3>Acumulaciones externas críticas por semana</h3>
          <GraficoLinea :datos="datos.criticasSemana" />
        </div>
        <div>
          <h3>Kilos recuperados por semana</h3>
          <GraficoLinea :datos="datos.kilosSemana" unidad=" kg" :meta="55" color="var(--verde)" />
        </div>
        <div>
          <h3>Acumulaciones externas por lugar (total: {{ datos.totales.externos }})</h3>
          <GraficoBarras :datos="datos.lugares" etiqueta-extra="Críticas" />
        </div>
        <div>
          <h3>Acumulaciones por franja horaria (total: {{ datos.totales.registros }})</h3>
          <GraficoColumnas :datos="datos.franjas" />
        </div>
      </section>

      <section>
        <h2>Lectura de los datos</h2>
        <ul><li v-for="item in lecturaAutomatica" :key="item">{{ item }}</li></ul>
      </section>
      <section>
        <h2>Interpretación</h2>
        <p class="texto-multilinea">{{ interpretacion || 'Sin interpretación cargada para este período.' }}</p>
      </section>
      <section>
        <h2>Acciones de mejora</h2>
        <ol v-if="listaAcciones.length"><li v-for="item in listaAcciones" :key="item">{{ item }}</li></ol>
        <p v-else>Sin acciones cargadas para este período.</p>
      </section>
      <footer class="pie-informe">Destinatarios: Consejo de Administración, Comisión Ambiental y docente asesor. Consulta habilitada para Ambiental, Administración y Consejo, Tecnología y Docente asesor.</footer>
    </article>
  </div>
</template>
