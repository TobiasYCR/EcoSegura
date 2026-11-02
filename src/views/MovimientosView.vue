<script setup>
import { reactive, ref, computed, onMounted, watch } from 'vue'
import { useAuth } from '@/composables/useAuth'
import { useOperacion } from '@/composables/useOperacion'
import { listarMovimientos, guardarMovimiento, anularMovimiento } from '@/services/movimientos'
import { urlFirmada } from '@/services/archivos'
import { reglas, validar, aNumero } from '@/utils/validaciones'
import { hoyISO, formatoFecha, formatoMoneda } from '@/utils/fechas'
import { TIPOS_MOVIMIENTO } from '@/utils/catalogos'
import CampoForm from '@/components/common/CampoForm.vue'
import Cargando from '@/components/common/Cargando.vue'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'
import AvisoPrueba from '@/components/common/AvisoPrueba.vue'
import EtiquetaPrueba from '@/components/common/EtiquetaPrueba.vue'

// Artículo 8 del reglamento: Administración registra ingresos y gastos.
const TIPOS_COMPROBANTE = ['image/jpeg', 'image/png', 'application/pdf']
const { puede } = useAuth()
const lista = useOperacion()
const op = useOperacion()

const items = ref([])
const filtros = reactive({ busqueda: '', tipo: '', desde: '', hasta: '', incluirAnulados: false })
const vacio = () => ({ fecha: hoyISO(), concepto: '', tipo: '', monto: '' })
const form = reactive(vacio())
const comprobante = ref(null)
const editando = ref(null)
const mostrarForm = ref(false)
const errores = ref({})
const anulandoId = ref(null)
const motivo = ref('')

const ingresos = computed(() => items.value.filter((i) => !i.anulado && i.tipo === 'ingreso').reduce((s, i) => s + Number(i.monto), 0))
const gastos = computed(() => items.value.filter((i) => !i.anulado && i.tipo === 'gasto').reduce((s, i) => s + Number(i.monto), 0))

async function cargar() {
  await lista.ejecutar(async () => (items.value = await listarMovimientos(filtros)))
}
onMounted(cargar)
let espera
watch(filtros, () => {
  clearTimeout(espera)
  espera = setTimeout(cargar, 300)
})

