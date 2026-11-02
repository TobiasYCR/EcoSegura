<script setup>
import { reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useOperacion } from '@/composables/useOperacion'
import { reglas, validar } from '@/utils/validaciones'
import CampoForm from '@/components/common/CampoForm.vue'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'

const router = useRouter()
const route = useRoute()
const { ingresar, rol } = useAuth()
const { cargando, error, ejecutar, limpiar } = useOperacion()

const form = reactive({ email: '', clave: '' })
const errores = ref({})

async function enviar() {
  errores.value = validar(form, {
    email: [reglas.obligatorio, reglas.email],
    clave: [reglas.obligatorio]
  })
  if (Object.keys(errores.value).length) return
  const { ok } = await ejecutar(() => ingresar(form.email, form.clave))
  if (ok) router.push(rol.value ? route.query.volver || '/' : { name: 'sin-perfil' })
}
</script>

<template>
  <div class="ingreso">
    <div class="caja">
      <svg class="logo" viewBox="0 0 32 32" aria-hidden="true">
        <rect width="32" height="32" rx="8" fill="#b91c1c" />
        <path d="M9 21c0-7 5-11 14-12-1 9-5 14-12 14l-2 2-1-1 2-2c-.7-.3-1-.6-1-1z" fill="#fff" />
      </svg>
      <h1>EcoSegura</h1>
      <p class="subtitulo">Cooperativa Escolar</p>

      <AvisoOperacion :error="error" @cerrar="limpiar" />

      <form novalidate @submit.prevent="enviar">
        <CampoForm etiqueta="Usuario (email)" :error="errores.email" para="email">
          <input id="email" v-model="form.email" type="email" inputmode="email" autocomplete="username" placeholder="nombre.apellido@escuela.edu.ar" />
        </CampoForm>
        <CampoForm etiqueta="Contraseña" :error="errores.clave" para="clave">
          <input id="clave" v-model="form.clave" type="password" autocomplete="current-password" placeholder="••••••••" />
        </CampoForm>
        <button class="btn btn-primario btn-bloque" type="submit" :disabled="cargando">
          {{ cargando ? 'Ingresando...' : 'Ingresar' }}
        </button>
      </form>
      <p class="pie">¿Olvidaste tu clave? Pedile a Tecnología.</p>
    </div>
  </div>
</template>
