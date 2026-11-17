<script setup>
import { computed } from 'vue'

const props = defineProps({ kpi: { type: Object, required: true } })
const etiquetas = {
  cumplida: 'Meta cumplida',
  no_cumplida: 'Meta no cumplida',
  no_calculable: 'No se puede calcular'
}
const etiquetaEstado = computed(() => etiquetas[props.kpi.estado] || props.kpi.estado)
</script>

<template>
  <article class="tarjeta-kpi" :class="`estado-${kpi.estado}`">
    <h2>{{ kpi.titulo }}</h2>
    <div class="resultado-kpi">{{ kpi.resultado }}</div>
    <p class="calculo-kpi">{{ kpi.calculo }}</p>
    <div class="pie-kpi">
      <span>Meta: {{ kpi.meta }}</span>
      <span class="etiqueta" :class="{
        verde: kpi.estado === 'cumplida',
        roja: kpi.estado === 'no_cumplida'
      }">{{ etiquetaEstado }}</span>
    </div>
  </article>
</template>
