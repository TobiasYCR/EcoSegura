<script setup>
import { computed } from 'vue'

// Barras horizontales. "extra" se pinta en rojo dentro de la barra (p. ej. críticas).
const props = defineProps({
  datos: { type: Array, required: true },
  etiquetaExtra: { type: String, default: '' },
  etiquetaValor: { type: String, default: 'Total' }
})
const maximo = computed(() => Math.max(1, ...props.datos.map((d) => d.valor)))
</script>

<template>
  <div>
    <div class="barras-h">
      <div v-for="d in datos" :key="d.etiqueta" class="fila">
        <span>{{ d.etiqueta }}</span>
        <div class="pista">
          <div v-if="d.extra" class="relleno critico" :style="{ width: (d.extra / maximo) * 100 + '%' }"></div>
          <div class="relleno" :style="{ width: ((d.valor - (d.extra || 0)) / maximo) * 100 + '%' }"></div>
        </div>
        <strong class="num">{{ d.valor }}</strong>
      </div>
    </div>
    <div v-if="etiquetaExtra" class="leyenda">
      <span><i style="background: var(--rojo)"></i>{{ etiquetaExtra }}</span>
      <span><i style="background: #7b858f"></i>Resto</span>
    </div>
  </div>
</template>
