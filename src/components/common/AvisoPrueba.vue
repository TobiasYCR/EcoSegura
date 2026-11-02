<script setup>
defineProps({ visible: { type: Boolean, default: false } })
</script>

<template>
  <div v-if="visible" class="aviso prueba">
    Este listado incluye <strong>datos de prueba</strong>: son ficticios y se cargaron con
    <code>seed.sql</code> para probar el sistema. Están marcados con la etiqueta DATOS DE PRUEBA.
  </div>
</template>
