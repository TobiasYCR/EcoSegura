<script setup>
import { reactive, ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useOperacion } from '@/composables/useOperacion'
import { listarLugares } from '@/services/lugares'
import { crearRegistro, obtenerRegistro, actualizarRegistro } from '@/services/registros'
import { urlFirmada } from '@/services/archivos'
import { reglas, validar } from '@/utils/validaciones'
import { hoyISO, horaActual } from '@/utils/fechas'
import { CLIMAS, BOLSAS_CRITICA } from '@/utils/catalogos'
import CampoForm from '@/components/common/CampoForm.vue'
import AvisoOperacion from '@/components/common/AvisoOperacion.vue'
import Cargando from '@/components/common/Cargando.vue'
import Icono from '@/components/common/Icono.vue'

// Borrador local: si se pierde la conexión o se cierra la app en la calle,
// el texto cargado se recupera (la foto no se guarda en el navegador).
const CLAVE_BORRADOR = 'ecosegura.borrador-registro'
const TIPOS_FOTO = ['image/jpeg', 'image/png', 'image/webp']

const route = useRoute()
const router = useRouter()
const { perfil } = useAuth()
const carga = useOperacion()
const guardado = useOperacion()

const idEdicion = computed(() => route.params.id || null)
const lugares = ref([])
const foto = ref(null)
const vistaFoto = ref(null)
const errores = ref({})
const borradorRecuperado = ref(false)

const form = reactive({
  fecha: hoyISO(),
  hora: horaActual(),
  lugar_id: '',
  tipo: '',
  cantidad_bolsas: '0',
  clima: '',
  descripcion: ''
})

const esCritica = computed(() => Number(form.cantidad_bolsas) >= BOLSAS_CRITICA)

onMounted(() =>
  carga.ejecutar(async () => {
    lugares.value = await listarLugares()
    if (idEdicion.value) {
      const r = await obtenerRegistro(idEdicion.value)
      if (r.creado_por !== perfil.value.id || r.estado !== 'pendiente') {
        throw new Error('Solo podés corregir tus propios registros mientras están pendientes.')
      }
      Object.assign(form, {
        fecha: r.fecha, hora: r.hora.slice(0, 5), lugar_id: r.lugar_id, tipo: r.tipo,
        cantidad_bolsas: String(r.cantidad_bolsas), clima: r.clima || '', descripcion: r.descripcion
      })
      vistaFoto.value = await urlFirmada('fotos', r.foto_path)
    } else {
      try {
        const b = JSON.parse(localStorage.getItem(CLAVE_BORRADOR) || 'null')
        if (b && (b.descripcion || b.lugar_id)) {
          Object.assign(form, { ...b, fecha: hoyISO(), hora: horaActual() })
          borradorRecuperado.value = true
        }
      } catch {
        /* sin almacenamiento local */
      }
    }
  })
)

watch(form, () => {
  if (idEdicion.value) return
  try {
    localStorage.setItem(CLAVE_BORRADOR, JSON.stringify(form))
  } catch {
    /* sin almacenamiento local */
  }
})

// Al corregir un campo se quita su mensaje de error
watch(
  () => ({ ...form }),
  (nuevo, viejo) => {
    for (const k of Object.keys(nuevo)) if (nuevo[k] !== viejo[k]) delete errores.value[k]
  }
)

function elegirFoto(e) {
  const archivo = e.target.files[0]
  if (!archivo) return
  foto.value = archivo
  vistaFoto.value = URL.createObjectURL(archivo)
  delete errores.value.foto
}

function descartarBorrador() {
  try {
    localStorage.removeItem(CLAVE_BORRADOR)
  } catch {
    /* sin almacenamiento local */
  }
  Object.assign(form, { lugar_id: '', tipo: '', cantidad_bolsas: '0', clima: '', descripcion: '' })
  borradorRecuperado.value = false
}

async function guardar() {
  errores.value = validar({ ...form, foto: foto.value }, {
    fecha: [reglas.obligatorio, reglas.noFutura],
    hora: [reglas.obligatorio, reglas.hora],
    lugar_id: [reglas.obligatorio],
    tipo: [reglas.obligatorio],
    cantidad_bolsas: [reglas.obligatorio, reglas.entero(0, 50)],
    clima: [reglas.enLista(CLIMAS)],
    descripcion: [reglas.obligatorio, reglas.largo(5, 300)],
    foto: [
      (f) => (!f && !idEdicion.value ? 'La foto es obligatoria: es la prueba del problema.' : ''),
      reglas.archivo(TIPOS_FOTO, 5)
    ]
  })
  if (Object.keys(errores.value).length) return

  const fila = {
    fecha: form.fecha,
    hora: form.hora,
    lugar_id: Number(form.lugar_id),
    tipo: form.tipo,
    cantidad_bolsas: Number(form.cantidad_bolsas),
    clima: form.clima || null,
    descripcion: form.descripcion.trim()
  }
  const { ok } = await guardado.ejecutar(async () => {
    if (idEdicion.value) return actualizarRegistro(idEdicion.value, fila)
    return crearRegistro(fila, foto.value, perfil.value.id)
  })
  if (!ok) return
  if (idEdicion.value) {
    router.push({ path: `/registros/${idEdicion.value}`, query: { guardado: 'corregido' } })
  } else {
    try {
      localStorage.removeItem(CLAVE_BORRADOR)
    } catch {
      /* sin almacenamiento local */
    }
    router.push({ path: '/registros', query: { guardado: 'nuevo' } })
  }
}
</script>

