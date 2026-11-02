<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuth } from '@/composables/useAuth'
import { useOperacion } from '@/composables/useOperacion'
import { listarRegistros } from '@/services/registros'
import { listarReciclables } from '@/services/reciclables'
import { contar } from '@/services/informes'
import { listarUsuarios } from '@/services/perfiles'
import { hoyISO, sumarDias, formatoFechaCorta, formatoHora, formatoKilos } from '@/utils/fechas'
import { TIPOS_RESIDUO } from '@/utils/catalogos'
import Cargando from '@/components/common/Cargando.vue'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'
import EtiquetaEstado from '@/components/common/EtiquetaEstado.vue'
import EtiquetaPrueba from '@/components/common/EtiquetaPrueba.vue'

const { perfil, rol, nombreRol, puede } = useAuth()
const { cargando, error, ejecutar, limpiar } = useOperacion()

const semana = ref([])
const ultimos = ref([])
const kilosMes = ref(0)
const pendientes = ref(0)
const informesRevision = ref(0)
const informesAprobados = ref(0)
const sinPerfil = ref(0)
const misRegistros = ref(0)

const criticasSemana = computed(() => semana.value.filter((r) => r.critica).length)
const lugaresCriticos = computed(() => new Set(semana.value.filter((r) => r.critica).map((r) => r.lugar)).size)

onMounted(() =>
  ejecutar(async () => {
    const hoy = hoyISO()
    const tareas = [
      listarRegistros({ desde: sumarDias(hoy, -6), hasta: hoy, estado: 'activos' }).then((r) => (semana.value = r.data)),
      listarRegistros({ estado: 'activos', limite: 5 }).then((r) => (ultimos.value = r.data)),
      listarReciclables({ desde: sumarDias(hoy, -29), hasta: hoy }).then(
        (l) => (kilosMes.value = l.reduce((s, x) => s + Number(x.kilos), 0))
      ),
      contar('registros_residuos', { estado: 'pendiente' }).then((n) => (pendientes.value = n))
    ]
    if (puede('ambiental', 'administracion', 'tecnologia', 'docente')) {
      tareas.push(contar('informes', { estado: 'en_revision' }).then((n) => (informesRevision.value = n)))
      tareas.push(contar('informes', { estado: 'aprobado' }).then((n) => (informesAprobados.value = n)))
    }
    if (puede('tecnologia')) {
      tareas.push(listarUsuarios({ perfil: 'sin_perfil', estado: 'todos' }).then((l) => (sinPerfil.value = l.length)))
    }
    if (puede('relevador')) {
      tareas.push(contar('registros_residuos', { creado_por: perfil.value.id }).then((n) => (misRegistros.value = n)))
    }
    await Promise.all(tareas)
  })
)
</script>

<template>
  <div>
    <div class="encabezado-pagina">
      <div>
        <h1>Hola, {{ perfil?.nombre || 'integrante' }}</h1>
        <p>Perfil: {{ nombreRol }}</p>
      </div>
      <RouterLink v-if="puede('relevador')" to="/registros/nuevo" class="btn btn-primario">+ Nuevo registro</RouterLink>
    </div>

    <AvisoOperacion :error="error" @cerrar="limpiar" />
    <Cargando v-if="cargando" texto="Cargando el panel..." />

    <template v-else>
      <div class="tarjetas">
        <div class="tarjeta">
          <div class="numero">{{ semana.length }}</div>
          <div class="detalle">registros esta semana</div>
        </div>
        <div class="tarjeta destacada">
          <div class="numero">{{ criticasSemana }}</div>
          <div class="detalle">acumulaciones críticas en {{ lugaresCriticos }} puntos</div>
        </div>
        <div v-if="puede('relevador')" class="tarjeta">
          <div class="numero">{{ misRegistros }}</div>
          <div class="detalle">registros cargados por vos</div>
        </div>
        <div v-if="puede('ambiental', 'tecnologia', 'administracion')" class="tarjeta">
          <div class="numero">{{ pendientes }}</div>
          <div class="detalle">registros pendientes de revisión</div>
        </div>
        <div class="tarjeta">
          <div class="numero">{{ formatoKilos(kilosMes) }}</div>
          <div class="detalle">reciclables en los últimos 30 días</div>
        </div>
        <div v-if="puede('docente', 'administracion')" class="tarjeta" :class="{ destacada: rol === 'docente' && informesRevision }">
          <div class="numero">{{ informesRevision }}</div>
          <div class="detalle">informes esperando revisión docente</div>
        </div>
        <div v-if="puede('administracion')" class="tarjeta" :class="{ destacada: informesAprobados }">
          <div class="numero">{{ informesAprobados }}</div>
          <div class="detalle">informes aprobados para enviar</div>
        </div>
        <div v-if="puede('tecnologia')" class="tarjeta" :class="{ destacada: sinPerfil }">
          <div class="numero">{{ sinPerfil }}</div>
          <div class="detalle">cuentas sin perfil asignado</div>
        </div>
      </div>

      <div class="columnas">
        <section class="panel">
          <h2>Accesos</h2>
          <div class="botonera">
            <RouterLink v-if="puede('relevador')" to="/registros/nuevo" class="btn btn-primario">+ Nuevo registro</RouterLink>
            <RouterLink to="/registros" class="btn">Ver registros</RouterLink>
            <RouterLink v-if="puede('ambiental')" to="/registros?estado=pendiente" class="btn">Revisar pendientes</RouterLink>
            <RouterLink v-if="puede('ambiental')" to="/reciclables" class="btn">Cargar reciclables</RouterLink>
            <RouterLink to="/estadisticas" class="btn">Estadísticas</RouterLink>
            <RouterLink v-if="puede('administracion')" to="/informes" class="btn">Armar informe</RouterLink>
            <RouterLink v-if="puede('docente')" to="/informes?estado=en_revision" class="btn">Revisar informes</RouterLink>
            <RouterLink v-if="puede('administracion')" to="/actas" class="btn">Cargar acta</RouterLink>
            <RouterLink v-if="puede('administracion')" to="/movimientos" class="btn">Recursos y gastos</RouterLink>
            <RouterLink v-if="puede('tecnologia')" to="/usuarios" class="btn">Usuarios y perfiles</RouterLink>
          </div>
        </section>

        <section class="panel">
          <div class="panel-encabezado">
            <h2>Últimos registros</h2>
            <RouterLink to="/registros" class="btn btn-chico">Ver todos</RouterLink>
          </div>
          <p v-if="!ultimos.length" class="vacio">Todavía no hay registros.</p>
          <div v-else class="lista-registros">
            <RouterLink v-for="r in ultimos" :key="r.id" :to="`/registros/${r.id}`" class="item-registro" style="grid-template-columns: 1fr auto">
              <div>
                <div class="titulo">{{ r.lugar }} <EtiquetaPrueba v-if="r.datos_prueba" /></div>
                <div class="meta">
                  {{ formatoFechaCorta(r.fecha) }} · {{ formatoHora(r.hora) }} · {{ TIPOS_RESIDUO[r.tipo] }} ·
                  {{ r.cantidad_bolsas }} bolsas<span v-if="r.critica" style="color: var(--rojo); font-weight: 700"> · crítica</span>
                </div>
              </div>
              <EtiquetaEstado :estado="r.estado" />
            </RouterLink>
          </div>
        </section>
      </div>
    </template>
  </div>
</template>
