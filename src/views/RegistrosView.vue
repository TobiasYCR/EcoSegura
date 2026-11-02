<script setup>
import { reactive, ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useOperacion } from '@/composables/useOperacion'
import { listarRegistros } from '@/services/registros'
import { listarLugares } from '@/services/lugares'
import { mapaNombres } from '@/services/perfiles'
import { urlsFirmadas } from '@/services/archivos'
import { formatoFecha, formatoFechaCorta, formatoHora } from '@/utils/fechas'
import { TIPOS_RESIDUO, ESTADOS_REGISTRO } from '@/utils/catalogos'
import Cargando from '@/components/common/Cargando.vue'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'
import AvisoPrueba from '@/components/common/AvisoPrueba.vue'
import EtiquetaEstado from '@/components/common/EtiquetaEstado.vue'
import EtiquetaPrueba from '@/components/common/EtiquetaPrueba.vue'

const route = useRoute()
const router = useRouter()
const { perfil, puede } = useAuth()
const { cargando, error, exito, ejecutar, limpiar } = useOperacion()

const registros = ref([])
const total = ref(0)
const lugares = ref([])
const nombres = ref({})
const fotos = ref({})
const filtros = reactive({
  busqueda: '',
  tipo: '',
  estado: route.query.estado || 'activos',
  lugarId: '',
  desde: '',
  hasta: '',
  mios: false
})

const hayPrueba = computed(() => registros.value.some((r) => r.datos_prueba))

async function cargar(mensaje = '') {
  await ejecutar(async () => {
    const { data, count } = await listarRegistros({
      ...filtros,
      soloMios: filtros.mios ? perfil.value.id : null
    })
    registros.value = data
    total.value = count
    fotos.value = await urlsFirmadas('fotos', data.slice(0, 30).map((r) => r.foto_path))
  }, mensaje)
}

onMounted(async () => {
  const mensajes = { nuevo: 'Registro guardado.', anulado: 'Registro anulado.' }
  await Promise.all([
    listarLugares({ soloActivos: false }).then((l) => (lugares.value = l)),
    mapaNombres().then((m) => (nombres.value = m))
  ]).catch(() => {})
  await cargar(mensajes[route.query.guardado] || '')
  if (route.query.guardado) router.replace({ query: { ...route.query, guardado: undefined } })
})

let espera = null
watch(filtros, () => {
  clearTimeout(espera)
  espera = setTimeout(() => cargar(), 300)
})

function limpiarFiltros() {
  Object.assign(filtros, { busqueda: '', tipo: '', estado: 'activos', lugarId: '', desde: '', hasta: '', mios: false })
}
</script>

<template>
  <div>
    <div class="encabezado-pagina">
      <div>
        <h1>Registros de residuos</h1>
        <p>{{ total }} registros encontrados</p>
      </div>
      <RouterLink v-if="puede('relevador')" to="/registros/nuevo" class="btn btn-primario">+ Nuevo registro</RouterLink>
    </div>

    <AvisoOperacion :exito="exito" :error="error" @cerrar="limpiar" />
    <AvisoPrueba :visible="hayPrueba" />

    <div class="panel">
      <div class="filtros">
        <label>Buscar
          <input v-model="filtros.busqueda" type="search" placeholder="Descripción o lugar" />
        </label>
        <label>Tipo
          <select v-model="filtros.tipo">
            <option value="">Todos</option>
            <option v-for="(t, v) in TIPOS_RESIDUO" :key="v" :value="v">{{ t }}</option>
          </select>
        </label>
        <label>Estado
          <select v-model="filtros.estado">
            <option value="activos">Pendientes y revisados</option>
            <option v-for="(t, v) in ESTADOS_REGISTRO" :key="v" :value="v">{{ t }}</option>
            <option value="">Todos</option>
          </select>
        </label>
        <label>Lugar
          <select v-model="filtros.lugarId">
            <option value="">Todos</option>
            <option v-for="l in lugares" :key="l.id" :value="l.id">{{ l.nombre }}</option>
          </select>
        </label>
        <label>Desde
          <input v-model="filtros.desde" type="date" />
        </label>
        <label v-if="puede('relevador')" class="opciones" style="flex-direction: row; align-items: center">
          <input v-model="filtros.mios" type="checkbox" /> Solo mis registros
        </label>
        <label>Hasta
          <input v-model="filtros.hasta" type="date" />
        </label>
        <div style="display: flex; align-items: flex-end">
          <button type="button" class="btn btn-chico" @click="limpiarFiltros">Limpiar filtros</button>
        </div>
      </div>

      <Cargando v-if="cargando" texto="Cargando registros..." />
      <p v-else-if="!registros.length" class="vacio">No hay registros con esos filtros.</p>

      <template v-else>
        <!-- Computadora: tabla -->
        <div class="tabla-contenedor solo-escritorio">
          <table class="tabla">
            <thead>
              <tr>
                <th>Fecha</th><th>Hora</th><th>Lugar</th><th>Tipo</th><th class="num">Bolsas</th>
                <th>Descripción</th><th>Cargó</th><th>Estado</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in registros" :key="r.id" class="clic" :class="{ anulado: r.estado === 'anulado' }"
                  @click="router.push(`/registros/${r.id}`)">
                <td>{{ formatoFecha(r.fecha) }}</td>
                <td>{{ formatoHora(r.hora) }}</td>
                <td>{{ r.lugar }}</td>
                <td>{{ TIPOS_RESIDUO[r.tipo] }}</td>
                <td class="num">
                  {{ r.cantidad_bolsas }}
                  <span v-if="r.critica" class="etiqueta roja">Crítica</span>
                </td>
                <td>{{ r.descripcion }}</td>
                <td>{{ nombres[r.creado_por] || '—' }} <EtiquetaPrueba v-if="r.datos_prueba" /></td>
                <td><EtiquetaEstado :estado="r.estado" /></td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Celular: tarjetas, lo último arriba -->
        <div class="lista-registros solo-movil">
          <RouterLink v-for="r in registros" :key="r.id" :to="`/registros/${r.id}`" class="item-registro">
            <img v-if="fotos[r.foto_path]" :src="fotos[r.foto_path]" class="miniatura" alt="" />
            <div v-else class="miniatura">Sin foto</div>
            <div>
              <div class="titulo">{{ r.lugar }}</div>
              <div class="meta">
                {{ formatoFechaCorta(r.fecha) }} · {{ formatoHora(r.hora) }} · {{ TIPOS_RESIDUO[r.tipo] }}
              </div>
              <div class="meta">
                {{ r.cantidad_bolsas }} bolsas
                <span v-if="r.critica" class="etiqueta roja">Crítica</span>
                <EtiquetaPrueba v-if="r.datos_prueba" />
              </div>
            </div>
            <EtiquetaEstado :estado="r.estado" />
          </RouterLink>
        </div>
      </template>
    </div>
  </div>
</template>
