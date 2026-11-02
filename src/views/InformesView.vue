<script setup>
import { reactive, ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useOperacion } from '@/composables/useOperacion'
import { listarInformes, crearInforme } from '@/services/informes'
import { reglas, validar } from '@/utils/validaciones'
import { hoyISO, sumarDias, formatoFecha } from '@/utils/fechas'
import { ESTADOS_INFORME, RESPUESTAS_MUNICIPIO } from '@/utils/catalogos'
import CampoForm from '@/components/common/CampoForm.vue'
import Cargando from '@/components/common/Cargando.vue'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'
import AvisoPrueba from '@/components/common/AvisoPrueba.vue'
import EtiquetaEstado from '@/components/common/EtiquetaEstado.vue'
import EtiquetaPrueba from '@/components/common/EtiquetaPrueba.vue'

const route = useRoute()
const router = useRouter()
const { puede } = useAuth()
const lista = useOperacion()
const op = useOperacion()

const informes = ref([])
const filtros = reactive({ busqueda: '', estado: route.query.estado || '' })
const mostrarForm = ref(false)
const vacio = () => ({
  titulo: '', periodo_desde: sumarDias(hoyISO(), -30), periodo_hasta: sumarDias(hoyISO(), -1),
  introduccion: '', incluye_fotos: true
})
const form = reactive(vacio())
const errores = ref({})

async function cargar() {
  await lista.ejecutar(async () => (informes.value = await listarInformes(filtros)))
}
onMounted(async () => {
  await cargar()
  if (route.query.eliminado) {
    op.exito.value = 'Informe eliminado.'
    router.replace({ query: { ...route.query, eliminado: undefined } })
  }
})
let espera
watch(filtros, () => {
  clearTimeout(espera)
  espera = setTimeout(cargar, 300)
})

async function crear() {
  errores.value = validar(form, {
    titulo: [reglas.obligatorio, reglas.largo(5, 120)],
    periodo_desde: [reglas.obligatorio],
    periodo_hasta: [
      reglas.obligatorio, reglas.noFutura,
      (v, d) => (d.periodo_desde && v < d.periodo_desde ? 'Debe ser posterior a "desde".' : '')
    ],
    introduccion: [reglas.largo(0, 2000)]
  })
  if (Object.keys(errores.value).length) return
  const { ok, resultado } = await op.ejecutar(() =>
    crearInforme({ ...form, titulo: form.titulo.trim(), introduccion: form.introduccion.trim() || null })
  )
  if (ok) router.push({ path: `/informes/${resultado.id}`, query: { creado: 1 } })
}
</script>

<template>
  <div>
    <div class="encabezado-pagina">
      <div>
        <h1>Informes al municipio</h1>
        <p>Borrador → revisión del docente asesor → aprobado → enviado.</p>
      </div>
      <button v-if="puede('administracion') && !mostrarForm" class="btn btn-primario" @click="mostrarForm = true">+ Nuevo informe</button>
    </div>

    <AvisoOperacion :exito="op.exito.value" :error="op.error.value || lista.error.value" @cerrar="op.limpiar" />
    <AvisoPrueba :visible="informes.some((i) => i.datos_prueba)" />

    <form v-if="mostrarForm" class="panel" novalidate @submit.prevent="crear">
      <h2>Nuevo informe</h2>
      <div class="form-grid">
        <CampoForm class="ancho" etiqueta="Título" requerido :error="errores.titulo" para="i-titulo">
          <input id="i-titulo" v-model="form.titulo" maxlength="120" placeholder="Acumulaciones de residuos - octubre" />
        </CampoForm>
        <CampoForm etiqueta="Período desde" requerido :error="errores.periodo_desde" para="i-desde">
          <input id="i-desde" v-model="form.periodo_desde" type="date" :max="hoyISO()" />
        </CampoForm>
        <CampoForm etiqueta="Período hasta" requerido :error="errores.periodo_hasta" para="i-hasta">
          <input id="i-hasta" v-model="form.periodo_hasta" type="date" :max="hoyISO()" />
        </CampoForm>
        <div class="campo">
          <span class="etiqueta-campo">Contenido</span>
          <div class="opciones"><label><input v-model="form.incluye_fotos" type="checkbox" /> Incluir fotos</label></div>
        </div>
        <CampoForm class="ancho" etiqueta="Introducción" :error="errores.introduccion" para="i-intro" :ayuda="`${form.introduccion.length}/2000`">
          <textarea id="i-intro" v-model="form.introduccion" maxlength="2000" placeholder="La Cooperativa Escolar EcoSegura informa..."></textarea>
        </CampoForm>
      </div>
      <div class="acciones" style="margin-top: 14px">
        <button class="btn btn-primario" type="submit" :disabled="op.cargando.value">{{ op.cargando.value ? 'Creando...' : 'Crear borrador' }}</button>
        <button class="btn" type="button" @click="mostrarForm = false; Object.assign(form, vacio())">Cancelar</button>
      </div>
    </form>

    <div class="panel">
      <div class="filtros" style="grid-template-columns: 2fr 1fr">
        <label>Buscar <input v-model="filtros.busqueda" type="search" placeholder="Título" /></label>
        <label>Estado
          <select v-model="filtros.estado">
            <option value="">Todos</option>
            <option v-for="(t, v) in ESTADOS_INFORME" :key="v" :value="v">{{ t }}</option>
          </select>
        </label>
      </div>
      <Cargando v-if="lista.cargando.value" texto="Cargando informes..." />
      <p v-else-if="!informes.length" class="vacio">No hay informes.</p>
      <div v-else class="tabla-contenedor">
        <table class="tabla">
          <thead><tr><th>Título</th><th>Período</th><th>Estado</th><th>Envío</th><th>Respuesta</th></tr></thead>
          <tbody>
            <tr v-for="i in informes" :key="i.id" class="clic" @click="router.push(`/informes/${i.id}`)">
              <td><strong>{{ i.titulo }}</strong> <EtiquetaPrueba v-if="i.datos_prueba" /></td>
              <td>{{ formatoFecha(i.periodo_desde) }} al {{ formatoFecha(i.periodo_hasta) }}</td>
              <td><EtiquetaEstado :estado="i.estado" /></td>
              <td>{{ formatoFecha(i.fecha_envio) }}</td>
              <td>{{ i.estado === 'enviado' ? RESPUESTAS_MUNICIPIO[i.respuesta_municipio] : '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
