import { createRouter, createWebHistory } from 'vue-router'
import { useAuth } from '@/composables/useAuth'

const TODOS = ['relevador', 'ambiental', 'administracion', 'tecnologia', 'docente']

const routes = [
  { path: '/ingreso', name: 'ingreso', component: () => import('@/views/LoginView.vue'), meta: { publica: true, titulo: 'Ingreso' } },
  { path: '/sin-perfil', name: 'sin-perfil', component: () => import('@/views/SinPerfilView.vue'), meta: { sinPerfil: true, titulo: 'Cuenta sin perfil' } },
  { path: '/mi-cuenta', name: 'mi-cuenta', component: () => import('@/views/MiCuentaView.vue'), meta: { sinPerfil: true, titulo: 'Mi cuenta' } },

  { path: '/', name: 'inicio', component: () => import('@/views/InicioView.vue'), meta: { perfiles: TODOS, titulo: 'Inicio' } },
  { path: '/:pathMatch(.*)*', redirect: '/' }
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior: () => ({ top: 0 })
})

// Guardas: repiten en la navegación las mismas reglas que aplica la base.
router.beforeEach(async (to) => {
  const { iniciar, sesion, rol } = useAuth()
  await iniciar()

  if (to.meta.publica) return sesion.value ? '/' : true
  if (!sesion.value) return { name: 'ingreso', query: to.fullPath !== '/' ? { volver: to.fullPath } : {} }
  if (to.meta.sinPerfil) return true
  if (!rol.value) return { name: 'sin-perfil' }
  if (to.meta.perfiles && !to.meta.perfiles.includes(rol.value)) return { name: 'inicio' }
  return true
})

router.afterEach((to) => {
  document.title = to.meta.titulo ? `${to.meta.titulo} · EcoSegura` : 'EcoSegura'
})

export default router
