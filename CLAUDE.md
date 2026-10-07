# App Gym Cíclico — contexto para Claude

Fuente completa: documento "Traspaso — App Gym Cíclico" (claude.ai/artifact/UuMC7JokKepKuCanEWDGXA). Esto es el resumen operativo.

## Qué es
App web de entrenamiento para las clientas de Gym Cíclico (Brayan Pedraza): entrenar mujeres según su ciclo hormonal. En producción con usuarias reales (8 presenciales, 1 Compañía: Yeraldine Melo, 0 Corona). El Club (Skool) NO usa esta app.

## Archivos y despliegue
- `app.html` — app de clientas (pestañas Hoy, Ciclo, Rutinas, Medidas). Contiene el motor de ciclo. En uso.
- `admin1.html` — panel del entrenador (Clientas, Programas, Motor, Grupos, Nueva clienta). En uso. Antes se descargaba como `admin.html` y había que renombrarlo: en el repo SIEMPRE es `admin1.html`.
- `index.html` — landing legado, no se toca.
- Hosting: GitHub Pages (`brayanpedrazatrainer.github.io/App-/app.html` y `/admin1.html`). Sin build: hacer push = desplegar. La caché tarda 1–5 min; verificar en incógnito con Ctrl+Shift+R.
- Stack: HTML autocontenido (CSS + JS inline) + Supabase por CDN. Proyecto Supabase `brqojlcdtzmqfurztbnm` (App-Entrenamiento); la anon key pública está embebida.

## Patrón interno
Estado global `S`, `set(u)` = `Object.assign(S,u)` + `render()`, funciones `rAlgo()` que devuelven strings HTML. Cada `set()` repinta toda la pantalla.

Funciones clave `app.html`: `calcularTarjetaMotor`, `mapearFaseLunar`, `getCurrentFase`, `rHoy`, `rSess`, `sH` (series con semáforo + nivel), `efClick`, `tSet`, `limpiarNombre`.
Funciones clave `admin1.html`: `calcMotorPhase` (copia del motor), `generarMes`, `saveGeneratedRows`, `borrarMes`, `rGrupos`/`saveGrupo`/`asignarGrupo`, `editExById`/`saveExercise`.

## Supabase
- Tablas heredadas: profiles, programs, sessions, exercises, client_programs, exercise_completions, scheduled_sessions, cycle_logs, symptom_logs, meno_logs, measurements.
- Tablas del motor: plantillas (lunar, energia), plantilla_tarjetas (28 por plantilla: fase+orden → session_id, tipo, arquetipo, carga alta|media|tecnica), equivalencias (patron + escenario A/B/C → exercise_id), checkins (energia, animo, molestias, sueno 1–3, semaforo; único client_id+fecha), carga_log (exercise_id uuid; único client_id+exercise_id+fecha+fase para UPSERT), grupos.
- profiles: plan (presencial|corona|compania), ruta (lunar|energia), sub_perfil, nivel 1–3 (def 2), duracion_ciclo (def 28), ancla, escenario_default (def C), dias_presenciales text[], grupo_id, dias_clase.
- exercises: bloque 1–5, patron, carga_pct (solo admin), carga_kg, tempo, cue. `order_index` es BIGINT: no volver a smallint.
- Seguridad (migración `supabase/migracion_seguridad_2026-09-27.sql`, rollback al lado): RLS activo en TODAS las tablas de `public`.
  - Datos de clienta (checkins, carga_log, cycle_logs, symptom_logs, meno_logs, measurements, exercise_completions, scheduled_sessions): cada clienta gestiona los suyos; el admin lee todo.
  - profiles: clienta lee y actualiza solo el suyo, y el trigger `proteger_perfil` solo le deja cambiar `ancla`. Admin todo. Insert/delete solo admin.
  - programs, sessions, exercises, plantillas, plantilla_tarjetas, equivalencias, grupos: lectura para cualquier autenticada; escritura solo admin.
  - Admin real = `profiles.is_admin` vía la función `is_admin()` (SECURITY DEFINER). `handle_new_user` siempre crea `is_admin=false`.
  - Si una función nueva de la app escribe en otra tabla o columna, hay que añadir la política correspondiente.
  - Plan gratuito de Supabase: "Leaked password protection" no disponible.
- En carga_log se usa `auth.jwt() ->> 'email'` (mejor que `auth.email()`).
- El panel admin también compara el email en el código (brayanpedrazatrainer@gmail.com). Alta de clientas con `sb.auth.signUp()`; luego confirmar el correo en Supabase → Authentication → Users.

## Reglas de producto (no romper)
- **Regla de oro:** nunca borrar ni modificar filas de `scheduled_sessions` puestas a mano. Desde octubre 2026 el motor sí escribe el calendario mensual, y cada fila lleva `origen`:
  - `manual` (default; todo lo anterior a oct 2026 y lo que Brayan cambie en el generador): intocable.
  - `motor`: generada por `generar_motor(client, desde, hasta)` en Supabase. "Me llegó el período" llama `regenerar_motor(client, hoy)`, que borra y recalcula solo las filas `motor` + `pending` desde hoy hasta la última fecha generada.
  - La lógica de fases vive duplicada en `generar_motor` (SQL), `calcMotorPhase` (admin) y `calcularTarjetaMotor` (app). En ruta lunar, SQL y admin proyectan ciclos (`dc = dias % dur + 1`); la app sin fila sigue en menguante_b si el período se atrasa. Si se cambia una, cambiar las demás.
  - La app agrega a `PROG` las sesiones agendadas que no están en el programa asignado (las del motor vienen de los programas plantilla de Gina y Camila).
