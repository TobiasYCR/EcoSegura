<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useOperacion } from '@/composables/useOperacion'
import { cargarIndicadores } from '@/services/indicadores'
import {
  actualizarSeguimiento,
  crearSeguimiento,
  eliminarSeguimiento,
  listarSeguimientos,
  obtenerSeguimiento
} from '@/services/seguimientos'
import { formatoFecha, formatoFechaCorta, formatoMoneda, hoyISO, rangoUltimasSemanas } from '@/utils/fechas'
import { reglas, validar } from '@/utils/validaciones'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'
import Cargando from '@/components/common/Cargando.vue'
import CampoForm from '@/components/common/CampoForm.vue'
import GraficoBarras from '@/components/common/GraficoBarras.vue'
import GraficoColumnas from '@/components/common/GraficoColumnas.vue'
import GraficoLinea from '@/components/common/GraficoLinea.vue'

const route = useRoute()
const router = useRouter()
const { nombreCompleto, puede } = useAuth()
const operacion = useOperacion()
const guardado = useOperacion()
const historial = useOperacion()
const inicial = rangoUltimasSemanas(4)
const filtros = reactive({
  desde: route.query.desde || inicial.desde,
  hasta: route.query.hasta || inicial.hasta
})
const seguimientos = ref([])
const seguimientoId = ref('')
const titulo = ref('')
const datos = ref(null)
const periodoDatos = reactive({ desde: '', hasta: '' })
const consultado = ref(null)
const interpretacion = ref('')
const acciones = ref('')
const errores = ref({})
let montado = false

const errorPeriodo = computed(() => {
  if (!filtros.desde || !filtros.hasta) return 'Elegí las dos fechas del período.'
  if (filtros.desde > filtros.hasta) return 'La fecha "desde" debe ser anterior a "hasta".'
  return reglas.noFutura(filtros.hasta)
})
const periodo = computed(() => `${formatoFecha(filtros.desde)} al ${formatoFecha(filtros.hasta)}`)
const datosDesactualizados = computed(() =>
  !datos.value || periodoDatos.desde !== filtros.desde || periodoDatos.hasta !== filtros.hasta
)
const claveLocal = computed(() => `ecosegura.seguimiento.${filtros.desde}.${filtros.hasta}`)
const listaAcciones = computed(() => acciones.value.split('\n').map((x) => x.trim()).filter(Boolean))
const estados = { cumplida: 'Meta cumplida', no_cumplida: 'Meta no cumplida', no_calculable: 'No calculable' }
const imprimir = () => window.print()
const formatoFechaHora = (valor) => valor
  ? new Intl.DateTimeFormat('es-AR', { dateStyle: 'short', timeStyle: 'short' }).format(new Date(valor))
  : '—'
const lecturaAutomatica = computed(() => {
  if (!datos.value) return []
  const lectura = []
  const franja = [...datos.value.franjas].sort((a, b) => b.valor - a.valor)[0]
  const lugar = datos.value.lugares[0]
  if (franja?.valor) lectura.push(`La franja con más acumulaciones fue ${franja.etiqueta} (${franja.valor} de ${datos.value.totales.registros}).`)
  if (lugar?.extra) lectura.push(`El lugar con más críticas externas fue ${lugar.etiqueta} (${lugar.extra} de ${datos.value.totales.criticas}).`)
  const noCalculables = datos.value.kpis.filter((k) => k.estado === 'no_calculable').map((k) => k.titulo.toLowerCase())
  if (noCalculables.length) lectura.push(`Indicadores no calculables: ${noCalculables.join(', ')}.`)
  return lectura
})

function tituloPredeterminado() {
  return `Seguimiento ${formatoFechaCorta(filtros.desde)} al ${formatoFechaCorta(filtros.hasta)}`
}

function cargarBorradorLocal() {
  try {
    const borrador = JSON.parse(localStorage.getItem(claveLocal.value) || '{}')
    titulo.value = borrador.titulo || tituloPredeterminado()
    interpretacion.value = borrador.interpretacion || ''
    acciones.value = borrador.acciones || ''
  } catch {
    titulo.value = tituloPredeterminado()
    interpretacion.value = ''
    acciones.value = ''
  }
}

function guardarBorradorLocal() {
  if (!montado || seguimientoId.value) return
  try {
    localStorage.setItem(claveLocal.value, JSON.stringify({
      titulo: titulo.value,
      interpretacion: interpretacion.value,
      acciones: acciones.value
    }))
  } catch {
    /* El borrador sigue funcionando aunque el navegador no permita almacenamiento. */
  }
}

async function cargarHistorial() {
  await historial.ejecutar(async () => (seguimientos.value = await listarSeguimientos()))
}

