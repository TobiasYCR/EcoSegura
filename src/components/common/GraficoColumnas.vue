<script setup>
import { computed } from 'vue'

// Columnas verticales; la mayor se marca en rojo (horario más crítico).
const props = defineProps({
  datos: { type: Array, required: true },
  unidad: { type: String, default: '' }
})
const numero = (v) => Number(v).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const maximo = computed(() => Math.max(1, ...props.datos.map((d) => d.valor)))
const indiceMax = computed(() => {
  const m = Math.max(...props.datos.map((d) => d.valor))
  return m > 0 ? props.datos.findIndex((d) => d.valor === m) : -1
})
</script>

<template>
  <div>
    <div class="grafico" role="img" :aria-label="datos.map((d) => `${d.etiqueta}: ${numero(d.valor)}${unidad}`).join(', ')">
      <div v-for="(d, i) in datos" :key="d.etiqueta" class="columna">
        <span class="valor">{{ numero(d.valor) }}{{ unidad }}</span>
        <div class="barra" :class="{ maxima: i === indiceMax }" :style="{ height: (d.valor / maximo) * 85 + '%' }"></div>
      </div>
    </div>
    <div class="grafico-etiquetas">
      <span v-for="d in datos" :key="d.etiqueta" :title="d.etiqueta">{{ d.etiqueta }}</span>
    </div>
  </div>
</template>
