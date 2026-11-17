// Menú según el perfil. Las mismas reglas están en las rutas y en la base.
export const MENU = [
  { ruta: '/', texto: 'Inicio', icono: 'inicio', perfiles: ['relevador', 'ambiental', 'administracion', 'tecnologia', 'docente'] },
  { ruta: '/registros/nuevo', texto: 'Nuevo registro', icono: 'mas', perfiles: ['relevador'] },
  { ruta: '/registros', texto: 'Registros', icono: 'lista', perfiles: ['relevador', 'ambiental', 'administracion', 'tecnologia', 'docente'] },
  { ruta: '/reciclables', texto: 'Reciclables', icono: 'reciclar', perfiles: ['relevador', 'ambiental', 'administracion', 'tecnologia', 'docente'] },
  { ruta: '/estadisticas', texto: 'Estadísticas', icono: 'grafico', perfiles: ['relevador', 'ambiental', 'administracion', 'tecnologia', 'docente'] },
  { ruta: '/tablero', texto: 'Tablero', icono: 'tablero', perfiles: ['ambiental', 'administracion', 'tecnologia', 'docente'] },
  { ruta: '/seguimiento', texto: 'Seguimiento', icono: 'seguimiento', perfiles: ['ambiental', 'administracion', 'tecnologia', 'docente'] },
  { ruta: '/informes', texto: 'Informes', icono: 'informe', perfiles: ['ambiental', 'administracion', 'tecnologia', 'docente'] },
  { ruta: '/actas', texto: 'Actas', icono: 'acta', perfiles: ['relevador', 'ambiental', 'administracion', 'tecnologia', 'docente'] },
  { ruta: '/movimientos', texto: 'Recursos y gastos', icono: 'dinero', perfiles: ['relevador', 'ambiental', 'administracion', 'tecnologia', 'docente'] },
  { ruta: '/usuarios', texto: 'Usuarios', icono: 'usuarios', perfiles: ['administracion', 'tecnologia', 'docente'] },
  { ruta: '/lugares', texto: 'Lugares', icono: 'lugar', perfiles: ['tecnologia'] }
]

export function menuPara(perfil) {
  return MENU.filter((m) => m.perfiles.includes(perfil))
}
