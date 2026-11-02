<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useOperacion } from '@/composables/useOperacion'
import { obtenerRegistro, actualizarRegistro, anularRegistro } from '@/services/registros'
import { mapaNombres } from '@/services/perfiles'
import { urlFirmada } from '@/services/archivos'
import { formatoFecha, formatoHora } from '@/utils/fechas'
import { TIPOS_RESIDUO, CLIMAS, DIAS } from '@/utils/catalogos'
import { reglas, validar } from '@/utils/validaciones'
import Cargando from '@/components/common/Cargando.vue'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'
import EtiquetaEstado from '@/components/common/EtiquetaEstado.vue'
import EtiquetaPrueba from '@/components/common/EtiquetaPrueba.vue'
import CampoForm from '@/components/common/CampoForm.vue'

const route = useRoute()
const router = useRouter()
const { perfil, puede } = useAuth()
const carga = useOperacion()
const accion = useOperacion()

const r = ref(null)
const foto = ref(null)
const nombres = ref({})
const tipoNuevo = ref('')
const anulando = ref(false)
const motivo = ref('')
const errorMotivo = ref('')

const puedeCorregir = computed(() => puede('relevador') && r.value?.creado_por === perfil.value.id && r.value?.estado === 'pendiente')
const puedeRevisar = computed(() => puede('ambiental') && r.value && r.value.estado !== 'anulado')
const puedeAnular = computed(() => puede('tecnologia') && r.value && r.value.estado !== 'anulado')

async function cargar() {
  r.value = await obtenerRegistro(route.params.id)
  tipoNuevo.value = r.value.tipo
  foto.value = await urlFirmada('fotos', r.value.foto_path)
}

onMounted(async () => {
  await carga.ejecutar(async () => {
    nombres.value = await mapaNombres().catch(() => ({}))
    await cargar()
  })
  if (route.query.guardado === 'corregido') accion.exito.value = 'Registro corregido.'
})

async function revisar(estado) {
  const texto = estado === 'revisado' ? 'Registro marcado como revisado.' : 'Registro devuelto a pendiente.'
  await accion.ejecutar(async () => {
    await actualizarRegistro(r.value.id, { estado, tipo: tipoNuevo.value })
    await cargar()
  }, texto)
}

async function cambiarTipo() {
  await accion.ejecutar(async () => {
    await actualizarRegistro(r.value.id, { tipo: tipoNuevo.value })
    await cargar()
  }, 'Tipo actualizado.')
}

async function anular() {
  errorMotivo.value = validar({ motivo: motivo.value }, { motivo: [reglas.obligatorio, reglas.largo(5, 200)] }).motivo || ''
  if (errorMotivo.value) return
  if (!window.confirm('¿Anular este registro? No se borra: queda en el historial como anulado.')) return
  const { ok } = await accion.ejecutar(() => anularRegistro(r.value.id, motivo.value.trim()))
  if (ok) router.push({ path: '/registros', query: { guardado: 'anulado' } })
}
</script>

