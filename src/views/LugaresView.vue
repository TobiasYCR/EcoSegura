<script setup>
import { ref, onMounted } from 'vue'
import { useOperacion } from '@/composables/useOperacion'
import { listarLugares, crearLugar, actualizarLugar } from '@/services/lugares'
import { reglas, validar } from '@/utils/validaciones'
import CampoForm from '@/components/common/CampoForm.vue'
import Cargando from '@/components/common/Cargando.vue'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'

// Lista de lugares de la pantalla "Nuevo registro". No se borran: se desactivan,
// así los registros viejos conservan su lugar.
const lista = useOperacion()
const op = useOperacion()
const lugares = ref([])
const nombre = ref('')
const error = ref('')
const editandoId = ref(null)
const nombreEdicion = ref('')

async function cargar() {
  await lista.ejecutar(async () => (lugares.value = await listarLugares({ soloActivos: false })))
}
onMounted(cargar)

async function crear() {
  error.value = validar({ nombre: nombre.value }, { nombre: [reglas.obligatorio, reglas.largo(3, 60)] }).nombre || ''
  if (error.value) return
  const { ok } = await op.ejecutar(() => crearLugar(nombre.value), 'Lugar agregado.')
  if (ok) {
    nombre.value = ''
    await cargar()
  }
}

async function guardar(l) {
  if (nombreEdicion.value.trim().length < 3) {
    op.error.value = 'El nombre debe tener al menos 3 caracteres.'
    return
  }
  const { ok } = await op.ejecutar(() => actualizarLugar(l.id, { nombre: nombreEdicion.value.trim() }), 'Lugar actualizado.')
  if (ok) {
    editandoId.value = null
    await cargar()
  }
}

async function alternar(l) {
  const { ok } = await op.ejecutar(
    () => actualizarLugar(l.id, { activo: !l.activo }),
    l.activo ? 'Lugar desactivado: ya no aparece al cargar registros.' : 'Lugar activado.'
  )
  if (ok) await cargar()
}
</script>

<template>
  <div>
    <div class="encabezado-pagina">
      <div>
        <h1>Lugares de relevamiento</h1>
        <p>Opciones de la lista "Lugar" al cargar un registro.</p>
      </div>
    </div>
    <AvisoOperacion :exito="op.exito.value" :error="op.error.value || lista.error.value" @cerrar="op.limpiar" />

    <form class="panel" novalidate @submit.prevent="crear">
      <div class="acciones" style="align-items: flex-end">
        <CampoForm etiqueta="Nuevo lugar" requerido :error="error" para="l-nombre" style="flex: 1; min-width: 220px">
          <input id="l-nombre" v-model="nombre" maxlength="60" placeholder="Esquina norte" />
        </CampoForm>
        <button class="btn btn-primario" type="submit" :disabled="op.cargando.value">Agregar</button>
      </div>
    </form>

    <div class="panel">
      <Cargando v-if="lista.cargando.value" texto="Cargando lugares..." />
      <div v-else class="tabla-contenedor">
        <table class="tabla">
          <thead><tr><th>Lugar</th><th>Estado</th><th></th></tr></thead>
          <tbody>
            <tr v-for="l in lugares" :key="l.id">
              <td>
                <input v-if="editandoId === l.id" v-model="nombreEdicion" maxlength="60" aria-label="Nombre del lugar" />
                <span v-else>{{ l.nombre }}</span>
              </td>
              <td><span class="etiqueta" :class="l.activo ? 'verde' : ''">{{ l.activo ? 'Activo' : 'Inactivo' }}</span></td>
              <td>
                <div class="acciones">
                  <template v-if="editandoId === l.id">
                    <button class="btn btn-chico btn-primario" @click="guardar(l)">Guardar</button>
                    <button class="btn btn-chico" @click="editandoId = null">Cancelar</button>
                  </template>
                  <template v-else>
                    <button class="btn btn-chico" @click="editandoId = l.id; nombreEdicion = l.nombre">Renombrar</button>
                    <button class="btn btn-chico" @click="alternar(l)">{{ l.activo ? 'Desactivar' : 'Activar' }}</button>
                  </template>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
