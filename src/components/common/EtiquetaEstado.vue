<script setup>
import { computed } from 'vue'
import { ESTADOS_REGISTRO, ESTADOS_INFORME } from '@/utils/catalogos'

const props = defineProps({ estado: { type: String, required: true } })
const colores = {
  pendiente: 'ambar', revisado: 'verde', anulado: '',
  borrador: '', en_revision: 'ambar', aprobado: 'azul', enviado: 'verde'
}
const texto = computed(() => ESTADOS_REGISTRO[props.estado] || ESTADOS_INFORME[props.estado] || props.estado)
</script>

<template>
  <span class="etiqueta" :class="colores[estado]">{{ texto }}</span>
</template>
