<script setup>
defineProps({
  exito: { type: String, default: '' },
  error: { type: String, default: '' }
})
const emit = defineEmits(['cerrar'])
</script>

<template>
  <div v-if="error" class="aviso error" role="alert">
    <button type="button" class="cerrar" aria-label="Cerrar" @click="emit('cerrar')">×</button>
    {{ error }}
  </div>
  <div v-else-if="exito" class="aviso exito" role="status">
    <button type="button" class="cerrar" aria-label="Cerrar" @click="emit('cerrar')">×</button>
    {{ exito }}
  </div>
</template>
