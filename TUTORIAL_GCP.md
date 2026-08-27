# Tutorial: cómo desplegué APTM en Google Cloud Platform (GCP)

> Estado real, tal como quedó:
> - **Proyecto GCP:** `aptm-produccion`
> - **VM:** `aptm-server` (e2-small, 2 vCPU comp., 2 GB RAM) en `northamerica-south1-a` (Querétaro, México)
> - **IP estática:** `34.51.63.92`
> - **Frontend:** https://aptm-uami.duckdns.org
> - **Backend:** https://aptm-api-uami.duckdns.org
> - **Costo:** por ahora corre sobre el crédito de prueba gratuito de GCP (90 días desde la activación). A día de hoy me quedan aproximadamente **64 días** antes de que se acabe el periodo de prueba — es un cálculo mío a partir de la última vez que revisé el saldo, así que antes de citarlo en algo formal conviene confirmar la cifra exacta en Facturación → Resumen.

---

## 0. Arquitectura

Así quedó armado, una vez desplegado:

```
Internet
   │
   ├── https://aptm-uami.duckdns.org      ─┐
   └── https://aptm-api-uami.duckdns.org  ─┤
                                            ▼
                              VM Compute Engine (aptm-server)
                              ┌──────────────────────────────┐
                              │ nginx (host, puerto 80/443)  │  ← certbot / Let's Encrypt
                              │   ├─ proxy → 127.0.0.1:8080  │  (frontend)
                              │   └─ proxy → 127.0.0.1:8001  │  (backend)
                              │                               │
                              │ docker compose (network_mode: host) │
                              │   ├─ aptm_frontend  (nginx+Flutter Web) :8080
                              │   ├─ aptm_backend   (FastAPI)           :8001
                              │   └─ aptm_postgres  (Postgres 16)       :55432
                              └──────────────────────────────┘
```

**Decisión clave (la aprendí a la mala):** compilo las imágenes Docker en mi máquina local y las
subo ya construidas a Artifact Registry; la VM solo hace `docker pull` + `docker compose up`. La
primera vez intenté compilar Flutter Web (`dart2js`) directamente dentro de la VM de 2 GB de RAM
y la saturé por completo — se me colgó hasta el SSH. Compilar en mi máquina y desplegar imágenes
ya armadas resultó más rápido, más confiable, y además es la práctica estándar en cualquier flujo
de CI/CD.

---

## 1. Prerrequisitos

Esto es lo que tuve que tener listo antes de empezar:

- Cuenta de Google con facturación habilitada (tarjeta registrada; GCP no cobra sin confirmación
  explícita, pero la VM y la IP sí generan costo mientras están activas).
- `gcloud` CLI instalado y autenticado en mi máquina:
  ```bash
  curl https://sdk.cloud.google.com | bash
  exec -l $SHELL
  gcloud init
  gcloud auth login
  ```
