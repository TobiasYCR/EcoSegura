<script setup>
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'

const router = useRouter()
const { perfil, salir, cargarPerfil, rol } = useAuth()

async function actualizar() {
  await cargarPerfil()
  if (rol.value) router.push('/')
}
async function cerrar() {
  await salir()
  router.push({ name: 'ingreso' })
}
</script>

<template>
  <div class="panel" style="max-width: 560px; margin: 40px auto">
    <h1>Tu cuenta todavía no tiene acceso</h1>
    <p v-if="perfil && !perfil.activo">La cuenta <strong>{{ perfil.email }}</strong> está desactivada.</p>
    <p v-else>
      La cuenta <strong>{{ perfil?.email }}</strong> existe, pero la Comisión de Tecnología todavía no le asignó un perfil.
    </p>
    <p>Pedile a Tecnología que te asigne el perfil que corresponde a tu comisión.</p>
    <div class="acciones">
      <button class="btn btn-primario" type="button" @click="actualizar">Volver a comprobar</button>
      <RouterLink class="btn" to="/mi-cuenta">Mi cuenta</RouterLink>
      <button class="btn" type="button" @click="cerrar">Cerrar sesión</button>
    </div>
  </div>
</template>
