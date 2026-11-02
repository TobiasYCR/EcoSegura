<script setup>
import { reactive, ref, computed, onMounted, watch } from 'vue'
import { useAuth } from '@/composables/useAuth'
import { useOperacion } from '@/composables/useOperacion'
import { listarReciclables, crearReciclable, actualizarReciclable } from '@/services/reciclables'
import { mapaNombres } from '@/services/perfiles'
import { reglas, validar, aNumero } from '@/utils/validaciones'
import { hoyISO, sumarDias, formatoFecha, formatoKilos } from '@/utils/fechas'
import { MATERIALES } from '@/utils/catalogos'
import CampoForm from '@/components/common/CampoForm.vue'
import Cargando from '@/components/common/Cargando.vue'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'
import AvisoPrueba from '@/components/common/AvisoPrueba.vue'
import EtiquetaPrueba from '@/components/common/EtiquetaPrueba.vue'

const { puede } = useAuth()
const lista = useOperacion()
const op = useOperacion()

const items = ref([])
const nombres = ref({})
const filtros = reactive({ material: '', desde: sumarDias(hoyISO(), -29), hasta: hoyISO(), incluirAnulados: false })
const vacio = () => ({ fecha: hoyISO(), material: '', kilos: '', observacion: '' })
const form = reactive(vacio())
const editando = ref(null)
const errores = ref({})
const anulandoId = ref(null)
const motivo = ref('')

const totales = computed(() => {
  const t = Object.fromEntries(Object.keys(MATERIALES).map((m) => [m, 0]))
  for (const i of items.value) if (!i.anulado) t[i.material] += Number(i.kilos)
  return t
})
const totalGeneral = computed(() => Object.values(totales.value).reduce((a, b) => a + b, 0))

async function cargar() {
  await lista.ejecutar(async () => {
    items.value = await listarReciclables(filtros)
  })
}
onMounted(async () => {
  nombres.value = await mapaNombres().catch(() => ({}))
  await cargar()
})
watch(filtros, cargar)

function editar(i) {
  editando.value = i.id
  Object.assign(form, { fecha: i.fecha, material: i.material, kilos: String(i.kilos), observacion: i.observacion || '' })
  errores.value = {}
  window.scrollTo({ top: 0, behavior: 'smooth' })
}
function cancelar() {
  editando.value = null
  Object.assign(form, vacio())
  errores.value = {}
}

async function guardar() {
  errores.value = validar(form, {
    fecha: [reglas.obligatorio, reglas.noFutura],
    material: [reglas.obligatorio, reglas.enLista(MATERIALES)],
    kilos: [reglas.obligatorio, reglas.decimal(0, 1000)],
    observacion: [reglas.largo(0, 200)]
  })
  if (Object.keys(errores.value).length) return
  const fila = { fecha: form.fecha, material: form.material, kilos: aNumero(form.kilos), observacion: form.observacion.trim() || null }
  const { ok } = await op.ejecutar(
    () => (editando.value ? actualizarReciclable(editando.value, fila) : crearReciclable(fila)),
    editando.value ? 'Pesaje corregido.' : 'Pesaje registrado.'
  )
  if (ok) {
    cancelar()
    await cargar()
  }
}

async function anular(id) {
  if (motivo.value.trim().length < 5) {
    op.error.value = 'Indicá el motivo de la anulación (mínimo 5 caracteres).'
    return
  }
  if (!window.confirm('¿Anular este pesaje? Queda en el historial como anulado.')) return
  const { ok } = await op.ejecutar(
    () => actualizarReciclable(id, { anulado: true, motivo_anulacion: motivo.value.trim() }),
    'Pesaje anulado.'
  )
  if (ok) {
    anulandoId.value = null
    motivo.value = ''
    await cargar()
  }
}
</script>

