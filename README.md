# Front APTM

Frontend Flutter web de Aplicate Por Tu Mente.

## Dónde está desplegado

| | Dirección |
|---|---|
| Aplicación | https://ml.izt.uam.mx/aptm/ |
| API | https://ml.izt.uam.mx/aptm-api/ |

Corre en el servidor de la UAM Iztapalapa, con Python y PostgreSQL instalados
directamente (sin Docker) y publicado a través del Apache del servidor. El
despliegue anterior en Google Cloud quedó fuera de servicio al terminarse los
créditos gratuitos.

**Cada push a la rama `demo` se publica solo:** GitHub compila la app y publica
un paquete (`.tar.gz`); el servidor lo recoge, verifica su suma sha256 y lo
instala, en menos de cinco minutos. GitHub no tiene ningún acceso al servidor.

El procedimiento completo, con capturas y decisiones, está en
`documentacion/despliegue_servidor/despliegue_uam.md` (también en PDF).

## Ejecutar con Docker

No necesitas tener Flutter instalado en la computadora o servidor. Docker usa la
imagen `ghcr.io/cirruslabs/flutter:stable` para descargar dependencias y compilar
el build web dentro del contenedor.

Desde la carpeta `APPlicatuMente`:

```bash
docker compose up --build frontend
```

La app queda disponible en `http://localhost:8080`.

Puedes cambiar la URL del backend al compilar:

```bash
API_BASE_URL=http://localhost:8001 docker compose up --build frontend
```

## Ejecutar en local

Si tienes Flutter instalado, este script solo instala dependencias y ejecuta el
comando pedido. Si no tienes Flutter, usa Docker para `build` o `pub-get`.

```bash
./scripts/flutter_web.sh pub-get
./scripts/flutter_web.sh build
./scripts/flutter_web.sh run
```