<template>
  <div>
    <div class="encabezado-pagina">
      <div>
        <h1>{{ idEdicion ? 'Corregir registro' : 'Nuevo registro' }}</h1>
        <p>Fecha y hora se completan solas. Los campos con <span style="color: var(--rojo)">*</span> son obligatorios.</p>
      </div>
    </div>

    <Cargando v-if="carga.cargando.value" texto="Cargando lugares..." />
    <AvisoOperacion v-else-if="carga.error.value" :error="carga.error.value" />

    <form v-else class="panel" novalidate @submit.prevent="guardar">
      <div v-if="borradorRecuperado" class="aviso info">
        Se recuperó el registro que habías empezado a cargar.
        <button type="button" class="btn-texto" @click="descartarBorrador">Empezar de nuevo</button>
      </div>
      <AvisoOperacion :error="guardado.error.value" @cerrar="guardado.limpiar" />

      <div class="form-grid">
        <div class="ancho campo" :class="{ 'con-error': errores.foto }">
          <span class="etiqueta-campo">Foto <span v-if="!idEdicion" class="requerido">*</span></span>
          <label class="foto-carga" :class="{ 'sin-cambio': idEdicion }">
            <img v-if="vistaFoto" :src="vistaFoto" alt="Foto del residuo" />
            <template v-else>
              <Icono nombre="camara" />
              <span>Cámara · Sacar foto</span>
            </template>
            <input v-if="!idEdicion" type="file" accept="image/jpeg,image/png,image/webp" capture="environment" @change="elegirFoto" />
          </label>
          <span v-if="errores.foto" class="error-campo">{{ errores.foto }}</span>
          <span v-else class="ayuda">{{ idEdicion ? 'La foto no se cambia al corregir.' : 'JPG, PNG o WEBP de hasta 5 MB.' }}</span>
        </div>

        <CampoForm etiqueta="Fecha" requerido :error="errores.fecha" para="fecha">
          <input id="fecha" v-model="form.fecha" type="date" :max="hoyISO()" />
        </CampoForm>
        <CampoForm etiqueta="Hora" requerido :error="errores.hora" para="hora">
          <input id="hora" v-model="form.hora" type="time" />
        </CampoForm>
        <CampoForm etiqueta="Lugar" requerido :error="errores.lugar_id" para="lugar">
          <select id="lugar" v-model="form.lugar_id">
            <option value="">Elegí el lugar</option>
            <option v-for="l in lugares" :key="l.id" :value="l.id">{{ l.nombre }}</option>
          </select>
        </CampoForm>

        <div class="campo" :class="{ 'con-error': errores.tipo }">
          <span class="etiqueta-campo">Tipo <span class="requerido">*</span></span>
          <div class="opciones" role="radiogroup">
            <label><input v-model="form.tipo" type="radio" value="interno" /> Interno</label>
            <label><input v-model="form.tipo" type="radio" value="externo" /> Externo</label>
          </div>
          <span v-if="errores.tipo" class="error-campo">{{ errores.tipo }}</span>
          <span v-else class="ayuda">Interno: dentro de la escuela. Externo: le toca al municipio.</span>
        </div>
        <CampoForm etiqueta="Cantidad de bolsas" requerido :error="errores.cantidad_bolsas" para="bolsas"
                   :ayuda="esCritica ? 'Acumulación crítica (3 o más bolsas).' : 'Entre 0 y 50.'">
          <input id="bolsas" v-model="form.cantidad_bolsas" type="number" inputmode="numeric" min="0" max="50" step="1" />
        </CampoForm>
        <CampoForm etiqueta="Clima" :error="errores.clima" para="clima">
          <select id="clima" v-model="form.clima">
            <option value="">Sin indicar</option>
            <option v-for="(t, v) in CLIMAS" :key="v" :value="v">{{ t }}</option>
          </select>
        </CampoForm>

        <CampoForm class="ancho" etiqueta="Descripción" requerido :error="errores.descripcion" para="descripcion"
                   :ayuda="`${form.descripcion.length}/300`">
          <textarea id="descripcion" v-model="form.descripcion" maxlength="300" placeholder="Bolsas en el piso..."></textarea>
        </CampoForm>
      </div>

      <div class="acciones" style="margin-top: 16px">
        <button class="btn btn-primario" type="submit" :disabled="guardado.cargando.value">
          {{ guardado.cargando.value ? 'Guardando...' : idEdicion ? 'Guardar corrección' : 'Guardar registro' }}
        </button>
        <RouterLink :to="idEdicion ? `/registros/${idEdicion}` : '/registros'" class="btn">Cancelar</RouterLink>
      </div>
    </form>
  </div>
</template>