- Dos rutas: lunar (ciclo regular sin anticonceptivos, 5 fases sobre la duración real) y energia (anticonceptivos, irregular, peri/menopausia: bloque fijo de 4 semanas). 56 tarjetas en total.
- Ciclos ≠ 28: luna_nueva anclada al inicio (días 1–5); llena, menguante_a y menguante_b ancladas al final; creciente absorbe la diferencia; si faltan tarjetas, el orden rota con módulo.
- Toda sesión del motor tiene calentamiento y cierre (desde 2026-10-01, `supabase/calentamiento_y_cierre_2026-10-01.sql`): Movilidad articular suave (calentamiento, bloque 1), trabajo principal (order_index 11+, bloque 3), Recuperación muscular (cierre, bloque 5, order_index 99). El Blindaje articular (+ Ejercicios 1-7) va SOLO en Recuperación Activa: Brayan lo corrigió el 2026-10-01; no agregar bloques a las sesiones sin preguntarle qué lleva cada uno. El semáforo rojo deja solo 1, 2 y 5.
- Series/reps se muestran con `textoSeries(n, reps_range)`: "3 series de 10 a 12 repeticiones" + chips (peso, intensidad sin RPE, "Descansa 90 segundos") + avisos ⚠. No mostrar "3×10–12" ni RPE a las clientas. Los bloques 1, 2 y 5 no cambian series por nivel ni semáforo y no piden esfuerzo.
- Nivel: 1 = una serie menos, 2 = igual, 3 = una más; mínimo 1; no aplica en recuperación activa ni en calentamiento/cierre. Se acumula con el semáforo.
- Semáforo: check-in de 4 preguntas 1–3 (en molestias el 3 es malo). Amarillo = una serie menos; rojo = solo bloques 1, 2 y 5. **La clienta nunca ve explicaciones del ajuste**; el badge dice solo "Check-in de hoy registrado ✓". Existe "Me siento mejor / peor" para moverlo un escalón.
- Esfuerzo con palabras: Sobrada / Justa / Al límite (nunca números). Siguiente ciclo en la misma fase: sobrada sube un escalón; justa y al límite mantienen.
- Escenarios A "Solo cuerpo" (no "Casa": en casa puede haber mancuernas) / B "Mancuernas" (y bandas) / C "Gimnasio": el botón significa "dónde entreno hoy". Tabla `variantes` (familia + escenario → nombre, video, descripción) y columnas `exercises.familia` / `exercises.equipo` (cuerpo|mancuernas|banda|gimnasio). Regla de Brayan (2026-10-02): Gimnasio = lo programado tal cual (ahí se puede mezclar todo); Mancuernas = solo cambia lo de máquina/barra; Solo cuerpo = cambia mancuernas y máquina/barra, la banda se queda. Sin versión para ese escenario → se muestra lo programado. Se conservan series/reps/tempo/cue; el peso programado no se sugiere para el reemplazo. `equivalencias` quedó obsoleta (la app ya no la lee). Desde 2026-10-02 las sesiones programan "Jalón en máquina", "Press militar con mancuernas" y "Remo con barra" (equipo gimnasio) en lugar de jalón con banda / press sentada / remo a una mano; en Mancuernas vuelven a esas versiones. Si falta la versión A de algo de gimnasio, Solo cuerpo usa la B (jalón → con banda). En Solo cuerpo la banda también cambia si existe versión A (jalón → toalla, pallof → con mano). OJO: toda tabla nueva necesita `grant ... to authenticated`, si no la app falla en silencio (pasó con variantes). Faltan: zancada y press de pecho de gimnasio. `exListSesion(sess)` es la única fuente de la lista; rSess y rVid la comparten.
- Compañía/Corona en día de clase: solo el botón de Zoom; "No puedo asistir — hacer la sesión sola" abajo, sin protagonismo.
- Descartado: plan Brújula; "escolta" (ahora Compañía; si aparece es residuo); 168 tarjetas; motor en Postgres; indicador verde/rojo en la vista comparativa.
- Diseño: paleta en la constante `C`; rojo de marca sobre negro cálido, mobile-first; colores de fase en `FASE_INFO` / `FASE_LABELS`. Trato "reina".