function nuevo() {
  editando.value = null
  Object.assign(form, vacio())
  comprobante.value = null
  errores.value = {}
  mostrarForm.value = true
}
function editar(m) {
  editando.value = m.id
  Object.assign(form, { fecha: m.fecha, concepto: m.concepto, tipo: m.tipo, monto: String(m.monto) })
  comprobante.value = null
  errores.value = {}
  mostrarForm.value = true
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

async function guardar() {
  errores.value = validar({ ...form, comprobante: comprobante.value }, {
    fecha: [reglas.obligatorio, reglas.noFutura],
    concepto: [reglas.obligatorio, reglas.largo(3, 120)],
    tipo: [reglas.obligatorio, reglas.enLista(TIPOS_MOVIMIENTO)],
    monto: [reglas.obligatorio, reglas.decimal(0, 100000000)],
    comprobante: [reglas.archivo(TIPOS_COMPROBANTE, 5)]
  })
  if (Object.keys(errores.value).length) return
  const fila = { fecha: form.fecha, concepto: form.concepto.trim(), tipo: form.tipo, monto: aNumero(form.monto) }
  const { ok } = await op.ejecutar(
    () => guardarMovimiento(fila, comprobante.value, editando.value),
    editando.value ? 'Movimiento corregido.' : 'Movimiento registrado.'
  )
  if (ok) {
    mostrarForm.value = false
    await cargar()
  }
}

async function anular(id) {
  if (motivo.value.trim().length < 5) {
    op.error.value = 'Indicá el motivo de la anulación (mínimo 5 caracteres).'
    return
  }
  if (!window.confirm('¿Anular este movimiento? Queda en el historial como anulado.')) return
  const { ok } = await op.ejecutar(() => anularMovimiento(id, motivo.value.trim()), 'Movimiento anulado.')
  if (ok) {
    anulandoId.value = null
    await cargar()
  }
}

async function verComprobante(ruta) {
  const url = await urlFirmada('comprobantes', ruta)
  if (url) window.open(url, '_blank', 'noopener')
  else op.error.value = 'No se pudo abrir el comprobante.'
}
</script>

<template>
  <div>
    <div class="encabezado-pagina">
      <div>
        <h1>Recursos y gastos</h1>
        <p>Todos los integrantes pueden consultar el uso de los recursos (artículo 3).</p>
      </div>
      <button v-if="puede('administracion') && !mostrarForm" class="btn btn-primario" @click="nuevo">+ Nuevo movimiento</button>
    </div>

    <AvisoOperacion :exito="op.exito.value" :error="op.error.value || lista.error.value" @cerrar="op.limpiar" />
    <AvisoPrueba :visible="items.some((i) => i.datos_prueba)" />

    <div class="tarjetas">
      <div class="tarjeta"><div class="numero">{{ formatoMoneda(ingresos) }}</div><div class="detalle">ingresos</div></div>
      <div class="tarjeta"><div class="numero">{{ formatoMoneda(gastos) }}</div><div class="detalle">gastos</div></div>
      <div class="tarjeta destacada"><div class="numero">{{ formatoMoneda(ingresos - gastos) }}</div><div class="detalle">saldo de lo listado</div></div>
    </div>

    <form v-if="mostrarForm" class="panel" novalidate @submit.prevent="guardar">
      <h2>{{ editando ? 'Corregir movimiento' : 'Nuevo movimiento' }}</h2>
      <div class="form-grid">
        <CampoForm etiqueta="Fecha" requerido :error="errores.fecha" para="m-fecha">
          <input id="m-fecha" v-model="form.fecha" type="date" :max="hoyISO()" />
        </CampoForm>
        <div class="campo" :class="{ 'con-error': errores.tipo }">
          <span class="etiqueta-campo">Tipo <span class="requerido">*</span></span>
          <div class="opciones">
            <label><input v-model="form.tipo" type="radio" value="ingreso" /> Ingreso</label>
            <label><input v-model="form.tipo" type="radio" value="gasto" /> Gasto</label>
          </div>
          <span v-if="errores.tipo" class="error-campo">{{ errores.tipo }}</span>
        </div>
        <CampoForm etiqueta="Monto ($)" requerido :error="errores.monto" para="m-monto">
          <input id="m-monto" v-model="form.monto" type="text" inputmode="decimal" placeholder="4800" />
        </CampoForm>
        <CampoForm class="ancho" etiqueta="Concepto" requerido :error="errores.concepto" para="m-concepto">
          <input id="m-concepto" v-model="form.concepto" maxlength="120" placeholder="Bolsas para el punto verde" />
        </CampoForm>
        <CampoForm class="ancho" etiqueta="Comprobante" :error="errores.comprobante" ayuda="PDF, JPG o PNG de hasta 5 MB." para="m-comp">
          <input id="m-comp" type="file" accept="application/pdf,image/jpeg,image/png" @change="comprobante = $event.target.files[0] || null" />
        </CampoForm>
      </div>
      <div class="acciones" style="margin-top: 14px">
        <button class="btn btn-primario" type="submit" :disabled="op.cargando.value">
          {{ op.cargando.value ? 'Guardando...' : 'Guardar' }}
        </button>
        <button class="btn" type="button" @click="mostrarForm = false">Cancelar</button>
      </div>
    </form>

    <div class="panel">
      <div class="filtros">
        <label>Buscar <input v-model="filtros.busqueda" type="search" placeholder="Concepto" /></label>
        <label>Tipo
          <select v-model="filtros.tipo">
            <option value="">Todos</option>
            <option v-for="(t, v) in TIPOS_MOVIMIENTO" :key="v" :value="v">{{ t }}</option>
          </select>
        </label>
        <label>Desde <input v-model="filtros.desde" type="date" /></label>
        <label>Hasta <input v-model="filtros.hasta" type="date" /></label>
        <label class="opciones" style="flex-direction: row; align-items: center">
          <input v-model="filtros.incluirAnulados" type="checkbox" /> Ver anulados
        </label>
      </div>
      <Cargando v-if="lista.cargando.value" texto="Cargando movimientos..." />
      <p v-else-if="!items.length" class="vacio">No hay movimientos.</p>
      <div v-else class="tabla-contenedor">
        <table class="tabla">
          <thead><tr><th>Fecha</th><th>Concepto</th><th>Tipo</th><th class="num">Monto</th><th>Comprobante</th><th></th></tr></thead>
          <tbody>
            <tr v-for="m in items" :key="m.id" :class="{ anulado: m.anulado }">
              <td>{{ formatoFecha(m.fecha) }}</td>
              <td>
                {{ m.concepto }} <EtiquetaPrueba v-if="m.datos_prueba" />
                <div v-if="m.anulado" style="font-size: 0.8rem">Anulado: {{ m.motivo_anulacion }}</div>
              </td>
              <td><span class="etiqueta" :class="m.tipo === 'ingreso' ? 'verde' : 'roja'">{{ TIPOS_MOVIMIENTO[m.tipo] }}</span></td>
              <td class="num">{{ formatoMoneda(m.monto) }}</td>
              <td>
                <button v-if="m.comprobante_path" class="btn btn-chico" @click="verComprobante(m.comprobante_path)">Ver</button>
                <span v-else>—</span>
              </td>
              <td>
                <div v-if="puede('administracion') && !m.anulado" class="acciones">
                  <template v-if="anulandoId === m.id">
                    <input v-model="motivo" placeholder="Motivo" maxlength="200" style="min-height: 30px; border: 1px solid var(--gris-300); border-radius: 6px; padding: 4px 8px" />
                    <button class="btn btn-chico btn-peligro" :disabled="op.cargando.value" @click="anular(m.id)">Confirmar</button>
                    <button class="btn btn-chico" @click="anulandoId = null">Cancelar</button>
                  </template>
                  <template v-else>
                    <button class="btn btn-chico" @click="editar(m)">Corregir</button>
                    <button class="btn btn-chico btn-peligro" @click="anulandoId = m.id; motivo = ''">Anular</button>
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
