<script setup>
defineProps({
  etiqueta: { type: String, required: true },
  error: { type: String, default: '' },
  requerido: { type: Boolean, default: false },
  ayuda: { type: String, default: '' },
  para: { type: String, default: '' }
})
</script>

<template>
  <div class="campo" :class="{ 'con-error': error }">
    <label :for="para">{{ etiqueta }} <span v-if="requerido" class="requerido">*</span></label>
    <slot />
    <span v-if="error" class="error-campo">{{ error }}</span>
    <span v-else-if="ayuda" class="ayuda">{{ ayuda }}</span>
  </div>
</template>
