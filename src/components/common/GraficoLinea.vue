<script setup>
import { computed } from 'vue'

const props = defineProps({
  datos: { type: Array, required: true },
  unidad: { type: String, default: '' },
  meta: { type: Number, default: null },
  color: { type: String, default: 'var(--rojo)' }
})

const ancho = 560
const alto = 230
const margen = { izquierda: 42, derecha: 18, arriba: 24, abajo: 38 }
const numero = (v) => Number(v).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const maximo = computed(() => Math.max(1, props.meta || 0, ...props.datos.map((d) => Number(d.valor))) * 1.12)
const x = (i) => props.datos.length <= 1
  ? ancho / 2
  : margen.izquierda + (i * (ancho - margen.izquierda - margen.derecha)) / (props.datos.length - 1)
const y = (valor) => margen.arriba + (1 - Number(valor) / maximo.value) * (alto - margen.arriba - margen.abajo)
const puntos = computed(() => props.datos.map((d, i) => `${x(i)},${y(d.valor)}`).join(' '))
const descripcion = computed(() => props.datos.map((d) => `${d.etiqueta}: ${numero(d.valor)}${props.unidad}`).join(', '))
</script>

<template>
  <div class="grafico-linea" role="img" :aria-label="descripcion">
    <svg :viewBox="`0 0 ${ancho} ${alto}`" preserveAspectRatio="xMidYMid meet">
      <line :x1="margen.izquierda" :x2="ancho - margen.derecha" :y1="alto - margen.abajo" :y2="alto - margen.abajo" class="eje" />
      <line :x1="margen.izquierda" :x2="ancho - margen.derecha" :y1="margen.arriba" :y2="margen.arriba" class="guia" />
      <text :x="margen.izquierda - 8" :y="alto - margen.abajo + 4" text-anchor="end" class="texto-eje">0</text>
      <text :x="margen.izquierda - 8" :y="margen.arriba + 4" text-anchor="end" class="texto-eje">{{ numero(maximo) }}</text>

      <g v-if="meta !== null">
        <line :x1="margen.izquierda" :x2="ancho - margen.derecha" :y1="y(meta)" :y2="y(meta)" class="linea-meta" />
        <text :x="ancho - margen.derecha" :y="y(meta) - 6" text-anchor="end" class="texto-meta">Meta: {{ numero(meta) }}{{ unidad }}</text>
      </g>

      <polyline v-if="datos.length > 1" :points="puntos" fill="none" :stroke="color" stroke-width="3" stroke-linejoin="round" />
      <g v-for="(d, i) in datos" :key="d.etiqueta">
        <circle :cx="x(i)" :cy="y(d.valor)" r="5" :fill="color" />
        <text :x="x(i)" :y="y(d.valor) - 10" text-anchor="middle" class="valor-linea">{{ numero(d.valor) }}</text>
        <text :x="x(i)" :y="alto - 12" text-anchor="middle" class="texto-eje">{{ d.etiqueta }}</text>
      </g>
    </svg>
  </div>
</template>
