<script setup>
import { reactive, ref, onMounted, watch } from 'vue'
import { useAuth } from '@/composables/useAuth'
import { useOperacion } from '@/composables/useOperacion'
import { listarActas, guardarActa } from '@/services/actas'
import { reglas, validar } from '@/utils/validaciones'
import { hoyISO, formatoFecha } from '@/utils/fechas'
import CampoForm from '@/components/common/CampoForm.vue'
import Cargando from '@/components/common/Cargando.vue'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'
import AvisoPrueba from '@/components/common/AvisoPrueba.vue'
import EtiquetaPrueba from '@/components/common/EtiquetaPrueba.vue'

// Artículo 7 del reglamento: fecha, participantes, temas, decisiones y responsables.
const { puede } = useAuth()
const lista = useOperacion()
const op = useOperacion()

const actas = ref([])
const filtros = reactive({ busqueda: '', desde: '', hasta: '' })
const vacio = () => ({ fecha: hoyISO(), participantes: '', temas: '', decisiones: '', responsables: '' })
const form = reactive(vacio())
const editando = ref(null)
const mostrarForm = ref(false)
const errores = ref({})
const abierta = ref(null)

async function cargar() {
  await lista.ejecutar(async () => (actas.value = await listarActas(filtros)))
}
onMounted(cargar)
let espera
watch(filtros, () => {
  clearTimeout(espera)
  espera = setTimeout(cargar, 300)
})

function nueva() {
  editando.value = null
  Object.assign(form, vacio())
  errores.value = {}
  mostrarForm.value = true
}
function editar(a) {
  editando.value = a.id
  Object.assign(form, {
    fecha: a.fecha, participantes: a.participantes, temas: a.temas,
    decisiones: a.decisiones, responsables: a.responsables || ''
  })
  errores.value = {}
  mostrarForm.value = true
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

async function guardar() {
  errores.value = validar(form, {
    fecha: [reglas.obligatorio, reglas.noFutura],
    participantes: [reglas.obligatorio, reglas.largo(3, 1000)],
    temas: [reglas.obligatorio, reglas.largo(3, 2000)],
    decisiones: [reglas.obligatorio, reglas.largo(3, 2000)],
    responsables: [reglas.largo(0, 1000)]
  })
  if (Object.keys(errores.value).length) return
  const fila = { ...form, responsables: form.responsables.trim() || null }
  const { ok } = await op.ejecutar(() => guardarActa(fila, editando.value), editando.value ? 'Acta actualizada.' : 'Acta registrada.')
  if (ok) {
    mostrarForm.value = false
    await cargar()
  }
}
</script>

<template>
  <div>
    <div class="encabezado-pagina">
      <div>
        <h1>Actas de reuniones</h1>
        <p>Todos los integrantes pueden consultarlas (artículo 3 del reglamento).</p>
      </div>
      <button v-if="puede('administracion') && !mostrarForm" class="btn btn-primario" @click="nueva">+ Nueva acta</button>
    </div>

    <AvisoOperacion :exito="op.exito.value" :error="op.error.value || lista.error.value" @cerrar="op.limpiar" />
    <AvisoPrueba :visible="actas.some((a) => a.datos_prueba)" />

    <form v-if="mostrarForm" class="panel" novalidate @submit.prevent="guardar">
      <h2>{{ editando ? 'Editar acta' : 'Nueva acta' }}</h2>
      <div class="form-grid dos">
        <CampoForm etiqueta="Fecha de la reunión" requerido :error="errores.fecha" para="a-fecha">
          <input id="a-fecha" v-model="form.fecha" type="date" :max="hoyISO()" />
        </CampoForm>
        <CampoForm etiqueta="Participantes" requerido :error="errores.participantes" para="a-part">
          <input id="a-part" v-model="form.participantes" maxlength="1000" placeholder="Presidencia, Secretaría..." />
        </CampoForm>
        <CampoForm class="ancho" etiqueta="Temas tratados" requerido :error="errores.temas" para="a-temas">
          <textarea id="a-temas" v-model="form.temas" maxlength="2000"></textarea>
        </CampoForm>
        <CampoForm class="ancho" etiqueta="Decisiones tomadas" requerido :error="errores.decisiones" para="a-dec">
          <textarea id="a-dec" v-model="form.decisiones" maxlength="2000"></textarea>
        </CampoForm>
        <CampoForm class="ancho" etiqueta="Responsables de cada tarea" :error="errores.responsables" para="a-resp">
          <textarea id="a-resp" v-model="form.responsables" maxlength="1000" placeholder="Secretaría: envío del informe..."></textarea>
        </CampoForm>
      </div>
      <div class="acciones" style="margin-top: 14px">
        <button class="btn btn-primario" type="submit" :disabled="op.cargando.value">
          {{ op.cargando.value ? 'Guardando...' : 'Guardar acta' }}
        </button>
        <button class="btn" type="button" @click="mostrarForm = false">Cancelar</button>
      </div>
    </form>

    <div class="panel">
      <div class="filtros">
        <label>Buscar <input v-model="filtros.busqueda" type="search" placeholder="Tema, decisión o participante" /></label>
        <label>Desde <input v-model="filtros.desde" type="date" /></label>
        <label>Hasta <input v-model="filtros.hasta" type="date" /></label>
      </div>
      <Cargando v-if="lista.cargando.value" texto="Cargando actas..." />
      <p v-else-if="!actas.length" class="vacio">No hay actas registradas.</p>
      <div v-else class="lista-registros">
        <article v-for="a in actas" :key="a.id" class="panel" style="margin: 0">
          <div class="panel-encabezado">
            <h3 style="margin: 0">Reunión del {{ formatoFecha(a.fecha) }} <EtiquetaPrueba v-if="a.datos_prueba" /></h3>
            <div class="acciones">
              <button class="btn btn-chico" @click="abierta = abierta === a.id ? null : a.id">{{ abierta === a.id ? 'Ocultar' : 'Ver acta' }}</button>
              <button v-if="puede('administracion')" class="btn btn-chico" @click="editar(a)">Editar</button>
            </div>
          </div>
          <p style="margin: 0; color: var(--gris-700)">{{ a.temas }}</p>
          <dl v-if="abierta === a.id" class="detalle-lista" style="margin-top: 12px">
            <dt>Participantes</dt><dd>{{ a.participantes }}</dd>
            <dt>Decisiones</dt><dd>{{ a.decisiones }}</dd>
            <dt>Responsables</dt><dd>{{ a.responsables || '—' }}</dd>
          </dl>
        </article>
      </div>
    </div>
  </div>
</template>
