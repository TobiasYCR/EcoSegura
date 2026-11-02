<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { menuPara } from '@/utils/menu'
import Icono from '@/components/common/Icono.vue'

const router = useRouter()
const { rol, nombreRol, nombreCompleto, salir } = useAuth()
const items = computed(() => menuPara(rol.value))

async function cerrarSesion() {
  await salir()
  router.push({ name: 'ingreso' })
}
</script>

<template>
  <aside class="lateral">
    <div class="marca">
      <Icono nombre="hoja" />
      <div>EcoSegura<small>Cooperativa Escolar</small></div>
    </div>
    <nav aria-label="Menú principal">
      <RouterLink v-for="i in items" :key="i.ruta" :to="i.ruta">
        <Icono :nombre="i.icono" /> {{ i.texto }}
      </RouterLink>
    </nav>
    <div class="usuario">
      <strong>{{ nombreCompleto }}</strong>
      <span>Perfil: {{ nombreRol }}</span>
      <div class="acciones">
        <RouterLink to="/mi-cuenta" class="btn btn-chico">Mi cuenta</RouterLink>
        <button type="button" class="btn btn-chico" @click="cerrarSesion">Salir</button>
      </div>
    </div>
  </aside>
</template>
