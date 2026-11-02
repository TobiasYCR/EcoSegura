<script setup>
import { reactive, ref, onMounted, watch, computed } from 'vue'
import { useOperacion } from '@/composables/useOperacion'
import { calcularEstadisticas } from '@/services/estadisticas'
import { listarLugares } from '@/services/lugares'
import { hoyISO, sumarDias, formatoFechaCorta, formatoKilos } from '@/utils/fechas'
import { TIPOS_RESIDUO } from '@/utils/catalogos'
import { reglas } from '@/utils/validaciones'
import Cargando from '@/components/common/Cargando.vue'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'
import AvisoPrueba from '@/components/common/AvisoPrueba.vue'
import GraficoColumnas from '@/components/common/GraficoColumnas.vue'
import GraficoBarras from '@/components/common/GraficoBarras.vue'

const { cargando, error, ejecutar, limpiar } = useOperacion()
const lugares = ref([])
const est = ref(null)
const filtros = reactive({ desde: sumarDias(hoyISO(), -29), hasta: hoyISO(), tipo: '', lugarId: '' })
const errorPeriodo = computed(() => {
  if (!filtros.desde || !filtros.hasta) return 'Elegí las dos fechas del período.'
  if (filtros.desde > filtros.hasta) return 'La fecha "desde" debe ser anterior a "hasta".'
  return reglas.noFutura(filtros.hasta)
})
const pctCriticas = computed(() => (est.value?.total ? Math.round((est.value.criticas / est.value.total) * 100) : 0))
const hayPrueba = computed(() => est.value?.registros.some((r) => r.datos_prueba) || est.value?.reciclables.some((r) => r.datos_prueba))
const franjaCritica = computed(() => {
  if (!est.value?.total) return null
  return est.value.franjas.reduce((a, b) => (b.valor > a.valor ? b : a))
})

async function cargar() {
  if (errorPeriodo.value) return
  await ejecutar(async () => (est.value = await calcularEstadisticas(filtros)))
}
onMounted(async () => {
  lugares.value = await listarLugares({ soloActivos: false }).catch(() => [])
  await cargar()
})
watch(filtros, cargar)
</script>

<template>
  <div>
    <div class="encabezado-pagina">
      <div>
        <h1>Estadísticas</h1>
        <p>Acumulaciones de residuos y reciclaje del período elegido.</p>
      </div>
    </div>

    <div class="panel">
      <div class="filtros" style="grid-template-columns: repeat(4, minmax(0, 1fr))">
        <label>Desde <input v-model="filtros.desde" type="date" :max="hoyISO()" /></label>
        <label>Hasta <input v-model="filtros.hasta" type="date" :max="hoyISO()" /></label>
        <label>Tipo
          <select v-model="filtros.tipo">
            <option value="">Todos</option>
            <option v-for="(t, v) in TIPOS_RESIDUO" :key="v" :value="v">{{ t }}</option>
          </select>
        </label>
        <label>Lugar
          <select v-model="filtros.lugarId">
            <option value="">Todos</option>
            <option v-for="l in lugares" :key="l.id" :value="l.id">{{ l.nombre }}</option>
          </select>
        </label>
      </div>
      <div v-if="errorPeriodo" class="aviso error" style="margin: 0">{{ errorPeriodo }}</div>
    </div>

    <AvisoOperacion :error="error" @cerrar="limpiar" />
    <Cargando v-if="cargando" texto="Calculando estadísticas..." />

    <template v-else-if="est">
      <AvisoPrueba :visible="hayPrueba" />
      <div class="tarjetas">
        <div class="tarjeta"><div class="numero">{{ est.total }}</div><div class="detalle">acumulaciones registradas</div></div>
        <div class="tarjeta destacada"><div class="numero">{{ est.criticas }}</div><div class="detalle">críticas (3 o más bolsas) · {{ pctCriticas }} %</div></div>
        <div class="tarjeta"><div class="numero">{{ est.externos }}</div><div class="detalle">externas (le tocan al municipio)</div></div>
        <div class="tarjeta"><div class="numero">{{ est.bolsas }}</div><div class="detalle">bolsas contadas</div></div>
        <div class="tarjeta"><div class="numero">{{ formatoKilos(est.kilos) }}</div><div class="detalle">reciclables recuperados</div></div>
      </div>

      <div class="columnas">
        <section class="panel">
          <h2>Acumulaciones por franja horaria</h2>
          <GraficoColumnas :datos="est.franjas" />
          <p v-if="franjaCritica" class="leyenda">
            <span><i style="background: var(--rojo)"></i>Franja más crítica: {{ franjaCritica.etiqueta }}</span>
          </p>
        </section>
        <section class="panel">
          <h2>Acumulaciones por lugar</h2>
          <p v-if="!est.lugares.length" class="vacio">Sin datos.</p>
          <GraficoBarras v-else :datos="est.lugares" etiqueta-extra="Críticas" />
        </section>
        <section class="panel">
          <h2>Acumulaciones por día de la semana</h2>
          <GraficoColumnas :datos="est.dias" />
        </section>
        <section class="panel">
          <h2>Kilos recuperados por material</h2>
          <GraficoColumnas :datos="est.materiales" unidad=" kg" />
        </section>
      </div>
      <section class="panel">
        <h2>Kilos recuperados por semana</h2>
        <p v-if="!est.semanas.length" class="vacio">Sin pesajes en el período.</p>
        <GraficoColumnas v-else :datos="est.semanas.map((s) => ({ etiqueta: 'Sem. ' + formatoFechaCorta(s.etiqueta), valor: s.valor }))" unidad=" kg" />
      </section>
    </template>
  </div>
</template>
