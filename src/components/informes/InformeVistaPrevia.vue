<script setup>
import { ref, computed, onMounted } from 'vue'
import { calcularEstadisticas } from '@/services/estadisticas'
import { urlsFirmadas } from '@/services/archivos'
import { formatoFecha, formatoHora, formatoKilos } from '@/utils/fechas'
import { ESTADOS_INFORME } from '@/utils/catalogos'
import Cargando from '@/components/common/Cargando.vue'
import GraficoColumnas from '@/components/common/GraficoColumnas.vue'
import GraficoBarras from '@/components/common/GraficoBarras.vue'

// Vista previa del informe: se arma con los datos del período y se exporta
// a PDF con la impresión del navegador.
const props = defineProps({ informe: { type: Object, required: true } })

const est = ref(null)
const fotos = ref({})
const error = ref('')

const casosExternos = computed(() =>
  (est.value?.registros || []).filter((r) => r.tipo === 'externo' && r.critica).slice(0, 12)
)
const conFoto = computed(() => (props.informe.incluye_fotos ? casosExternos.value.filter((r) => fotos.value[r.foto_path]) : []))
const sinFoto = computed(() => casosExternos.value.filter((r) => !conFoto.value.includes(r)))
const franjaCritica = computed(() =>
  est.value?.total ? est.value.franjas.reduce((a, b) => (b.valor > a.valor ? b : a)) : null
)
const lugarCritico = computed(() => est.value?.lugares[0] || null)

onMounted(async () => {
  try {
    est.value = await calcularEstadisticas({ desde: props.informe.periodo_desde, hasta: props.informe.periodo_hasta })
    if (props.informe.incluye_fotos) {
      fotos.value = await urlsFirmadas('fotos', casosExternos.value.map((r) => r.foto_path))
    }
  } catch (e) {
    error.value = e.message
  }
})
</script>

<template>
  <Cargando v-if="!est && !error" texto="Armando la vista previa..." />
  <div v-else-if="error" class="aviso error">No se pudo armar la vista previa: {{ error }}</div>
  <article v-else class="hoja-informe">
    <div class="membrete">
      <div>
        <strong>EcoSegura · Cooperativa Escolar</strong>
        <div style="color: var(--gris-500); font-size: 0.85rem">Informe a la oficina de ambiente y limpieza del municipio</div>
      </div>
      <div style="text-align: right; font-size: 0.85rem">
        Período: {{ formatoFecha(informe.periodo_desde) }} al {{ formatoFecha(informe.periodo_hasta) }}<br />
        Estado: {{ ESTADOS_INFORME[informe.estado] }}
        <template v-if="informe.fecha_envio"><br />Enviado: {{ formatoFecha(informe.fecha_envio) }}</template>
      </div>
    </div>
    <div v-if="informe.datos_prueba" class="aviso prueba">Informe armado con <strong>datos de prueba</strong>.</div>

    <h1>{{ informe.titulo }}</h1>
    <p v-if="informe.introduccion">{{ informe.introduccion }}</p>

    <h2>Resumen</h2>
    <ul>
      <li>Se registraron <strong>{{ est.total }}</strong> acumulaciones de residuos; <strong>{{ est.externos }}</strong> fuera de la escuela.</li>
      <li><strong>{{ est.criticas }}</strong> fueron críticas (3 o más bolsas), con un total de {{ est.bolsas }} bolsas contadas.</li>
      <li v-if="franjaCritica">La franja horaria con más acumulaciones fue la de las <strong>{{ franjaCritica.etiqueta }}</strong>.</li>
      <li v-if="lugarCritico">El punto más afectado fue <strong>{{ lugarCritico.etiqueta }}</strong> ({{ lugarCritico.valor }} registros, {{ lugarCritico.extra }} críticos).</li>
      <li>En el punto verde se recuperaron <strong>{{ formatoKilos(est.kilos) }}</strong> de reciclables.</li>
    </ul>

    <h2>Acumulaciones por franja horaria</h2>
    <GraficoColumnas :datos="est.franjas" />

    <h2>Acumulaciones por lugar</h2>
    <GraficoBarras :datos="est.lugares" etiqueta-extra="Críticas" />

    <h2>Casos críticos fuera de la escuela</h2>
    <p v-if="!casosExternos.length">No hubo casos críticos externos en el período.</p>
    <div v-if="conFoto.length" class="fotos" style="margin-bottom: 12px">
      <figure v-for="r in conFoto" :key="r.id">
        <img :src="fotos[r.foto_path]" alt="" />
        <figcaption>{{ r.lugar }} · {{ formatoFecha(r.fecha) }} {{ formatoHora(r.hora) }} · {{ r.cantidad_bolsas }} bolsas</figcaption>
      </figure>
    </div>
    <div v-if="sinFoto.length" class="tabla-contenedor">
      <table class="tabla">
        <thead><tr><th>Fecha</th><th>Hora</th><th>Lugar</th><th class="num">Bolsas</th><th>Descripción</th></tr></thead>
        <tbody>
          <tr v-for="r in sinFoto" :key="r.id">
            <td>{{ formatoFecha(r.fecha) }}</td><td>{{ formatoHora(r.hora) }}</td><td>{{ r.lugar }}</td>
            <td class="num">{{ r.cantidad_bolsas }}</td><td>{{ r.descripcion }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <h2>Reciclables recuperados</h2>
    <GraficoColumnas :datos="est.materiales" unidad=" kg" />

    <h2>Pedido</h2>
    <p>
      Con estos datos, la cooperativa solicita reforzar la recolección en los lugares y horarios indicados,
      en especial en {{ lugarCritico?.etiqueta || 'los puntos relevados' }}<template v-if="franjaCritica"> cerca de las {{ franjaCritica.etiqueta }}</template>.
    </p>
  </article>
</template>