- Docker instalado localmente (para compilar y subir las imágenes).
- Una cuenta gratuita en [duckdns.org](https://www.duckdns.org) (entré con mi cuenta de Google).

---

## 2. Crear el proyecto GCP y habilitar servicios

```bash
GC=gcloud   # o la ruta completa a tu binario, p.ej. ~/google-cloud-sdk/bin/gcloud

# Crear proyecto
"$GC" projects create aptm-produccion --name="APTM Produccion"
"$GC" config set project aptm-produccion

# Vincular facturación (obtén tu ACCOUNT_ID con: gcloud billing accounts list)
"$GC" billing projects link aptm-produccion --billing-account=TU_BILLING_ACCOUNT_ID

# Habilitar APIs necesarias
"$GC" services enable compute.googleapis.com artifactregistry.googleapis.com --project=aptm-produccion
```

---

## 3. Red: IP estática y firewall

```bash
REGION=northamerica-south1
ZONE=northamerica-south1-a

# IP pública fija (no cambia si apagas/enciendes la VM)
"$GC" compute addresses create aptm-ip --region=$REGION --project=aptm-produccion
"$GC" compute addresses describe aptm-ip --region=$REGION --project=aptm-produccion --format="value(address)"

# Firewall: solo SSH, HTTP y HTTPS públicos. Los puertos internos (8080/8001/55432)
# de los contenedores NUNCA se abren al público — solo nginx local habla con ellos.
"$GC" compute firewall-rules create aptm-allow-web \
  --project=aptm-produccion \
  --direction=INGRESS --action=ALLOW \
  --rules=tcp:22,tcp:80,tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=aptm-server
```

---

## 4. Crear la VM

```bash
"$GC" compute instances create aptm-server \
  --project=aptm-produccion \
  --zone=$ZONE \
  --machine-type=e2-small \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=30GB \
  --boot-disk-type=pd-balanced \
  --tags=aptm-server \
  --address=aptm-ip
```

Elegí `e2-small` (2 GB de RAM) porque alcanza de sobra para **correr** los tres contenedores ya
compilados — el problema nunca fue correrlos, fue compilar ahí mismo (ver la decisión del punto 0).

---

## 5. Instalar Docker, Nginx y Certbot en la VM

Esto lo corrí una sola vez, por SSH:

```bash
"$GC" compute ssh aptm-server --zone=$ZONE --project=aptm-produccion --command='
set -e
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg nginx certbot python3-certbot-nginx
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $(whoami)
sudo systemctl enable --now docker
'
```

**Swap de seguridad** (con 2 GB de RAM al límite, sin swap cualquier pico de memoria me iba a
volver a colgar la VM):

```bash
"$GC" compute ssh aptm-server --zone=$ZONE --project=aptm-produccion --command='
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
'
```

---

## 6. DuckDNS (DNS gratuito) apuntando a la IP estática

1. Entré a https://www.duckdns.org e inicié sesión.
2. Creé dos subdominios: `aptm-uami` y `aptm-api-uami`.
3. Copié mi **token** (aparece arriba de la página) y actualicé los registros con la IP estática
   del paso 3. Ojo con esto: a mí DuckDNS me autocompletó el campo con mi propia IP de casa la
   primera vez que entré a la página — tuve que corregirlo a mano para que apuntara a la IP de la
   VM:
   ```bash
   TOKEN=tu_token_duckdns
   curl "https://www.duckdns.org/update?domains=aptm-uami,aptm-api-uami&token=${TOKEN}&ip=34.51.63.92"
   ```
4. Verifiqué la propagación:
   ```bash
   getent hosts aptm-uami.duckdns.org
   getent hosts aptm-api-uami.duckdns.org
   ```

---

## 7. Compilar y subir las imágenes (desde tu máquina, NO en la VM)

```bash
"$GC" auth configure-docker northamerica-south1-docker.pkg.dev --quiet
"$GC" artifacts repositories create aptm-images \
  --repository-format=docker --location=$REGION --project=aptm-produccion

REGISTRY="northamerica-south1-docker.pkg.dev/aptm-produccion/aptm-images"
cd APPlicatuMente

# Frontend: el build-arg API_BASE_URL queda "horneado" dentro del JS compilado.
docker build --build-arg API_BASE_URL=https://aptm-api-uami.duckdns.org \
  -t "$REGISTRY/frontend:latest" .
docker push "$REGISTRY/frontend:latest"

# Backend
cd mock_backend
docker build -t "$REGISTRY/backend:latest" .
docker push "$REGISTRY/backend:latest"
```

> Si cambio el dominio del backend más adelante, tengo que reconstruir el frontend (el
> `API_BASE_URL` se compila dentro del JavaScript, no es una variable de entorno en runtime).

---

## 8. Desplegar en la VM

Copio `docker-compose.prod.yml` (incluido en este repo) y despliego:

```bash
SSH_OPTS="-i ~/.ssh/google_compute_engine -o StrictHostKeyChecking=no"
scp $SSH_OPTS docker-compose.prod.yml purpple-alien@34.51.63.92:~/aptm/

# Autenticar la VM contra Artifact Registry (token de corta duración, ~1h)
TOKEN=$("$GC" auth print-access-token)
"$GC" compute ssh aptm-server --zone=$ZONE --project=aptm-produccion \
  --command="echo \"$TOKEN\" | docker login -u oauth2accesstoken --password-stdin https://northamerica-south1-docker.pkg.dev"

"$GC" compute ssh aptm-server --zone=$ZONE --project=aptm-produccion --command='
cd ~/aptm
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
docker compose -f docker-compose.prod.yml ps
'
```

> **Nota que me dejé anotada:** el token dura ~1 hora, suficiente para el `pull` inicial. Para no
> repetir esto en cada redeploy, la opción robusta es re-crear la VM con el scope `cloud-platform`
> y otorgar el rol `roles/artifactregistry.reader` a su cuenta de servicio; con eso,
> `gcloud auth configure-docker` funciona de forma permanente sin tokens manuales.

---

## 9. Nginx como reverse proxy + HTTPS con Let's Encrypt

Creé dos server blocks (uno por subdominio) que redirigen a los puertos internos de los
contenedores, y dejé que Certbot añadiera TLS automáticamente:

`/etc/nginx/sites-available/aptm-uami.conf`:
```nginx
server {
    listen 80;
    server_name aptm-uami.duckdns.org;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

`/etc/nginx/sites-available/aptm-api-uami.conf` (igual, pero `proxy_pass http://127.0.0.1:8001;`).

```bash
sudo ln -sf /etc/nginx/sites-available/aptm-uami.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/aptm-api-uami.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# Certificados HTTPS + redirect automático HTTP→HTTPS
sudo certbot --nginx -n --agree-tos -m tu_correo@ejemplo.com \
  -d aptm-uami.duckdns.org -d aptm-api-uami.duckdns.org --redirect
```

Certbot instala un **systemd timer** (`certbot.timer`) que renueva los certificados
automáticamente antes de que expiren — no tuve que volver a tocar esto.

---

## 10. Verificación

Así confirmé que todo servía:

```bash
curl -I https://aptm-uami.duckdns.org/                 # 200 OK, sirve el HTML de Flutter
curl https://aptm-api-uami.duckdns.org/salud            # {"status":"ok"}
curl -I http://aptm-uami.duckdns.org/                   # 301 → https (redirect funcionando)

# Los puertos internos NO deben responder desde fuera:
curl --max-time 5 http://34.51.63.92:8080/              # debe fallar / timeout
```

Y por último abrí `https://aptm-uami.duckdns.org` en el navegador y probé registro + login
de punta a punta.

---

## 11. Operación día a día

**Ver logs:**
```bash
"$GC" compute ssh aptm-server --zone=$ZONE --project=aptm-produccion \
  --command='cd ~/aptm && docker compose -f docker-compose.prod.yml logs --tail=50 backend'
```

**Redesplegar tras un cambio de código** (repito el paso 7 y luego):
```bash
"$GC" compute ssh aptm-server --zone=$ZONE --project=aptm-produccion --command='
cd ~/aptm
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
'
```

**Apagar la VM para ahorrar crédito** (la IP estática se conserva, el disco sigue cobrando
~$1-2/mes):
```bash
"$GC" compute instances stop aptm-server --zone=$ZONE --project=aptm-produccion
# ... y para reactivar:
"$GC" compute instances start aptm-server --zone=$ZONE --project=aptm-produccion
```
Los contenedores tienen `restart: unless-stopped`, así que **vuelven a arrancar solos** cuando la
VM enciende — no tengo que repetir `docker compose up` a mano.

**Backup de la base de datos:**
```bash
"$GC" compute ssh aptm-server --zone=$ZONE --project=aptm-produccion \
  --command='docker exec aptm_postgres pg_dump -U postgres aptm_tmp' > backup_$(date +%F).sql
```

---

## 12. Pendientes de seguridad antes de usarlo con datos reales de estudiantes

Esto lo dejo anotado porque todavía no lo resuelvo:

- **CORS abierto (`allow_origins=["*"]`)** en el backend — hay que restringirlo a los dominios
  reales del frontend antes de manejar datos sensibles.
- **Contraseña de Postgres por defecto** (`postgres`/`postgres`) — tengo que cambiarla; aunque el
  puerto 55432 no es público, no es buena práctica dejar credenciales por defecto.
- El backend actual (`mock_backend`) sigue siendo un **stub de desarrollo**: el chat de "Serena"
  solo responde un mensaje fijo, no hay rate limiting ni verificación real de JWT contra un
  proveedor de identidad. Antes de producción real con usuarios finales, tengo que sustituirlo por
  el backend definitivo del proyecto.
- Me falta sacar los tokens de DuckDNS y demás credenciales fuera de este repo, por si en algún
  momento se hace público.