async function actualizarDatos() {
  if (errorPeriodo.value) return false
  const { ok } = await operacion.ejecutar(async () => {
    datos.value = await cargarIndicadores(filtros)
    Object.assign(periodoDatos, { desde: filtros.desde, hasta: filtros.hasta })
    consultado.value = new Date()
  }, 'Datos actualizados. Guardá el seguimiento para conservar esta versión.')
  return ok
}

async function nuevoSeguimiento() {
  seguimientoId.value = ''
  Object.assign(filtros, rangoUltimasSemanas(4))
  datos.value = null
  Object.assign(periodoDatos, { desde: '', hasta: '' })
  consultado.value = null
  errores.value = {}
  cargarBorradorLocal()
  guardado.limpiar()
  await router.replace({ path: '/seguimiento' })
  await actualizarDatos()
}

async function abrirSeguimiento(id) {
  const { ok, resultado } = await operacion.ejecutar(() => obtenerSeguimiento(id))
  if (!ok) return
  seguimientoId.value = resultado.id
  titulo.value = resultado.titulo
  Object.assign(filtros, { desde: resultado.periodo_desde, hasta: resultado.periodo_hasta })
  interpretacion.value = resultado.interpretacion || ''
  acciones.value = resultado.acciones || ''
  datos.value = resultado.datos
  Object.assign(periodoDatos, { desde: resultado.periodo_desde, hasta: resultado.periodo_hasta })
  consultado.value = new Date(resultado.consultado_en)
  errores.value = {}
  guardado.limpiar()
  await router.replace({ path: '/seguimiento', query: { id: resultado.id } })
}

async function guardarSeguimiento() {
  errores.value = validar({ titulo: titulo.value }, {
    titulo: [reglas.obligatorio, reglas.largo(5, 120)]
  })
  if (errorPeriodo.value) errores.value.periodo = errorPeriodo.value
  if (Object.keys(errores.value).length) return
  if (datosDesactualizados.value && !(await actualizarDatos())) return

  const payload = {
    titulo: titulo.value.trim(),
    periodo_desde: filtros.desde,
    periodo_hasta: filtros.hasta,
    interpretacion: interpretacion.value.trim() || null,
    acciones: acciones.value.trim() || null,
    datos: datos.value,
    consultado_en: (consultado.value || new Date()).toISOString()
  }
  const mensaje = seguimientoId.value ? 'Seguimiento actualizado y guardado.' : 'Nuevo seguimiento guardado.'
  const { ok, resultado } = await guardado.ejecutar(
    () => seguimientoId.value
      ? actualizarSeguimiento(seguimientoId.value, payload)
      : crearSeguimiento(payload),
    mensaje
  )
  if (!ok) return
  seguimientoId.value = resultado.id
  titulo.value = resultado.titulo
  localStorage.removeItem(claveLocal.value)
  await router.replace({ path: '/seguimiento', query: { id: resultado.id } })
  await cargarHistorial()
}

async function borrarSeguimiento(id) {
  const item = seguimientos.value.find((s) => s.id === id)
  if (!window.confirm(`¿Eliminar "${item?.titulo || 'este seguimiento'}"? Esta acción no se puede deshacer.`)) return
  const { ok } = await guardado.ejecutar(() => eliminarSeguimiento(id), 'Seguimiento eliminado.')
  if (!ok) return
  await cargarHistorial()
  if (seguimientoId.value === id) await nuevoSeguimiento()
}

function limpiarAvisos() {
  operacion.limpiar()
  guardado.limpiar()
  historial.limpiar()
}

onMounted(async () => {
  await cargarHistorial()
  if (route.query.id) await abrirSeguimiento(route.query.id)
  else {
    cargarBorradorLocal()
    await actualizarDatos()
  }
  montado = true
})
watch([titulo, interpretacion, acciones], guardarBorradorLocal)
</script>

