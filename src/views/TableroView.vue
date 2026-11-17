<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue'
import { cargarIndicadores } from '@/services/indicadores'
import { listarLugares } from '@/services/lugares'
import { useOperacion } from '@/composables/useOperacion'
import { formatoFecha, hoyISO, rangoUltimasSemanas } from '@/utils/fechas'
import { reglas } from '@/utils/validaciones'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'
import AvisoPrueba from '@/components/common/AvisoPrueba.vue'
import Cargando from '@/components/common/Cargando.vue'
import GraficoBarras from '@/components/common/GraficoBarras.vue'
import GraficoColumnas from '@/components/common/GraficoColumnas.vue'
import GraficoLinea from '@/components/common/GraficoLinea.vue'
import TarjetaKpi from '@/components/common/TarjetaKpi.vue'

const operacion = useOperacion()
const lugares = ref([])
const datos = ref(null)
const actualizado = ref(null)
const filtros = reactive({ preset: '4', ...rangoUltimasSemanas(4), lugarId: '' })
let temporizador = null
let montado = false

const errorPeriodo = computed(() => {
  if (!filtros.desde || !filtros.hasta) return 'Elegí las dos fechas del período.'
  if (filtros.desde > filtros.hasta) return 'La fecha "desde" debe ser anterior a "hasta".'
  return reglas.noFutura(filtros.hasta)
})
const lugarElegido = computed(() => lugares.value.find((l) => String(l.id) === String(filtros.lugarId)))
const periodo = computed(() => `${formatoFecha(filtros.desde)} al ${formatoFecha(filtros.hasta)}`)
const textoActualizado = computed(() => actualizado.value
  ? new Intl.DateTimeFormat('es-AR', { dateStyle: 'short', timeStyle: 'short' }).format(actualizado.value)
  : '')

function aplicarPreset() {
  if (filtros.preset === 'custom') return
  Object.assign(filtros, rangoUltimasSemanas(Number(filtros.preset)))
}

async function cargar() {
  if (errorPeriodo.value) return
  await operacion.ejecutar(async () => {
    datos.value = await cargarIndicadores(filtros)
    actualizado.value = new Date()
  })
}

function programarCarga() {
  if (!montado) return
  clearTimeout(temporizador)
  temporizador = setTimeout(cargar, 180)
}

onMounted(async () => {
  await operacion.ejecutar(async () => {
    lugares.value = await listarLugares({ soloActivos: false })
    datos.value = await cargarIndicadores(filtros)
    actualizado.value = new Date()
  })
  montado = true
})
onBeforeUnmount(() => clearTimeout(temporizador))
watch(() => filtros.preset, () => { aplicarPreset(); programarCarga() })
watch(() => [filtros.desde, filtros.hasta, filtros.lugarId], programarCarga)
</script>

<template>
  <div>
    <div class="encabezado-pagina">
      <div>
        <h1>Tablero del piloto</h1>
        <p>
          Indicadores del relevamiento y del punto verde · {{ periodo }}
          <template v-if="lugarElegido"> · {{ lugarElegido.nombre }}</template>
        </p>
      </div>
      <div class="acciones no-imprimir">
        <span v-if="textoActualizado" class="texto-actualizacion">Actualizado: {{ textoActualizado }}</span>
        <button class="btn" :disabled="operacion.cargando.value || !!errorPeriodo" @click="cargar">Actualizar</button>
        <RouterLink :to="{ path: '/seguimiento', query: { desde: filtros.desde, hasta: filtros.hasta } }" class="btn btn-primario">
          Informe de seguimiento
        </RouterLink>
      </div>
    </div>

    <section class="panel no-imprimir">
      <div class="filtros filtros-tablero">
        <label>Período
          <select v-model="filtros.preset">
            <option value="4">Últimas 4 semanas</option>
            <option value="2">Últimas 2 semanas</option>
            <option value="1">Última semana</option>
            <option value="custom">Otro período</option>
          </select>
        </label>
        <label>Desde
          <input v-model="filtros.desde" type="date" :max="hoyISO()" @change="filtros.preset = 'custom'" />
        </label>
        <label>Hasta
          <input v-model="filtros.hasta" type="date" :max="hoyISO()" @change="filtros.preset = 'custom'" />
        </label>
        <label>Lugar
          <select v-model="filtros.lugarId">
            <option value="">Todos</option>
            <option v-for="l in lugares" :key="l.id" :value="l.id">{{ l.nombre }}</option>
          </select>
        </label>
      </div>
      <p class="ayuda-filtros">El lugar filtra las acumulaciones; los kilos y los gastos del punto verde no dependen del lugar.</p>
      <div v-if="errorPeriodo" class="aviso error" style="margin: 10px 0 0">{{ errorPeriodo }}</div>
    </section>

    <template v-if="operacion.error.value">
      <AvisoOperacion :error="`No se pudo cargar el tablero. ${operacion.error.value}`" @cerrar="operacion.limpiar" />
      <button class="btn btn-chico" style="margin: -6px 0 14px" @click="cargar">Reintentar</button>
    </template>
    <Cargando v-if="operacion.cargando.value && !datos" texto="Calculando indicadores..." />

    <template v-else-if="datos">
      <AvisoPrueba :visible="datos.hayPrueba" />
      <div v-if="!datos.hayDatos" class="panel vacio">
        No hay registros ni pesajes en el período elegido.
      </div>
      <template v-else>
        <section class="kpis" :class="{ recalculando: operacion.cargando.value }">
          <TarjetaKpi v-for="kpi in datos.kpis" :key="kpi.id" :kpi="kpi" />
        </section>

        <div class="columnas graficos-tablero" :class="{ recalculando: operacion.cargando.value }">
          <section class="panel">
            <h2>¿Bajan las acumulaciones críticas fuera de la escuela?</h2>
            <p class="meta-grafico">Acumulaciones externas críticas (3 o más bolsas) por semana · {{ periodo }} · Total: {{ datos.totales.criticas }}</p>
            <GraficoLinea :datos="datos.criticasSemana" />
            <div class="leyenda"><span><i style="background: var(--rojo)"></i>Críticas externas</span></div>
          </section>
          <section class="panel">
            <h2>¿Dónde se concentran?</h2>
            <p class="meta-grafico">Acumulaciones externas por lugar · {{ periodo }} · Total: {{ datos.totales.externos }}</p>
            <p v-if="!datos.lugares.length" class="vacio">Sin acumulaciones externas.</p>
            <GraficoBarras v-else :datos="datos.lugares" etiqueta-extra="Críticas (3 o más bolsas)" />
          </section>
          <section class="panel">
            <h2>¿Se llega a la meta de reciclables?</h2>
            <p class="meta-grafico">Kilos recuperados en el punto verde por semana · {{ periodo }} · Total: {{ datos.totales.kilos.toLocaleString('es-AR') }} kg</p>
            <GraficoLinea :datos="datos.kilosSemana" unidad=" kg" :meta="55" color="var(--verde)" />
            <div class="leyenda"><span><i style="background: var(--verde)"></i>Kilos por semana</span><span>Línea punteada: meta semanal</span></div>
          </section>
          <section class="panel">
            <h2>¿En qué horario aparecen?</h2>
            <p class="meta-grafico">Acumulaciones por franja horaria · {{ periodo }} · Total: {{ datos.totales.registros }}</p>
            <GraficoColumnas :datos="datos.franjas" />
            <div class="leyenda"><span><i style="background: var(--rojo)"></i>Franja con más acumulaciones</span><span><i style="background: #7b858f"></i>Resto</span></div>
          </section>
        </div>
      </template>
    </template>
  </div>
</template>
