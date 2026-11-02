import { ref } from 'vue'
import { traducirError } from '@/utils/errores'

// Estado de una operación: cargando, mensaje de éxito y de error.
export function useOperacion() {
  const cargando = ref(false)
  const exito = ref('')
  const error = ref('')

  async function ejecutar(fn, mensajeExito = '') {
    cargando.value = true
    exito.value = ''
    error.value = ''
    try {
      const resultado = await fn()
      exito.value = mensajeExito
      return { ok: true, resultado }
    } catch (e) {
      error.value = traducirError(e)
      return { ok: false, error: e }
    } finally {
      cargando.value = false
    }
  }

  function limpiar() {
    exito.value = ''
    error.value = ''
  }

  return { cargando, exito, error, ejecutar, limpiar }
}
