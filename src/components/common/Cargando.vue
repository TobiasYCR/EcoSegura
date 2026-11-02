<script setup>
defineProps({ texto: { type: String, default: 'Cargando...' } })
</script>

<template>
  <div class="cargando" role="status">{{ texto }}</div>
</template>