<template>
  <div>
    <div class="encabezado-pagina no-imprimir">
      <div>
        <h1>Informes de seguimiento</h1>
        <p>Creá, guardá y consultá los cierres del piloto por período.</p>
      </div>
      <div class="acciones">
        <button class="btn" @click="nuevoSeguimiento">+ Nuevo seguimiento</button>
        <button class="btn" :disabled="operacion.cargando.value || !!errorPeriodo" @click="actualizarDatos">Actualizar datos</button>
        <button class="btn btn-primario" :disabled="guardado.cargando.value || !datos" @click="guardarSeguimiento">
          {{ guardado.cargando.value ? 'Guardando...' : seguimientoId ? 'Guardar cambios' : 'Guardar seguimiento' }}
        </button>
        <button class="btn" :disabled="datosDesactualizados" @click="imprimir">Imprimir o guardar PDF</button>
      </div>
    </div>

    <AvisoOperacion
      :exito="guardado.exito.value || operacion.exito.value"
      :error="guardado.error.value || operacion.error.value || historial.error.value"
      @cerrar="limpiarAvisos"
    />

    <section class="panel no-imprimir">
      <div class="encabezado-seccion">
        <div>
          <h2>Seguimientos guardados</h2>
          <p class="texto-secundario">Abrí un seguimiento para consultar la versión que quedó registrada.</p>
        </div>
      </div>
      <Cargando v-if="historial.cargando.value" texto="Cargando seguimientos..." />
      <p v-else-if="!seguimientos.length" class="vacio">Todavía no hay seguimientos guardados.</p>
      <div v-else class="tabla-contenedor">
        <table class="tabla">
          <thead><tr><th>Título</th><th>Período</th><th>Última actualización</th><th></th></tr></thead>
          <tbody>
            <tr v-for="s in seguimientos" :key="s.id" :class="{ seleccionado: seguimientoId === s.id }">
              <td><strong>{{ s.titulo }}</strong></td>
              <td>{{ formatoFecha(s.periodo_desde) }} al {{ formatoFecha(s.periodo_hasta) }}</td>
              <td>{{ formatoFechaHora(s.actualizado_en) }}</td>
              <td>
                <div class="acciones">
                  <button class="btn btn-chico" @click="abrirSeguimiento(s.id)">Abrir</button>
                  <button v-if="puede('administracion')" class="btn btn-chico btn-peligro" @click="borrarSeguimiento(s.id)">Eliminar</button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <section class="panel no-imprimir controles-seguimiento">
      <div class="form-grid dos">
        <CampoForm class="ancho" etiqueta="Título del seguimiento" requerido :error="errores.titulo" para="s-titulo">
          <input id="s-titulo" v-model="titulo" maxlength="120" placeholder="Seguimiento del piloto - noviembre" />
        </CampoForm>
        <label class="campo">Desde
          <input v-model="filtros.desde" type="date" :max="hoyISO()" />
        </label>
        <label class="campo">Hasta
          <input v-model="filtros.hasta" type="date" :max="hoyISO()" />
        </label>
        <label class="campo ancho">Interpretación acordada
          <textarea v-model="interpretacion" maxlength="4000" placeholder="Explicá qué metas se cumplieron, los patrones y las dificultades..."></textarea>
          <span class="ayuda">Se conserva en la base de datos al guardar el seguimiento.</span>
        </label>
        <label class="campo ancho">Acciones de mejora
          <textarea v-model="acciones" maxlength="3000" placeholder="Una acción por línea..."></textarea>
          <span class="ayuda">Cada línea se imprime como un punto de la lista.</span>
        </label>
      </div>
      <div v-if="errores.periodo || errorPeriodo" class="aviso error" style="margin: 12px 0 0">{{ errores.periodo || errorPeriodo }}</div>
      <div v-else-if="datosDesactualizados" class="aviso" style="margin: 12px 0 0">Cambiaste el período. Presioná <strong>Actualizar datos</strong> antes de imprimir; al guardar se actualizarán automáticamente.</div>
      <p class="ayuda" style="margin-bottom: 0">
        {{ seguimientoId ? 'Estás editando un seguimiento guardado.' : 'Estás preparando un seguimiento nuevo. Presioná Guardar seguimiento para incorporarlo al historial.' }}
      </p>
    </section>

    <Cargando v-if="operacion.cargando.value && !datos" texto="Armando el informe..." />

    <article v-else-if="datos" class="hoja-informe hoja-seguimiento">
      <header class="membrete">
        <div>
          <strong>EcoSegura · Cooperativa Escolar</strong>
          <div>{{ titulo || 'Informe de seguimiento del piloto' }}</div>
        </div>
        <div class="datos-emision">
          <div>Período: {{ periodo }}</div>
          <div>Emitido: {{ formatoFecha(hoyISO()) }}</div>
          <div>Preparó: {{ nombreCompleto || 'Administración y Consejo' }}</div>
        </div>
      </header>

      <div v-if="datos.hayPrueba" class="aviso prueba">Informe armado con datos de prueba: los valores son ficticios.</div>

      <section>
        <h2>Objetivo</h2>
        <p>Mostrar al Consejo de Administración, a la Comisión Ambiental y al docente asesor si el piloto avanza hacia sus metas: menos acumulaciones críticas fuera de la escuela, más reciclables recuperados y un costo razonable por kilo.</p>
      </section>

      <section>
        <h2>Fuente de los datos</h2>
        <p>
          Base de datos de EcoSegura (Supabase): {{ datos.totales.registros }} registros de residuos no anulados,
          {{ datos.totales.pesajes }} pesajes del punto verde y {{ datos.totales.movimientos }} gastos no anulados.
          Consulta realizada {{ formatoFechaHora(consultado) }}.
        </p>
      </section>

      <section>
        <h2>Indicadores</h2>
        <p>Se cumplieron {{ datos.kpis.filter((k) => k.estado === 'cumplida').length }} de {{ datos.kpis.filter((k) => k.estado !== 'no_calculable').length }} metas que se pudieron calcular.</p>
        <div class="tabla-contenedor">
          <table class="tabla tabla-informe">
            <thead><tr><th>Indicador</th><th>Meta</th><th>Resultado</th><th>Estado</th><th>Cálculo o motivo</th></tr></thead>
            <tbody>
              <tr v-for="kpi in datos.kpis" :key="kpi.id">
                <td data-label="Indicador">{{ kpi.titulo }}</td>
                <td data-label="Meta">{{ kpi.meta }}</td>
                <td data-label="Resultado"><strong>{{ kpi.resultado }}</strong></td>
                <td data-label="Estado"><span class="etiqueta" :class="{ verde: kpi.estado === 'cumplida', roja: kpi.estado === 'no_cumplida' }">{{ estados[kpi.estado] }}</span></td>
                <td data-label="Cálculo o motivo">{{ kpi.calculo }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2>Resultados por semana</h2>
        <div class="tabla-contenedor">
          <table class="tabla tabla-informe">
            <thead><tr><th>Semana</th><th>Fechas</th><th class="num">Acumulaciones externas</th><th class="num">Críticas externas</th><th class="num">Kilos</th><th class="num">Gastos</th></tr></thead>
            <tbody>
              <tr v-for="s in datos.resultadosSemana" :key="s.desde">
                <td data-label="Semana">{{ s.numero }}</td><td data-label="Fechas">{{ formatoFechaCorta(s.desde) }} al {{ formatoFechaCorta(s.hasta) }}</td>
                <td data-label="Acumulaciones externas" class="num">{{ s.externas }}</td><td data-label="Críticas externas" class="num">{{ s.criticas }}</td>
                <td data-label="Kilos" class="num">{{ s.kilos.toLocaleString('es-AR') }} kg</td><td data-label="Gastos" class="num">{{ formatoMoneda(s.gastos) }}</td>
              </tr>
              <tr class="total"><td colspan="2">Total del período</td><td data-label="Acumulaciones externas" class="num">{{ datos.totales.externos }}</td><td data-label="Críticas externas" class="num">{{ datos.totales.criticas }}</td><td data-label="Kilos" class="num">{{ datos.totales.kilos.toLocaleString('es-AR') }} kg</td><td data-label="Gastos" class="num">{{ formatoMoneda(datos.totales.gastos) }}</td></tr>
            </tbody>
          </table>
        </div>
      </section>

      <section class="graficos-informe">
        <div>
          <h3>Acumulaciones externas críticas por semana</h3>
          <GraficoLinea :datos="datos.criticasSemana" />
        </div>
        <div>
          <h3>Kilos recuperados por semana</h3>
          <GraficoLinea :datos="datos.kilosSemana" unidad=" kg" :meta="55" color="var(--verde)" />
        </div>
        <div>
          <h3>Acumulaciones externas por lugar (total: {{ datos.totales.externos }})</h3>
          <GraficoBarras :datos="datos.lugares" etiqueta-extra="Críticas" />
        </div>
        <div>
          <h3>Acumulaciones por franja horaria (total: {{ datos.totales.registros }})</h3>
          <GraficoColumnas :datos="datos.franjas" />
        </div>
      </section>

      <section>
        <h2>Lectura de los datos</h2>
        <ul><li v-for="item in lecturaAutomatica" :key="item">{{ item }}</li></ul>
      </section>
      <section>
        <h2>Interpretación</h2>
        <p class="texto-multilinea">{{ interpretacion || 'Sin interpretación cargada para este período.' }}</p>
      </section>
      <section>
        <h2>Acciones de mejora</h2>
        <ol v-if="listaAcciones.length"><li v-for="item in listaAcciones" :key="item">{{ item }}</li></ol>
        <p v-else>Sin acciones cargadas para este período.</p>
      </section>
      <footer class="pie-informe">Destinatarios: Consejo de Administración, Comisión Ambiental y docente asesor. Consulta habilitada para Ambiental, Administración y Consejo, Tecnología y Docente asesor.</footer>
    </article>
  </div>
</template>
