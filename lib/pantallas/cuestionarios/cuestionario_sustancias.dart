import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme_provider.dart';
import '../principal.dart';
import '../servicios/user.dart';

import 'aviso_envio_fallido.dart';
import 'envio_cuestionario.dart';
import 'respuestas_cuestionario_sustancias.dart';

class CuestionarioSustancias extends StatefulWidget {
  const CuestionarioSustancias({super.key});

  @override
  State<CuestionarioSustancias> createState() =>
      _CuestionarioSustanciasState();
}

class _CuestionarioSustanciasState
  extends State<CuestionarioSustancias> {
    final Map<String, Map<String, dynamic>> _respuestas = {};
    bool _enviando = false;
    bool _cargandoPreguntas = true;
    int _bloqueActual = 0;
    late List<Map<String, dynamic>> _preguntas =
    List<Map<String, dynamic>>.from(_defaultPreguntas);

    // Listado de bloques con preguntas *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~

    static const List<Map<String, dynamic>> _defaultPreguntas = [
      {
        'id': 'B1',
        'numero': 1,
        'bloque': 'PreguntasBloque1',
        'bloque_nombre': 'Primer consumo',
        'tipo': 'RespuestasB1',
        'pregunta':
            'A lo largo de su vida, ¿cual de las siguientes sustancias ha consumido alguna vez?  (SOLO PARA USOS NO-MÉDICOS)',
      },{
        'id': 'B2',
        'numero': 2,
        'bloque': 'PreguntasBloque2',
        'bloque_nombre': 'Frecuencia de consumo',
        'tipo': 'RespuestasB2',
        'pregunta':
            '¿Con qué frecuencia ha consumido las sustancias que ha mencionado en los últimos tres meses, (PRIMERA DROGA, SEGUNDA DROGA, ETC)? ',
      },{
        'id': 'B3',
        'numero': 3,
        'bloque': 'PreguntasBloque3',
        'bloque_nombre': 'Deseo y ansiedad de consumir',
        'tipo': 'RespuestasB3',
        'pregunta':
            'En los últimos tres meses, ¿con qué frecuencia ha tenido deseos fuertes o ansias de consumir (PRIMERA DROGA, SEGUNDA DROGA, ETC)? ',
      },{
        'id': 'B4',
        'numero': 4,
        'bloque': 'PreguntasBloque4',
        'bloque_nombre': 'Problemas sociales por consumo',
        'tipo': 'RespuestasB4',
        'pregunta':
            'En los últimos tres meses, ¿con qué frecuencia le ha llevado su consumo de (PRIMERA DROGA, SEGUNDA DROGA, ETC) a problemas de salud, sociales, legales o económicos? ',
      },{
        'id': 'B5',
        'numero': 5,
        'bloque': 'PreguntasBloque5',
        'bloque_nombre': 'Irresponsabilidad por consumo',
        'tipo': 'RespuestasB5',
        'pregunta':
            'En los últimos tres meses, ¿con qué frecuencia dejó de hacer lo que se esperaba de usted habitualmente por el consumo de (PRIMERA DROGA, SEGUNDA DROGA, ETC)?',
      },{
        'id': 'B6',
        'numero': 6,
        'bloque': 'PreguntasBloque6',
        'bloque_nombre': 'Preocupación de mi círculo social',
        'tipo': 'RespuestasB6B7',
        'pregunta':
            '¿Un amigo, un familiar o alguien más alguna vez ha mostrado preocupación por su consume de (PRIMERA DROGA, SEGUNDA DROGA, ETC)?',
      },{
        'id': 'B7',
        'numero': 7,
        'bloque': 'PreguntasBloque7',
        'bloque_nombre': 'Abstinencia',
        'tipo': 'RespuestasB6B7',
        'pregunta':
            '¿Ha intentado alguna vez controlar, reducir o dejar de consumir (PRIMERA DROGA, SEGUNDA DROGA, ETC) y no lo ha logrado?',
      },{
        'id': 'B8',
        'numero': 8,
        'bloque': 'PreguntasBloque8',
        'bloque_nombre': 'Inyecciones',
        'tipo': 'RespuestasB8',
        'pregunta':
            '¿Ha consumido alguna vez alguna droga por vía inyectada? (ÚNICAMENTE PARA USOS NO MÉDICOS) ',
      },
    ];

    // Tipos de respuestas *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~

    static const Map<String, List<Map<String, dynamic >>> tiposRespuesta = {
      'RespuestasB1': RespuestasCuestionario.respuestasB1,
      'RespuestasB2': RespuestasCuestionario.respuestasB2,
      'RespuestasB3': RespuestasCuestionario.respuestasB3,
      'RespuestasB4': RespuestasCuestionario.respuestasB4,
      'RespuestasB5': RespuestasCuestionario.respuestasB5,
      'RespuestasB6B7': RespuestasCuestionario.respuestasB6B7,
      'RespuestasB8': RespuestasCuestionario.respuestasB8,
    };

    // Nombre de los bloques *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~

    static const Map<String, String> nombresBloques = {
      'PreguntasBloque1': 'Primer consumo',
      'PreguntasBloque2': 'Frecuencia de consumo',
      'PreguntasBloque3': 'Deseo y ansiedad de consumir',
      'PreguntasBloque4': 'Problemas sociales por consumo',
      'PreguntasBloque5': 'Irresponsabilidad por consumo',
      'PreguntasBloque6': 'Preocupación de mi círculo social',
      'PreguntasBloque7': 'Abstinencia',
      'PreguntasBloque8': 'Inyecciones',
    };

    // Listado de sustancias *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~

    static const List<Map<String, String>> sustancias = [{
        'id': 'tabaco',
        'nombre':
            'Tabaco (cigarrillos, cigarros habanos, tabaco de mascar, pipa, etc.)',
      },{
        'id': 'alcohol',
        'nombre':
            'Bebidas alcohólicas (cerveza, vino, licores, destilados, etc.)',
      },{
        'id': 'cannabis',
        'nombre':
            'Cannabis (marihuana, costo, hierba, hashish, etc.)',
      },{
        'id': 'cocaina',
        'nombre':
            'Cocaína (coca, farlopa, crack, base, etc.)',
      },{
        'id': 'anfetaminas',
        'nombre':
            'Anfetaminas u otro tipo de estimulantes (speed, éxtasis, píldoras adelgazantes, etc.)',
      },{
        'id': 'inhalantes',
        'nombre':
            'Inhalantes (colas, gasolina/nafta, pegamento, etc.)',
      },{
        'id': 'tranquilizantes',
        'nombre':
            'Tranquilizantes o pastillas para dormir (Valium/Diazepam, Trankimazin/Alprazolam/Xanax, Orfidal/Lorazepam, Rohipnol, etc.)',
      },{
        'id': 'alucinogenos',
        'nombre':
            'Alucinógenos (LSD, ácidos, ketamina, PCP, etc.)',
      },{
        'id': 'opiaceos',
        'nombre':
            'Opiáceos (heroína, metadona, codeína, morfina, dolantina/petidina, etc.)',
      },
    ];

    @override
    void initState() {
      super.initState();
      _loadPreguntas();
    }
    
    // Carga desde el servidor, aún no disponible *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~ 

    Future<void> _loadPreguntas() async {
      try {
        final result = await User().getCuestionarioConfig(
          modulo: 'sustancias',
        );

        if (!mounted) return;

        final data = result['data'];
        final rawQuestions =
            data is Map ? data['preguntas'] : null;

        if (result['success'] == true &&
            rawQuestions is List &&
            rawQuestions.isNotEmpty) {
          final defaultsById = {
            for (final question in _defaultPreguntas)
              question['id'].toString():Map<String, dynamic>.from(question),
          };

          final loaded = rawQuestions.whereType<Map>().map<Map<String, dynamic>>((raw) {
            final codigo = raw['codigo']?.toString() ?? '';
            final base = defaultsById[codigo] ?? 
                        <String, dynamic>{};
            final bloque = raw['bloque']?.toString() ??
                          base['bloque']?.toString() ??
                          'PreguntasBloque1';
            final bloqueNombre = raw['bloque_nombre']?.toString() ??
                                  base['bloque_nombre']?.toString() ??
                                  nombresBloques[bloque] ??
                                  bloque;
            final tipo = raw['tipo_respuesta']?.toString() ??
                          base['tipo']?.toString() ??
                          'RespuestasB1';

            final pregunta = raw['pregunta']?.toString() ??
                            base['pregunta']?.toString() ??
                            '';

            final numero = raw['numero'] is int ? 
                          raw['numero'] as int: 
                          int.tryParse(raw['numero']?.toString() ?? '',) ??
                          0;

            final puntaje = raw['puntaje'] is int ? 
                            raw['puntaje'] as int : 
                            int.tryParse(raw['puntaje']?.toString() ?? '',) ??
                            0;

            return {
              ...base,
              'id': codigo.isNotEmpty
                ? codigo
                : base['id']?.toString() ?? '',
              'numero': numero,
              'bloque': bloque,
              'bloque_nombre': bloqueNombre,
              'tipo': tipo,
              'pregunta': pregunta,
              'puntaje': puntaje,
            };
          }).where( 
            (question) => (question['id']?.
              toString() ?? '').isNotEmpty, 
            ).toList();

          loaded.sort(
            (a, b) => (a['numero'] as int).compareTo(b['numero'] as int),
          );

          if (loaded.isNotEmpty) {
            setState(() {
              _preguntas = loaded;
              _cargandoPreguntas = false;
            });

            return;
          }
        }
      } catch (e) {
        debugPrint(
          'Error cargando preguntas de sustancias: $e',
        );
      }

      if (!mounted) return;

      setState(() {
        _cargandoPreguntas = false;
      });
    }

    List<String> get _bloques {
      final bloques = <String>[];

      for (final pregunta in _preguntas) {
        final bloque =pregunta['bloque']?.toString() ?? '';
        if (bloque.isNotEmpty &&
          !bloques.contains(bloque)) {
          bloques.add(bloque);
        }
      }

      return bloques;
    }

    List<Map<String, dynamic>> get _preguntasActuales {
      if (_bloques.isEmpty ||
          _bloqueActual >= _bloques.length) {
        return [];
      }

      final bloque = _bloques[_bloqueActual];

      return _preguntas
          .where(
            (pregunta) =>
                pregunta['bloque']?.toString() ==
                bloque,
          )
          .toList();
    }

    String get _nombreBloqueActual {
      if (_preguntasActuales.isEmpty) {
        return 'Cuestionario';
      }

      return _preguntasActuales.first[
                  'bloque_nombre']
              ?.toString() ??
          nombresBloques[
              _preguntasActuales.first['bloque']
                  ?.toString()] ??
          'Cuestionario';
    }

    void _guardarRespuesta(
      String preguntaId,
      Map<String, dynamic> pregunta,
      Map<String, String> sustancia,
      int valor,
      String etiqueta,
    ) {
      final sustanciaId = sustancia['id']!;

      final respuestaId =
          '${preguntaId}_$sustanciaId';

      setState(() {
        _respuestas[respuestaId] = {
          'id': respuestaId,
          'pregunta_id': preguntaId,
          'sustancia_id': sustanciaId,
          'sustancia': sustancia['nombre'],
          'bloque': pregunta['bloque'],
          'bloque_nombre': pregunta['bloque_nombre'],
          'pregunta': pregunta['pregunta'],
          'tipo_respuesta': pregunta['tipo'],
          'respuesta_valor': valor,
          'respuesta_etiqueta': etiqueta,
        };
      });
    }

    bool _bloqueCompleto() {
      if (_preguntasActuales.isEmpty) {
        return false;
      }

      final pregunta = _preguntasActuales.first;
      final preguntaId = pregunta['id']?.toString() ?? '';

      if (preguntaId.isEmpty) {
        return false;
      }

      for (final sustancia in sustancias) {
        final sustanciaId = sustancia['id']!;

        final respuestaId = '${preguntaId}_$sustanciaId';

        if (!_respuestas.containsKey(
          respuestaId,
        )) {
          return false;
        }
      }

      return true;
    }

    int _buscarBloque(String nombreBloque) {
      return _bloques.indexWhere(
        (bloque) => bloque == nombreBloque,
      );
    }

    bool _todasSonNunca() {
      if (_preguntasActuales.isEmpty) {
        return false;
      }

      final preguntaId = _preguntasActuales.first['id']?.toString() ?? '';

      if (preguntaId.isEmpty) {
        return false;
      }

      for (final sustancia in sustancias) {
        final sustanciaId = sustancia['id']!;
        final respuestaId = '${preguntaId}_$sustanciaId';
        final respuesta = _respuestas[respuestaId];
        if (respuesta == null) {
          return false;
        }
        final etiqueta = respuesta['respuesta_etiqueta'] ?.toString().toLowerCase().trim() ?? '';
        if (!etiqueta.contains('nunca')) {
          return false;
        }
      }

      return true;
    }

    // Método para comprobar si todas las respestas del bloque 1 son 'No'
    // De ser así, finaliza el cuestionario

    bool _todasSonNo() {
      if (_preguntasActuales.isEmpty) {
        return false;
      }

      final preguntaId = _preguntasActuales.first['id'] ?.toString() ?? '';

      if (preguntaId.isEmpty) {
        return false;
      }

      for (final sustancia in sustancias) {
        final sustanciaId = sustancia['id']!;
        final respuestaId = '${preguntaId}_$sustanciaId';
        final respuesta =  _respuestas[respuestaId];
        if (respuesta == null) {
          return false;
        }
        final etiqueta = respuesta['respuesta_etiqueta']?.toString().toLowerCase().trim() ?? '';
        if (etiqueta != 'no') {
          return false;
        }
      }

      return true;
    }

    Future<void> _avanzarBloque() async {
      if (!_bloqueCompleto()) { _mostrarMensaje(
          'Responde a todas las sustancias antes de avanzar.',
        );
        return;
      }

      // *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~
      // Bloque 1. Si todas las sustancias tienen "No",
      // se termina el cuestionario.
      // *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~

      if (_bloqueActual < _bloques.length &&
          _bloques[_bloqueActual] ==
              'PreguntasBloque1') {
        if (_todasSonNo()) {
          await _finalizarYEnviar();
          return;
        }
      }

      // *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~
      // Bloque 2. Si todas las respuestas son "Nunca",
      // se salta directamente al bloque 6.
      // *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~

      if (_bloqueActual < _bloques.length &&
          _bloques[_bloqueActual] ==
              'PreguntasBloque2') {
        if (_todasSonNunca()) {
          final indiceBloque6 =
              _buscarBloque(
            'PreguntasBloque6',
          );

          if (indiceBloque6 != -1) {
            setState(() {
              _bloqueActual = indiceBloque6;
            });

            return;
          }
        }
      }

      // *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~
      // Si no se cumple ninguna de las dos condiciones pasadas,
      // se continua con el flujo normal de las preguntas
      // *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~

      if (_bloqueActual < _bloques.length - 1) {
        setState(() {
          _bloqueActual++;
        });
        return;
      }

      await _finalizarYEnviar();
    }

    // Lógica para volver atrás 
    //Comentado para evitar problemas con el caso de "Bloque 2 salta a Bloque 6"
    /* void _retrocederBloque() {
      if (_bloqueActual <= 0) {
        return;
      }

      setState(() {
        _bloqueActual--;
      });
    }
    */ 

    Map<String, int> _calcularPuntajesPorSustancia() {
      final Map<String, int> puntajes = {};

      for (final sustancia in sustancias) {
        final id = sustancia['id']!;
        final nombre = sustancia['nombre']!;
        puntajes[nombre] = 0;
      }

      for (final respuesta in _respuestas.values) {
        final sustanciaId = respuesta['sustancia_id']?.toString();

        if (sustanciaId == null || sustanciaId.isEmpty) {
          continue;
        }

        final sustancia = sustancias.firstWhere(
          (s) => s['id'] == sustanciaId,
          orElse: () => {'id': sustanciaId, 'nombre': sustanciaId},
        );

        final nombre = sustancia['nombre']!;
        final valor = respuesta['respuesta_valor'];
        final puntaje = valor is int
            ? valor
            : int.tryParse(valor?.toString() ?? '') ?? 0;
        puntajes[nombre] =
            (puntajes[nombre] ?? 0) + puntaje;
      }
      return puntajes;
    }

    List<Map<String, dynamic>>
        _crearDatosBloques() {
      final Map<String,List<Map<String, dynamic>>> agrupadas = {};

      for (final respuesta
          in _respuestas.values) {
        final bloque = respuesta['bloque'] ?.toString() ?? '';

        if (bloque.isEmpty) {
          continue;
        }

        agrupadas.putIfAbsent(
          bloque,
          () => [],
        );

        agrupadas[bloque]!
            .add(respuesta);
      }

      return agrupadas.entries.map(
        (entry) {
          final reactivos = List<Map<String, dynamic>>.from( entry.value,);
          int puntuacionTotal = 0;
          for (final reactivo in reactivos) {
            final valor = reactivo['respuesta_valor'];
            if (valor is int) {
              puntuacionTotal += valor;
            }
          }

          final nombre = reactivos.isNotEmpty ? 
                        reactivos.first[ 'bloque_nombre']?.toString():
                        nombresBloques[entry.key] ??
                        entry.key;
          
          return {
            'bloque': entry.key,
            'nombre': nombre,
            'puntuacion_total': puntuacionTotal,
            'reactivos': reactivos,
          };
        },
      ).toList();
    }

    Future<void> _finalizarYEnviar() async {
      if (_enviando) {
        return;
      }

      setState(() {
        _enviando = true;
      });

      final puntajesPorSustancia = _calcularPuntajesPorSustancia();
      final bloques = _crearDatosBloques();
      final payload = {
        'tipo_cuestionario':
            'sustancias',
        'fecha_aplicacion':
            DateTime.now()
                .toUtc()
                .toIso8601String(),
        'puntajes_por_sustancia':
            puntajesPorSustancia,
        'bloques': bloques,
        'respuestas':
            _respuestas.values.toList(),
      };

      bool enviado =
          await EnvioCuestionario.enviar(
        tipo: 'sustancias',
        payload: payload,
      );

      if (!mounted) {
        return;
      }

      while (!enviado) {
        setState(() {
          _enviando = false;
        });

        final esDark = Provider.of<ThemeProvider>(
          context,
          listen: false,
        ).isDarkMode;

        final accion =  await mostrarAvisoEnvioFallido(
          context,
          esDark: esDark,
        );

        if (!mounted) {
          return;
        }

        if (accion == AccionEnvioFallido.continuar) {
          break;
        }

        setState(() {
          _enviando = true;
        });

        enviado = await EnvioCuestionario.enviar(
          tipo: 'sustancias',
          payload: payload,
        );

        if (!mounted) {
          return;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _enviando = false;
      });

      _mostrarResultado(
        puntajesPorSustancia,
      );
    }

    //Método para mostrar los resultados finales de las sustancias
    void _mostrarResultado(
      Map<String, int> puntajesPorSustancia,
    ) {
      final esDark = Provider.of<ThemeProvider>(
        context,
        listen: false,
      ).isDarkMode;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog( backgroundColor:
            esDark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            title: Text(
              'Cuestionario completado',
              style: TextStyle(
                color: esDark
                    ? Colors.white
                    : Colors.black87,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child:
                  SingleChildScrollView(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,
                  children: [
                    Text(
                      'Estos son los puntajes obtenidos por cada sustancia:',
                      style: TextStyle(
                        color: esDark
                          ? Colors.white70
                          : Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 16,),

                    if (puntajesPorSustancia .isEmpty)
                      Text(
                        'No hay puntajes para mostrar.',
                        style: TextStyle(
                          color: esDark
                              ? Colors.white70
                              : Colors.black87,
                        ),
                      ),

                    ...puntajesPorSustancia
                        .entries
                        .map(
                      (entry) {
                        return Padding(
                          padding: const EdgeInsets .only(  
                            bottom: 10,
                          ),
                          child: _ScoreRow(
                            label: entry.key,
                            score: entry.value .toString(),
                            extra: 'Puntuación',
                            color: _colorParaPuntaje( entry.value,),
                            isDark: esDark,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const Principal(),
                    ),
                    (route) => false,
                  );
                },
                child:
                    const Text('Finalizar'),
              ),
            ],
          );
        },
      );
    }


    Color _colorParaPuntaje(
      int puntaje,
    ) {
      if (puntaje == 0) {
        return const Color(0xFF4A704B,);
      }
      if (puntaje <= 3) {
        return const Color(0xFF80A85A,);
      }
      if (puntaje <= 26) {
        return const Color(0xFFE0A72F,);
      }
      return const Color( 0xFFA33E3B,);
    }

    void _mostrarMensaje(
      String mensaje,
    ) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
        ),
      );
    }

    @override
    Widget build(
      BuildContext context,
    ) {
      final theme = Provider.of<ThemeProvider>( context,);
      final isDark = theme.isDarkMode;

      if (_cargandoPreguntas) {
        return Scaffold(
          backgroundColor:
            isDark
              ? const Color(0xFF121212)
              : Colors.white,
          body: const Center(
            child:
              CircularProgressIndicator(),
          ),
        );
      }

      if (_preguntas.isEmpty) {
        return Scaffold(
          backgroundColor:
            isDark
                ? const Color(0xFF121212)
                : Colors.white,
          appBar: AppBar(
            title: const Text('Cuestionario'),
          ),
          body: Center(
            child: Text(
              'No hay preguntas disponibles.',
              style: TextStyle(
                color: isDark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ),
        );
      }

      final preguntas =_preguntasActuales;
      final esUltimoBloque =_bloqueActual >= _bloques.length - 1;
      final pregunta = preguntas.isNotEmpty
        ? preguntas.first
        : <String, dynamic>{};
      final preguntaId = pregunta['id']
        ?.toString() ??
        '';
      final opciones = tiposRespuesta[
        pregunta['tipo']
        ?.toString()] ??
        [];

      return Scaffold(
        backgroundColor:
          isDark
            ? const Color(0xFF121212)
            : Colors.white,
        appBar: AppBar(
          title: Text(
            'Uso de sustancias',
            style: TextStyle(
              color: isDark
                ? Colors.white
                : Colors.black87,
              fontWeight:
                FontWeight.bold,
            ),
          ),
          backgroundColor:
            isDark
              ? const Color(0xFF1E1E1E)
              : Colors.white,
          foregroundColor:
            isDark
              ? Colors.white
              : Colors.black87,
          elevation: 0,
        ),

        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  8,
                ),
                child: Column(crossAxisAlignment:CrossAxisAlignment.stretch,

                  //Nombre del bloque
                  children: [
                    Text(
                      _nombreBloqueActual,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                          FontWeight.bold,
                        color: isDark
                          ? Colors.white
                          : Colors.black87,
                      ),
                    ),
                    Text(
                      pregunta['pregunta'] ?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                          FontWeight.bold,
                        color: isDark
                          ? Colors.white
                          : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6, ),

                    Text(
                      'Bloque ${_bloqueActual + 1} de ${_bloques.length}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                          ? Colors.white60
                          : Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 12,),

                    LinearProgressIndicator(
                      value:_bloques.isEmpty? 0: (_bloqueActual +1) /_bloques.length,
                      minHeight: 6,
                      borderRadius:
                          BorderRadius.circular(10,),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    10,
                    20,
                    20,
                  ),
                  children: [
                    if (preguntas.isNotEmpty)
                      Container(
                        margin:
                          const EdgeInsets.only(
                          bottom: 20,
                        ),
                        padding: const EdgeInsets.all(16,),
                        decoration:
                          BoxDecoration(
                            color: isDark
                              ? const Color( 0xFF1E1E1E, )
                              : const Color( 0xFFF5F5F5, ),
                            borderRadius:
                              BorderRadius.circular(14,),
                          ),
                          child: Column(
                        
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            children: [
                            const SizedBox(height: 20,), 

                            ...sustancias.map(
                              (sustancia) {
                                final sustanciaId =sustancia['id']!;
                                final respuestaId = '${preguntaId}_$sustanciaId';
                                final respuestaActual = _respuestas[respuestaId] ? ['respuesta_valor'];
                                return Container(
                                  margin: const EdgeInsets.only( bottom: 18,),
                                  padding: const EdgeInsets.all(12,),
                                  decoration:
                                    BoxDecoration(color: isDark
                                      ? const Color(0xFF292929,)
                                      : Colors.white,
                                      borderRadius: BorderRadius .circular(12,
                                    ),
                                  ),

                                  child: Column(crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sustancia['nombre']!,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                            ? Colors
                                              .white
                                            : Colors
                                              .black87,
                                        ),
                                      ),

                                      const SizedBox( height: 8,),

                                      ...opciones.map(
                                        (opcion) {
                                          final valor = opcion['valor'] as int;
                                          final etiqueta = opcion[ 'etiqueta'] as String;
                                          final color = opcion[ 'color'] as Color;
                                          return RadioListTile<int>(
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            activeColor:color,
                                            title:Text(etiqueta,
                                              style:
                                                TextStyle(
                                              color: isDark 
                                                ? Colors.white
                                                : Colors.black87,
                                              ),
                                            ),
                                            value:valor,
                                            groupValue:respuestaActual,
                                            onChanged:(valorSeleccionado) {
                                              if (valorSeleccionado == null) {
                                                return;
                                              }
                                              _guardarRespuesta(
                                                preguntaId,
                                                pregunta,
                                                sustancia,
                                                valorSeleccionado,
                                                etiqueta,
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20,
                ),
                decoration:
                    BoxDecoration(
                  color: isDark
                      ? const Color(
                          0xFF1E1E1E,
                        )
                      : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      offset:
                          const Offset(0, -2),
                      color:
                          Colors.black.withValues(
                        alpha: 0.08,
                      ),
                    ),
                  ],
                ),
                // BOTONES PARA AVANZAR Y RETROCEDER *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~
                child: Row(
                  children: [
                    /*
                      if (_bloqueActual > 0)
                      Expanded(
                        child:
                            OutlinedButton(
                          onPressed:
                              _enviando
                                  ? null
                                  : _retrocederBloque,
                          child:
                              const Text(
                            'Atrás',
                          ),
                        ),
                      ),
                    */
                    if (_bloqueActual > 0)
                      const SizedBox( width: 12,),

                    Expanded(
                      flex: 2,
                      child:
                          ElevatedButton(
                        onPressed:
                            _enviando
                                ? null
                                : _avanzarBloque,
                        child: _enviando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : Text(
                                esUltimoBloque
                                    ? 'Finalizar'
                                    : 'Avanzar',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
}


class _ScoreRow
    extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.score,
    required this.extra,
    required this.color,
    required this.isDark,
  });

  final String label;
  final String score;
  final String extra;
  final Color color;
  final bool isDark;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration:
          BoxDecoration(
        color: color.withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
                color: isDark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ),

          const SizedBox(width: 10,),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                score,
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  color: color,
                  fontSize: 18,
                ),
              ),
              Text(
                extra,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}