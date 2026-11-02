import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { PERFILES } from '@/utils/catalogos'

// Estado global de la sesión y del perfil del usuario
const sesion = ref(null)
const perfil = ref(null)
let listo = null

async function cargarPerfil() {
  if (!sesion.value) {
    perfil.value = null
    return
  }
  const { data, error } = await supabase
    .from('perfiles')
    .select('id, email, nombre, apellido, curso, comision, perfil, activo')
    .eq('id', sesion.value.user.id)
    .maybeSingle()
  if (error) throw error
  perfil.value = data
}

function iniciar() {
  if (!listo) {
    listo = (async () => {
      const { data } = await supabase.auth.getSession()
      sesion.value = data.session
      try {
        await cargarPerfil()
      } catch (e) {
        console.error(e)
      }
      supabase.auth.onAuthStateChange((evento, nueva) => {
        const cambioUsuario = nueva?.user?.id !== sesion.value?.user?.id
        sesion.value = nueva
        if (cambioUsuario) cargarPerfil().catch(console.error)
      })
    })()
  }
  return listo
}

export function useAuth() {
  const rol = computed(() => (perfil.value?.activo ? perfil.value.perfil : null))
  const nombreRol = computed(() => PERFILES[rol.value] || 'Sin perfil asignado')
  const nombreCompleto = computed(() =>
    [perfil.value?.nombre, perfil.value?.apellido].filter(Boolean).join(' ') || perfil.value?.email || ''
  )

  function puede(...perfiles) {
    return perfiles.includes(rol.value)
  }

  async function ingresar(email, clave) {
    const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password: clave })
    if (error) throw error
    const { data } = await supabase.auth.getSession()
    sesion.value = data.session
    await cargarPerfil()
  }

  async function salir() {
    await supabase.auth.signOut()
    sesion.value = null
    perfil.value = null
  }

  async function cambiarClave(nueva) {
    const { error } = await supabase.auth.updateUser({ password: nueva })
    if (error) throw error
  }

  return {
    sesion, perfil, rol, nombreRol, nombreCompleto,
    iniciar, ingresar, salir, cambiarClave, cargarPerfil, puede
  }
}
