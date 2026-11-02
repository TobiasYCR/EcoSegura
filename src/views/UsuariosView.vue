<script setup>
import { reactive, ref, onMounted, watch } from 'vue'
import { useAuth } from '@/composables/useAuth'
import { useOperacion } from '@/composables/useOperacion'
import { listarUsuarios, crearUsuario, asignarPerfil } from '@/services/perfiles'
import { reglas, validar } from '@/utils/validaciones'
import { PERFILES, COMISIONES } from '@/utils/catalogos'
import CampoForm from '@/components/common/CampoForm.vue'
import Cargando from '@/components/common/Cargando.vue'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'

// Tecnología crea usuarios y asigna perfiles; Administración y Docente consultan.
const { perfil: yo, puede } = useAuth()
const lista = useOperacion()
const op = useOperacion()

const usuarios = ref([])
const filtros = reactive({ busqueda: '', perfil: '', estado: 'activos' })
const mostrarAlta = ref(false)
const vacio = () => ({ nombre: '', apellido: '', email: '', clave: '', perfil: '', comision: '', curso: '' })
const alta = reactive(vacio())
const erroresAlta = ref({})
const editandoId = ref(null)
const edicion = reactive({ perfil: '', comision: '', curso: '', activo: true })

async function cargar() {
  await lista.ejecutar(async () => (usuarios.value = await listarUsuarios(filtros)))
}
onMounted(cargar)
let espera
watch(filtros, () => {
  clearTimeout(espera)
  espera = setTimeout(cargar, 300)
})

async function crear() {
  erroresAlta.value = validar(alta, {
    nombre: [reglas.obligatorio, reglas.largo(2, 60)],
    apellido: [reglas.obligatorio, reglas.largo(2, 60)],
    email: [reglas.obligatorio, reglas.email],
    clave: [reglas.obligatorio, reglas.largo(8, 72)],
    perfil: [reglas.obligatorio, reglas.enLista(PERFILES)],
    comision: [reglas.enLista(COMISIONES)],
    curso: [reglas.largo(0, 20)]
  })
  if (Object.keys(erroresAlta.value).length) return
  const { ok } = await op.ejecutar(
    () => crearUsuario(alta),
    `Usuario creado. Pasale a ${alta.nombre} su email y la contraseña inicial para que la cambie al ingresar.`
  )
  if (ok) {
    Object.assign(alta, vacio())
    mostrarAlta.value = false
    await cargar()
  }
}

function editar(u) {
  editandoId.value = u.id
  Object.assign(edicion, { perfil: u.perfil || '', comision: u.comision || '', curso: u.curso || '', activo: u.activo })
}

async function guardarEdicion(u) {
  if (edicion.activo && !edicion.perfil) {
    op.error.value = 'Elegí un perfil para el usuario activo.'
    return
  }
  if (!edicion.activo && !window.confirm(`¿Desactivar a ${u.nombre} ${u.apellido}? No podrá ingresar, pero sus registros se conservan.`)) return
  const { ok } = await op.ejecutar(() => asignarPerfil({ id: u.id, ...edicion }), 'Perfil actualizado.')
  if (ok) {
    editandoId.value = null
    await cargar()
  }
}
</script>

