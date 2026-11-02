<script setup>
import { reactive, ref, onMounted } from 'vue'
import { useAuth } from '@/composables/useAuth'
import { useOperacion } from '@/composables/useOperacion'
import { actualizarMisDatos } from '@/services/perfiles'
import { reglas, validar } from '@/utils/validaciones'
import { COMISIONES } from '@/utils/catalogos'
import CampoForm from '@/components/common/CampoForm.vue'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'

const { perfil, nombreRol, cambiarClave, cargarPerfil } = useAuth()
const datosOp = useOperacion()
const claveOp = useOperacion()

const datos = reactive({ nombre: '', apellido: '' })
const clave = reactive({ nueva: '', repetir: '' })
const erroresDatos = ref({})
const erroresClave = ref({})

onMounted(() => {
  datos.nombre = perfil.value?.nombre || ''
  datos.apellido = perfil.value?.apellido || ''
})

async function guardarDatos() {
  erroresDatos.value = validar(datos, {
    nombre: [reglas.obligatorio, reglas.largo(2, 60)],
    apellido: [reglas.obligatorio, reglas.largo(2, 60)]
  })
  if (Object.keys(erroresDatos.value).length) return
  await datosOp.ejecutar(async () => {
    await actualizarMisDatos(datos.nombre, datos.apellido)
    await cargarPerfil()
  }, 'Datos actualizados.')
}

async function guardarClave() {
  erroresClave.value = validar(clave, {
    nueva: [reglas.obligatorio, reglas.largo(8, 72)],
    repetir: [reglas.obligatorio, (v, d) => (v !== d.nueva ? 'Las contraseñas no coinciden.' : '')]
  })
  if (Object.keys(erroresClave.value).length) return
  const { ok } = await claveOp.ejecutar(() => cambiarClave(clave.nueva), 'Contraseña cambiada.')
  if (ok) Object.assign(clave, { nueva: '', repetir: '' })
}
</script>

<template>
  <div>
    <div class="encabezado-pagina">
      <div>
        <h1>Mi cuenta</h1>
        <p>{{ perfil?.email }} · {{ nombreRol }}<template v-if="perfil?.comision"> · {{ COMISIONES[perfil.comision] }}</template></p>
      </div>
    </div>
    <div class="columnas">
      <form class="panel" novalidate @submit.prevent="guardarDatos">
        <h2>Mis datos</h2>
        <AvisoOperacion :exito="datosOp.exito.value" :error="datosOp.error.value" @cerrar="datosOp.limpiar" />
        <div class="form-grid dos">
          <CampoForm etiqueta="Nombre" requerido :error="erroresDatos.nombre" para="nombre">
            <input id="nombre" v-model="datos.nombre" maxlength="60" autocomplete="given-name" />
          </CampoForm>
          <CampoForm etiqueta="Apellido" requerido :error="erroresDatos.apellido" para="apellido">
            <input id="apellido" v-model="datos.apellido" maxlength="60" autocomplete="family-name" />
          </CampoForm>
        </div>
        <p class="ayuda" style="margin-top: 10px; color: var(--gris-500)">El perfil, la comisión y el curso los asigna Tecnología.</p>
        <button class="btn btn-primario" type="submit" :disabled="datosOp.cargando.value">
          {{ datosOp.cargando.value ? 'Guardando...' : 'Guardar datos' }}
        </button>
      </form>

      <form class="panel" novalidate @submit.prevent="guardarClave">
        <h2>Cambiar contraseña</h2>
        <AvisoOperacion :exito="claveOp.exito.value" :error="claveOp.error.value" @cerrar="claveOp.limpiar" />
        <div class="form-grid dos">
          <CampoForm etiqueta="Nueva contraseña" requerido :error="erroresClave.nueva" ayuda="Mínimo 8 caracteres." para="nueva">
            <input id="nueva" v-model="clave.nueva" type="password" autocomplete="new-password" />
          </CampoForm>
          <CampoForm etiqueta="Repetir contraseña" requerido :error="erroresClave.repetir" para="repetir">
            <input id="repetir" v-model="clave.repetir" type="password" autocomplete="new-password" />
          </CampoForm>
        </div>
        <button class="btn btn-primario" type="submit" style="margin-top: 14px" :disabled="claveOp.cargando.value">
          {{ claveOp.cargando.value ? 'Guardando...' : 'Cambiar contraseña' }}
        </button>
      </form>
    </div>
  </div>
</template>