<template>
  <div>
    <div class="encabezado-pagina">
      <div>
        <RouterLink to="/registros" class="btn-texto">← Registros</RouterLink>
        <h1 style="margin-top: 6px">Detalle del registro</h1>
      </div>
    </div>

    <Cargando v-if="carga.cargando.value" texto="Cargando registro..." />
    <AvisoOperacion v-else-if="carga.error.value" :error="carga.error.value" />

    <template v-else-if="r">
      <AvisoOperacion :exito="accion.exito.value" :error="accion.error.value" @cerrar="accion.limpiar" />
      <div v-if="r.datos_prueba" class="aviso prueba">Este registro es un <strong>dato de prueba</strong> (ficticio).</div>

      <div class="columnas">
        <section class="panel">
          <div class="panel-encabezado">
            <h2>{{ r.lugar }}</h2>
            <EtiquetaEstado :estado="r.estado" />
          </div>
          <dl class="detalle-lista">
            <dt>Fecha y hora</dt><dd>{{ DIAS[r.dia_semana] }} {{ formatoFecha(r.fecha) }} · {{ formatoHora(r.hora) }}</dd>
            <dt>Tipo</dt><dd>{{ TIPOS_RESIDUO[r.tipo] }}</dd>
            <dt>Cantidad de bolsas</dt>
            <dd>{{ r.cantidad_bolsas }} <span v-if="r.critica" class="etiqueta roja">Acumulación crítica</span></dd>
            <dt>Clima</dt><dd>{{ CLIMAS[r.clima] || 'Sin indicar' }}</dd>
            <dt>Descripción</dt><dd>{{ r.descripcion }}</dd>
            <dt>Cargó</dt><dd>{{ nombres[r.creado_por] || '—' }} <EtiquetaPrueba v-if="r.datos_prueba" /></dd>
            <dt v-if="r.revisado_por">Revisó</dt><dd v-if="r.revisado_por">{{ nombres[r.revisado_por] || '—' }}</dd>
            <dt v-if="r.estado === 'anulado'">Motivo de anulación</dt>
            <dd v-if="r.estado === 'anulado'">{{ r.motivo_anulacion }}</dd>
          </dl>
          <div class="acciones" style="margin-top: 14px">
            <RouterLink v-if="puedeCorregir" :to="`/registros/${r.id}/editar`" class="btn btn-primario">Corregir</RouterLink>
          </div>
        </section>

        <section class="panel">
          <h2>Foto</h2>
          <img v-if="foto" :src="foto" class="foto-detalle" alt="Foto del registro" />
          <p v-else class="vacio">El registro no tiene foto.</p>
        </section>
      </div>

      <!-- Comisión Ambiental: revisar y clasificar -->
      <section v-if="puedeRevisar" class="panel">
        <h2>Revisar y clasificar</h2>
        <div class="form-grid">
          <CampoForm etiqueta="Tipo" para="tipo-revision">
            <select id="tipo-revision" v-model="tipoNuevo">
              <option v-for="(t, v) in TIPOS_RESIDUO" :key="v" :value="v">{{ t }}</option>
            </select>
          </CampoForm>
        </div>
        <div class="acciones" style="margin-top: 14px">
          <button v-if="r.estado === 'pendiente'" class="btn btn-primario" :disabled="accion.cargando.value" @click="revisar('revisado')">
            {{ accion.cargando.value ? 'Guardando...' : 'Marcar como revisado' }}
          </button>
          <button v-else class="btn" :disabled="accion.cargando.value" @click="revisar('pendiente')">Volver a pendiente</button>
          <button v-if="tipoNuevo !== r.tipo" class="btn" :disabled="accion.cargando.value" @click="cambiarTipo">Solo cambiar el tipo</button>
        </div>
      </section>

      <!-- Tecnología: anular duplicados o errores -->
      <section v-if="puedeAnular" class="panel">
        <h2>Anular registro</h2>
        <p style="color: var(--gris-500)">Para duplicados o cargas erróneas. El registro no se borra: queda en el historial marcado como anulado.</p>
        <button v-if="!anulando" class="btn btn-peligro" @click="anulando = true">Anular...</button>
        <form v-else novalidate @submit.prevent="anular">
          <CampoForm etiqueta="Motivo" requerido :error="errorMotivo" para="motivo">
            <input id="motivo" v-model="motivo" maxlength="200" placeholder="Duplicado del registro de las 10:20" />
          </CampoForm>
          <div class="acciones" style="margin-top: 10px">
            <button class="btn btn-peligro" type="submit" :disabled="accion.cargando.value">
              {{ accion.cargando.value ? 'Anulando...' : 'Confirmar anulación' }}
            </button>
            <button class="btn" type="button" @click="anulando = false">Cancelar</button>
          </div>
        </form>
      </section>
    </template>
  </div>
</template>
