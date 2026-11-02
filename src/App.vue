<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { configurado } from '@/lib/supabase'
import MenuLateral from '@/components/layout/MenuLateral.vue'
import BarraInferior from '@/components/layout/BarraInferior.vue'

const route = useRoute()
const { rol, nombreRol } = useAuth()
const conMenu = computed(() => !route.meta.publica && rol.value)
</script>

<template>
  <div class="app">
    <div v-if="!configurado" class="aviso error" style="margin: 0; border-radius: 0">
      Falta configurar Supabase: copiá <code>.env.example</code> como <code>.env</code> y completá la URL y la clave publicable.
    </div>
    <template v-if="conMenu">
      <MenuLateral />
      <header class="barra-movil">
        <strong>EcoSegura</strong>
        <span class="etiqueta">{{ nombreRol }}</span>
      </header>
    </template>
    <main :class="conMenu ? 'contenido' : route.meta.publica ? '' : 'contenido-solo'">
      <RouterView />
    </main>
    <BarraInferior v-if="conMenu" />
  </div>
</template>
