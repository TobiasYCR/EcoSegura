<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useOperacion } from '@/composables/useOperacion'
import { obtenerInforme, actualizarInforme, eliminarInforme } from '@/services/informes'
import { mapaNombres } from '@/services/perfiles'
import { reglas, validar } from '@/utils/validaciones'
import { hoyISO, formatoFecha } from '@/utils/fechas'
import { RESPUESTAS_MUNICIPIO } from '@/utils/catalogos'
import CampoForm from '@/components/common/CampoForm.vue'
import Cargando from '@/components/common/Cargando.vue'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'
import EtiquetaEstado from '@/components/common/EtiquetaEstado.vue'
import InformeVistaPrevia from '@/components/informes/InformeVistaPrevia.vue'

const route = useRoute()
const router = useRouter()
const { puede } = useAuth()
const carga = useOperacion()
const op = useOperacion()

const inf = ref(null)
const nombres = ref({})
const version = ref(0)
const editando = ref(false)
const form = reactive({ titulo: '', periodo_desde: '', periodo_hasta: '', introduccion: '', incluye_fotos: true })
const observaciones = ref('')
const envio = reactive({ fecha_envio: hoyISO() })
const respuesta = reactive({ respuesta_municipio: 'sin_respuesta', respuesta_detalle: '' })
const errores = ref({})

const esAdmin = computed(() => puede('administracion'))
const esDocente = computed(() => puede('docente'))
const exportable = computed(() => ['aprobado', 'enviado'].includes(inf.value?.estado))

function sincronizar(i) {
  inf.value = i
  Object.assign(form, {
    titulo: i.titulo, periodo_desde: i.periodo_desde, periodo_hasta: i.periodo_hasta,
    introduccion: i.introduccion || '', incluye_fotos: i.incluye_fotos
  })
  observaciones.value = i.observaciones_docente || ''
  Object.assign(respuesta, { respuesta_municipio: i.respuesta_municipio, respuesta_detalle: i.respuesta_detalle || '' })
  version.value++
}

onMounted(async () => {
  await carga.ejecutar(async () => {
    nombres.value = await mapaNombres().catch(() => ({}))
    sincronizar(await obtenerInforme(route.params.id))
  })
  if (route.query.creado) op.exito.value = 'Borrador creado. Revisá la vista previa y pedí la revisión del docente.'
})

async function cambiar(cambios, mensaje) {
  const { ok, resultado } = await op.ejecutar(() => actualizarInforme(inf.value.id, cambios), mensaje)
  if (ok) sincronizar(resultado)
  return ok
}

async function guardarEdicion() {
  errores.value = validar(form, {
    titulo: [reglas.obligatorio, reglas.largo(5, 120)],
    periodo_desde: [reglas.obligatorio],
    periodo_hasta: [reglas.obligatorio, reglas.noFutura, (v, d) => (v < d.periodo_desde ? 'Debe ser posterior a "desde".' : '')],
    introduccion: [reglas.largo(0, 2000)]
  })
  if (Object.keys(errores.value).length) return
  if (await cambiar({ ...form, introduccion: form.introduccion.trim() || null }, 'Borrador actualizado.')) editando.value = false
}

async function pedirRevision() {
  if (!window.confirm('¿Enviar el informe al docente asesor? Mientras esté en revisión no se puede editar.')) return
  await cambiar({ estado: 'en_revision' }, 'Informe enviado a revisión del docente.')
}

async function revisar(estado) {
  errores.value = {}
  if (estado === 'borrador' && observaciones.value.trim().length < 5) {
    errores.value.observaciones = 'Para devolver el informe dejá una observación.'
    return
  }
  const texto = estado === 'aprobado' ? 'Informe aprobado.' : estado === 'borrador' ? 'Informe devuelto con observaciones.' : 'Observaciones guardadas.'
  if (estado !== 'en_revision' && !window.confirm(estado === 'aprobado' ? '¿Aprobar el informe?' : '¿Devolver el informe a Administración?')) return
  await cambiar({ estado, observaciones_docente: observaciones.value.trim() || null }, texto)
}

