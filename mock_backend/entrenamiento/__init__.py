"""Reentrenamiento del analizador de sentimiento (Semana 8).

Pedido del asesor (12 de noviembre): con las respuestas de REDCap que
etiqueta el equipo de la Dra. Gonzalez,
  1. dejar escrito donde esta hoy el analizador (linea base por clase);
  2. reentrenar la red (RoBERTuito) y medir que cambio en su funcionamiento;
  3. si no mejora, probar un clasificador de otro tipo para separar las tres
     clases.

Modulos:
  metricas_clases  matriz de confusion, precision/recall/F1 por clase,
                   distribucion y que ejemplos cambiaron (sin dependencias)
  datos            arma el conjunto etiquetado y los pliegues (sin dependencias)
  linea_base       corre el analizador actual sobre un conjunto etiquetado
  reentrenar       ajuste fino de RoBERTuito con validacion cruzada
  alterno          TF-IDF + regresion logistica (y embeddings, opcional)

Privacidad: los datos de REDCap se procesan solo en el servidor de la UAM o
en una carpeta privada (permisos 600). Los reportes que escriben estos
comandos traen solo numeros, nunca respuestas.
"""