## Textos que ve la clienta
- Público: mujer que NO está entrenando; ha empezado muchas veces y lo ha dejado. Prohibido asumir rutina en curso, historial o constancia. Se habla de sus arranques. No es principiante absoluta.
- Brayan escribe como hombre que entiende a las mujeres: nunca en primera persona femenina ni "todas estamos".
- Frases cortas y largas mezcladas, lenguaje cercano, sin contraste "no x sino y", sin palabras técnicas sin explicar ("cíclica", "lineal"). Imágenes coloquiales. "Reina", "¿cierto?".
- Método: "La fase no cambia el patrón. Cambia la intención." 7 patrones; 5 sesiones + 2 de recuperación activa por semana. Bloques: 1 Activación articular, 2 Activación neuromuscular, 3 Trabajo principal, 4 Cardio metabólico, 5 Cierre y recuperación. Tonificar requiere tensión real (65–90% 1RM). Primera sesión de clienta nueva: sin carga externa. En luna llena no llevar la flexibilidad al límite.
- Fases lunares: nueva 1–5 Reconectar 40–50%; creciente 6–13 Construir 70–80%; llena 14–16 Expresar 80–90%; menguante A 17–23 Integrar 65–75%; menguante B 24–28 Sostener 50–60%. Ruta energía: semanas Resistir, Forjar, Conquistar, Blindar.

## Trampas técnicas — revisar en cada cambio
1. Comillas anidadas en `onclick` generados por concatenación: el botón queda muerto sin error. Pasar datos con `data-` + `this.dataset`, o interpolar ids numéricos sin comillas.
2. Reemplazos grandes que borran funciones vecinas (`doLogin`, `loadData`, `doAddClient`…). Después de editar, comprobar que ninguna función llamada haya desaparecido.
3. No usar `\w` en regex (rompe tildes y ñ): usar `limpiarNombre(s)`.
4. `Promise.all` que cuelga el loading: usar consultas secuenciales, try/catch por bloque y un catch final que apague `loading`. Usar `.maybeSingle()` si la fila puede no existir.
5. Joins anidados de Supabase (`plantillas!inner(...)`) se cuelgan: partir en consultas simples.
6. Nunca llamar funciones async que hagan `set()` dentro de un `rAlgo()`: el repintado borra el input. Cargar datos en `loadData()` o al cambiar de pestaña.
7. `<script>` duplicado: cada archivo debe tener exactamente 2 (CDN de Supabase + el propio).
8. `reps_range` ya trae "reps" ("10–12 reps · Ligera / RPE 6 · 90s desc"): no concatenar " reps"; se corta por "·".

## Pendientes
- Datos (Brayan): rellenar `bloque` 1–5 en ejercicios (sin eso el semáforo rojo no filtra); falta `patron` en algunos ejercicios; anclas de Lorena y Nubia; días/hora del grupo "Clase prueba" de Yeraldine; generar octubre para las 8 presenciales; verificar a Yeraldine con escenario B.
- Octubre 2026 generado (origen motor) para todas menos Carolina (Brayan confirma su último período). Nubia: ruta lunar con sub_perfil perimenopausia mientras su ciclo siga regular; si se vuelve irregular, pasarla a energía. Generar con `select generar_motor('<id>', '2026-10-01', '2026-10-31')`.
- Bloque 1 (calentamiento) llevará también blindaje articular cuando Brayan grabe la secuencia; por ahora solo Movilidad (se mantiene "8–10 min" aunque el video dure menos). Cierre: queda "Recuperación muscular" hasta que grabe la recuperación. Cuando mande los videos, preguntarle la lista exacta antes de cargarla en las 29 sesiones.
- Videos: prensa horizontal, press en suelo, pullover en suelo, blindaje articular (bloque 1), recuperación muscular (bloque 5), y sobre todo escenario A (casa).
- Producto: alertas en admin (duracion_ciclo fuera de 24–35 en 3 ciclos, 3 semáforos rojos en una semana, 40 días sin período en ruta lunar); registro "Asistí a la clase".

## Variabilidad de las Principales (2026-10-07, `supabase/variabilidad_principales_2026-10-07.sql`)
- Energía: cada semana tiene su sesión; los ejercicios rotan por semana (Resistir/Forjar/Conquistar/Blindar) manteniendo el número de ejercicios. P2 semanas 2-3 = gimnasio; semanas 1 y 4 = flexión, remo solo cuerpo/mancuerna, press sentada, jalón toalla/banda.
- Lunar: se clonaron Principal A (creciente#5 y menguante_a#4), B (creciente#6) y C (creciente#7) en el programa de Camila y se re-apuntaron esas tarjetas. Las clientas lunares se regeneraron con `regenerar_motor` desde el 2026-10-07.
- Bloque 4 (cardio, order_index 50): 3 rondas de 30 s. `exercises.impacto = 'alto'` (skipping, jumping jacks) → la app lo cambia por la variante `bajo_impacto_A` (Caminata con levantamiento de talones) si sub_perfil es perimenopausia o menopausia.
- Bloque 1: Movilidad bajó a "4–5 min" en sesiones de entrenamiento + 2-3 ejercicios de blindaje (bloque 2, order 2-4) según el tipo de día (inferior/superior/completo). Recuperación Activa: + 5 de blindaje ligero (rodilla/cadera) en order 10-14.
- Los 13 videos "movilidad y/o fortalecimiento" se nombraron viéndolos (nombres propuestos por Claude, Brayan puede corregirlos).
