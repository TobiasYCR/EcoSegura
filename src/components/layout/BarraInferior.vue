<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { menuPara } from '@/utils/menu'
import Icono from '@/components/common/Icono.vue'

// Celular: Inicio, Registros, Datos (estadísticas) e Informes/Más, como en el boceto.
const route = useRoute()
const router = useRouter()
const { rol, salir } = useAuth()
const abierto = ref(false)

const principales = computed(() => {
  const base = [
    { ruta: '/', texto: 'Inicio', icono: 'inicio' },
    { ruta: '/registros', texto: 'Registros', icono: 'lista' },
    { ruta: '/estadisticas', texto: 'Datos', icono: 'grafico' }
  ]
  if (['ambiental', 'administracion', 'tecnologia', 'docente'].includes(rol.value)) {
    base.push({ ruta: '/informes', texto: 'Informes', icono: 'informe' })
  }
  return base
})
const resto = computed(() =>
  menuPara(rol.value).filter((m) => !principales.value.some((p) => p.ruta === m.ruta))
)

watch(() => route.fullPath, () => (abierto.value = false))

async function cerrarSesion() {
  await salir()
  router.push({ name: 'ingreso' })
}
</script>

<template>
  <nav class="barra-inferior" aria-label="Navegación">
    <RouterLink
      v-for="p in principales"
      :key="p.ruta"
      :to="p.ruta"
      :class="{ activo: p.ruta === '/' ? route.path === '/' : route.path.startsWith(p.ruta) }"
    >
      <Icono :nombre="p.icono" />{{ p.texto }}
    </RouterLink>
    <button type="button" :class="{ activo: abierto }" aria-label="Más opciones" @click="abierto = !abierto">
      <Icono nombre="menu" />Más
    </button>
  </nav>
  <template v-if="abierto">
    <div class="fondo-menu" @click="abierto = false"></div>
    <div class="menu-mas">
      <RouterLink v-for="m in resto" :key="m.ruta" :to="m.ruta">{{ m.texto }}</RouterLink>
      <RouterLink to="/mi-cuenta">Mi cuenta</RouterLink>
      <button type="button" @click="cerrarSesion">Cerrar sesión</button>
    </div>
  </template>
</template>