<template>
  <div>
    <div class="encabezado-pagina">
      <div>
        <h1>Reciclables recuperados</h1>
        <p>Pesajes del punto verde por material.</p>
      </div>
    </div>

    <AvisoOperacion :exito="op.exito.value" :error="op.error.value || lista.error.value" @cerrar="op.limpiar" />
    <AvisoPrueba :visible="items.some((i) => i.datos_prueba)" />

    <div class="tarjetas">
      <div class="tarjeta destacada">
        <div class="numero">{{ formatoKilos(totalGeneral) }}</div>
        <div class="detalle">total del período</div>
      </div>
      <div v-for="(t, m) in MATERIALES" :key="m" class="tarjeta">
        <div class="numero">{{ formatoKilos(totales[m]) }}</div>
        <div class="detalle">{{ t }}</div>
      </div>
    </div>

    <form v-if="puede('ambiental')" class="panel" novalidate @submit.prevent="guardar">
      <h2>{{ editando ? 'Corregir pesaje' : 'Registrar pesaje' }}</h2>
      <div class="form-grid">
        <CampoForm etiqueta="Fecha" requerido :error="errores.fecha" para="r-fecha">
          <input id="r-fecha" v-model="form.fecha" type="date" :max="hoyISO()" />
        </CampoForm>
        <CampoForm etiqueta="Material" requerido :error="errores.material" para="r-material">
          <select id="r-material" v-model="form.material">
            <option value="">Elegí el material</option>
            <option v-for="(t, m) in MATERIALES" :key="m" :value="m">{{ t }}</option>
          </select>
        </CampoForm>
        <CampoForm etiqueta="Kilos" requerido :error="errores.kilos" ayuda="Hasta 2 decimales, máximo 1000." para="r-kilos">
          <input id="r-kilos" v-model="form.kilos" type="text" inputmode="decimal" placeholder="2,5" />
        </CampoForm>
        <CampoForm class="ancho" etiqueta="Observación" :error="errores.observacion" para="r-obs">
          <input id="r-obs" v-model="form.observacion" maxlength="200" placeholder="Opcional" />
        </CampoForm>
      </div>
      <div class="acciones" style="margin-top: 14px">
        <button class="btn btn-primario" type="submit" :disabled="op.cargando.value">
          {{ op.cargando.value ? 'Guardando...' : editando ? 'Guardar corrección' : 'Registrar' }}
        </button>
        <button v-if="editando" class="btn" type="button" @click="cancelar">Cancelar</button>
      </div>
    </form>

    <div class="panel">
      <div class="filtros">
        <label>Material
          <select v-model="filtros.material">
            <option value="">Todos</option>
            <option v-for="(t, m) in MATERIALES" :key="m" :value="m">{{ t }}</option>
          </select>
        </label>
        <label>Desde <input v-model="filtros.desde" type="date" /></label>
        <label>Hasta <input v-model="filtros.hasta" type="date" /></label>
        <label class="opciones" style="flex-direction: row; align-items: center">
          <input v-model="filtros.incluirAnulados" type="checkbox" /> Ver anulados
        </label>
      </div>

      <Cargando v-if="lista.cargando.value" texto="Cargando pesajes..." />
      <p v-else-if="!items.length" class="vacio">No hay pesajes en el período.</p>
      <div v-else class="tabla-contenedor">
        <table class="tabla">
          <thead>
            <tr><th>Fecha</th><th>Material</th><th class="num">Kilos</th><th>Observación</th><th>Cargó</th><th></th></tr>
          </thead>
          <tbody>
            <tr v-for="i in items" :key="i.id" :class="{ anulado: i.anulado }">
              <td>{{ formatoFecha(i.fecha) }}</td>
              <td>{{ MATERIALES[i.material] }}</td>
              <td class="num">{{ formatoKilos(i.kilos) }}</td>
              <td>{{ i.anulado ? 'Anulado: ' + i.motivo_anulacion : i.observacion || '—' }}</td>
              <td>{{ nombres[i.creado_por] || '—' }} <EtiquetaPrueba v-if="i.datos_prueba" /></td>
              <td>
                <div v-if="!i.anulado" class="acciones">
                  <button v-if="puede('ambiental')" class="btn btn-chico" @click="editar(i)">Corregir</button>
                  <template v-if="puede('tecnologia')">
                    <template v-if="anulandoId === i.id">
                      <input v-model="motivo" class="btn-chico" placeholder="Motivo" maxlength="200" style="min-height: 30px; border: 1px solid var(--gris-300); border-radius: 6px; padding: 4px 8px" />
                      <button class="btn btn-chico btn-peligro" :disabled="op.cargando.value" @click="anular(i.id)">Confirmar</button>
                      <button class="btn btn-chico" @click="anulandoId = null">Cancelar</button>
                    </template>
                    <button v-else class="btn btn-chico btn-peligro" @click="anulandoId = i.id; motivo = ''">Anular</button>
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