<template>
  <div>
    <div class="encabezado-pagina">
      <div>
        <h1>Usuarios</h1>
        <p>{{ puede('tecnologia') ? 'Creá usuarios y asigná el perfil de cada integrante.' : 'Integrantes con acceso al sistema.' }}</p>
      </div>
      <button v-if="puede('tecnologia') && !mostrarAlta" class="btn btn-primario" @click="mostrarAlta = true">+ Nuevo usuario</button>
    </div>

    <AvisoOperacion :exito="op.exito.value" :error="op.error.value || lista.error.value" @cerrar="op.limpiar" />

    <form v-if="mostrarAlta" class="panel" novalidate @submit.prevent="crear">
      <h2>Nuevo usuario</h2>
      <div class="form-grid">
        <CampoForm etiqueta="Nombre" requerido :error="erroresAlta.nombre" para="u-nombre">
          <input id="u-nombre" v-model="alta.nombre" maxlength="60" />
        </CampoForm>
        <CampoForm etiqueta="Apellido" requerido :error="erroresAlta.apellido" para="u-apellido">
          <input id="u-apellido" v-model="alta.apellido" maxlength="60" />
        </CampoForm>
        <CampoForm etiqueta="Email (usuario)" requerido :error="erroresAlta.email" para="u-email">
          <input id="u-email" v-model="alta.email" type="email" inputmode="email" autocomplete="off" />
        </CampoForm>
        <CampoForm etiqueta="Contraseña inicial" requerido :error="erroresAlta.clave" ayuda="Mínimo 8 caracteres. La persona la cambia desde Mi cuenta." para="u-clave">
          <input id="u-clave" v-model="alta.clave" type="password" autocomplete="new-password" />
        </CampoForm>
        <CampoForm etiqueta="Perfil" requerido :error="erroresAlta.perfil" para="u-perfil">
          <select id="u-perfil" v-model="alta.perfil">
            <option value="">Elegí el perfil</option>
            <option v-for="(t, v) in PERFILES" :key="v" :value="v">{{ t }}</option>
          </select>
        </CampoForm>
        <CampoForm etiqueta="Comisión" :error="erroresAlta.comision" para="u-comision">
          <select id="u-comision" v-model="alta.comision">
            <option value="">Sin comisión</option>
            <option v-for="(t, v) in COMISIONES" :key="v" :value="v">{{ t }}</option>
          </select>
        </CampoForm>
        <CampoForm etiqueta="Curso" :error="erroresAlta.curso" ayuda="Ej.: 5° 2°. Vacío para docentes." para="u-curso">
          <input id="u-curso" v-model="alta.curso" maxlength="20" />
        </CampoForm>
      </div>
      <div class="acciones" style="margin-top: 14px">
        <button class="btn btn-primario" type="submit" :disabled="op.cargando.value">{{ op.cargando.value ? 'Creando...' : 'Crear usuario' }}</button>
        <button class="btn" type="button" @click="mostrarAlta = false">Cancelar</button>
      </div>
    </form>

    <div class="panel">
      <div class="filtros" style="grid-template-columns: 2fr 1fr 1fr">
        <label>Buscar <input v-model="filtros.busqueda" type="search" placeholder="Nombre, apellido o email" /></label>
        <label>Perfil
          <select v-model="filtros.perfil">
            <option value="">Todos</option>
            <option v-for="(t, v) in PERFILES" :key="v" :value="v">{{ t }}</option>
            <option value="sin_perfil">Sin perfil asignado</option>
          </select>
        </label>
        <label>Estado
          <select v-model="filtros.estado">
            <option value="activos">Activos</option>
            <option value="inactivos">Inactivos</option>
            <option value="todos">Todos</option>
          </select>
        </label>
      </div>
      <Cargando v-if="lista.cargando.value" texto="Cargando usuarios..." />
      <p v-else-if="!usuarios.length" class="vacio">No hay usuarios con esos filtros.</p>
      <div v-else class="tabla-contenedor">
        <table class="tabla">
          <thead><tr><th>Integrante</th><th>Email</th><th>Perfil</th><th>Comisión</th><th>Curso</th><th>Estado</th><th v-if="puede('tecnologia')"></th></tr></thead>
          <tbody>
            <tr v-for="u in usuarios" :key="u.id" :class="{ anulado: !u.activo }">
              <td>{{ u.apellido }}, {{ u.nombre }}</td>
              <td>{{ u.email }}</td>
              <template v-if="editandoId === u.id">
                <td>
                  <select v-model="edicion.perfil" aria-label="Perfil">
                    <option value="">Sin perfil</option>
                    <option v-for="(t, v) in PERFILES" :key="v" :value="v">{{ t }}</option>
                  </select>
                </td>
                <td>
                  <select v-model="edicion.comision" aria-label="Comisión">
                    <option value="">Sin comisión</option>
                    <option v-for="(t, v) in COMISIONES" :key="v" :value="v">{{ t }}</option>
                  </select>
                </td>
                <td><input v-model="edicion.curso" maxlength="20" aria-label="Curso" style="width: 80px" /></td>
                <td>
                  <label class="opciones"><input v-model="edicion.activo" type="checkbox" :disabled="u.id === yo.id" /> Activo</label>
                </td>
                <td>
                  <div class="acciones">
                    <button class="btn btn-chico btn-primario" :disabled="op.cargando.value" @click="guardarEdicion(u)">Guardar</button>
                    <button class="btn btn-chico" @click="editandoId = null">Cancelar</button>
                  </div>
                </td>
              </template>
              <template v-else>
                <td>
                  <span v-if="u.perfil" class="etiqueta azul">{{ PERFILES[u.perfil] }}</span>
                  <span v-else class="etiqueta ambar">Sin perfil</span>
                </td>
                <td>{{ COMISIONES[u.comision] || '—' }}</td>
                <td>{{ u.curso || '—' }}</td>
                <td><span class="etiqueta" :class="u.activo ? 'verde' : ''">{{ u.activo ? 'Activo' : 'Inactivo' }}</span></td>
                <td v-if="puede('tecnologia')">
                  <button class="btn btn-chico" @click="editar(u)">Editar</button>
                </td>
              </template>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