async function marcarEnviado() {
  errores.value = validar(envio, { fecha_envio: [reglas.obligatorio, reglas.noFutura] })
  if (Object.keys(errores.value).length) return
  if (!window.confirm('¿Marcar el informe como enviado al municipio?')) return
  await cambiar({ estado: 'enviado', fecha_envio: envio.fecha_envio }, 'Informe marcado como enviado.')
}

async function guardarRespuesta() {
  errores.value = validar(respuesta, { respuesta_detalle: [reglas.largo(0, 2000)] })
  if (Object.keys(errores.value).length) return
  await cambiar({ ...respuesta, respuesta_detalle: respuesta.respuesta_detalle.trim() || null }, 'Respuesta del municipio registrada.')
}

async function eliminar() {
  if (!window.confirm('¿Eliminar este borrador? No se puede deshacer.')) return
  const { ok } = await op.ejecutar(() => eliminarInforme(inf.value.id))
  if (ok) router.push({ path: '/informes', query: { eliminado: 1 } })
}

function exportar() {
  window.print()
}
</script>

<template>
  <div>
    <div class="encabezado-pagina no-imprimir">
      <div>
        <RouterLink to="/informes" class="btn-texto">← Informes</RouterLink>
        <h1 style="margin-top: 6px">{{ inf?.titulo || 'Informe' }}</h1>
        <p v-if="inf">{{ formatoFecha(inf.periodo_desde) }} al {{ formatoFecha(inf.periodo_hasta) }}</p>
      </div>
      <div v-if="inf" class="acciones">
        <EtiquetaEstado :estado="inf.estado" />
        <button class="btn btn-primario" :disabled="!exportable" :title="exportable ? '' : 'Se exporta cuando el docente lo aprueba'" @click="exportar">
          Exportar PDF
        </button>
      </div>
    </div>

    <Cargando v-if="carga.cargando.value" texto="Cargando informe..." />
    <AvisoOperacion v-else-if="carga.error.value" :error="carga.error.value" />

    <template v-else-if="inf">
      <div class="no-imprimir">
        <AvisoOperacion :exito="op.exito.value" :error="op.error.value" @cerrar="op.limpiar" />

        <div v-if="inf.observaciones_docente && !esDocente" class="aviso info">
          <strong>Observaciones del docente<template v-if="inf.revisado_por"> ({{ nombres[inf.revisado_por] }})</template>:</strong>
          {{ inf.observaciones_docente }}
        </div>

        <!-- Administración: editar borrador y avanzar el circuito -->
        <section v-if="esAdmin" class="panel">
          <h2>Acciones de Administración</h2>
          <template v-if="inf.estado === 'borrador'">
            <form v-if="editando" novalidate @submit.prevent="guardarEdicion">
              <div class="form-grid">
                <CampoForm class="ancho" etiqueta="Título" requerido :error="errores.titulo" para="e-titulo">
                  <input id="e-titulo" v-model="form.titulo" maxlength="120" />
                </CampoForm>
                <CampoForm etiqueta="Desde" requerido :error="errores.periodo_desde" para="e-desde">
                  <input id="e-desde" v-model="form.periodo_desde" type="date" :max="hoyISO()" />
                </CampoForm>
                <CampoForm etiqueta="Hasta" requerido :error="errores.periodo_hasta" para="e-hasta">
                  <input id="e-hasta" v-model="form.periodo_hasta" type="date" :max="hoyISO()" />
                </CampoForm>
                <div class="campo">
                  <span class="etiqueta-campo">Contenido</span>
                  <div class="opciones"><label><input v-model="form.incluye_fotos" type="checkbox" /> Incluir fotos</label></div>
                </div>
                <CampoForm class="ancho" etiqueta="Introducción" :error="errores.introduccion" para="e-intro">
                  <textarea id="e-intro" v-model="form.introduccion" maxlength="2000"></textarea>
                </CampoForm>
              </div>
              <div class="acciones" style="margin-top: 12px">
                <button class="btn btn-primario" type="submit" :disabled="op.cargando.value">{{ op.cargando.value ? 'Guardando...' : 'Guardar cambios' }}</button>
                <button class="btn" type="button" @click="editando = false">Cancelar</button>
              </div>
            </form>
            <div v-else class="acciones">
              <button class="btn" @click="editando = true">Editar borrador</button>
              <button class="btn btn-primario" :disabled="op.cargando.value" @click="pedirRevision">Pedir revisión al docente</button>
              <button class="btn btn-peligro" :disabled="op.cargando.value" @click="eliminar">Eliminar borrador</button>
            </div>
          </template>
          <p v-else-if="inf.estado === 'en_revision'" style="margin: 0">El informe está esperando la revisión del docente asesor.</p>
          <form v-else-if="inf.estado === 'aprobado'" class="acciones" novalidate style="align-items: flex-end" @submit.prevent="marcarEnviado">
            <CampoForm etiqueta="Fecha de envío" requerido :error="errores.fecha_envio" para="e-envio">
              <input id="e-envio" v-model="envio.fecha_envio" type="date" :max="hoyISO()" />
            </CampoForm>
            <button class="btn btn-primario" type="submit" :disabled="op.cargando.value">Marcar como enviado</button>
          </form>
          <form v-else novalidate @submit.prevent="guardarRespuesta">
            <p>Enviado el {{ formatoFecha(inf.fecha_envio) }}. Registrá la respuesta que llegó por mail.</p>
            <div class="form-grid">
              <CampoForm etiqueta="¿Respondió el municipio?" para="e-resp">
                <select id="e-resp" v-model="respuesta.respuesta_municipio">
                  <option v-for="(t, v) in RESPUESTAS_MUNICIPIO" :key="v" :value="v">{{ t }}</option>
                </select>
              </CampoForm>
              <CampoForm class="ancho" etiqueta="Detalle de la respuesta" :error="errores.respuesta_detalle" para="e-det">
                <textarea id="e-det" v-model="respuesta.respuesta_detalle" maxlength="2000"></textarea>
              </CampoForm>
            </div>
            <button class="btn btn-primario" type="submit" style="margin-top: 12px" :disabled="op.cargando.value">
              {{ op.cargando.value ? 'Guardando...' : 'Guardar respuesta' }}
            </button>
          </form>
        </section>

        <!-- Docente asesor: observa y aprueba -->
        <section v-if="esDocente" class="panel">
          <h2>Revisión del docente asesor</h2>
          <template v-if="inf.estado === 'en_revision'">
            <CampoForm etiqueta="Observaciones" :error="errores.observaciones" para="d-obs" ayuda="Obligatorias si devolvés el informe.">
              <textarea id="d-obs" v-model="observaciones" maxlength="2000"></textarea>
            </CampoForm>
            <div class="acciones" style="margin-top: 12px">
              <button class="btn btn-primario" :disabled="op.cargando.value" @click="revisar('aprobado')">Aprobar</button>
              <button class="btn btn-peligro" :disabled="op.cargando.value" @click="revisar('borrador')">Devolver con observaciones</button>
              <button class="btn" :disabled="op.cargando.value" @click="revisar('en_revision')">Guardar observaciones</button>
            </div>
          </template>
          <p v-else style="margin: 0">
            {{ inf.estado === 'borrador' ? 'El informe todavía no fue enviado a revisión.' : 'El informe ya fue aprobado.' }}
            <template v-if="inf.observaciones_docente"><br />Tus observaciones: {{ inf.observaciones_docente }}</template>
          </p>
        </section>

        <h2>Vista previa</h2>
      </div>
      <InformeVistaPrevia :key="version" :informe="inf" />
    </template>
  </div>
</template>
