// Service worker mínimo de APPlicatuMente.
//
// Existe por una sola razón: Chrome/Edge sólo emiten el evento
// `beforeinstallprompt` (el que habilita el botón "Instalar") cuando la página
// tiene un service worker registrado con un manejador `fetch`.
//
// Deliberadamente NO cachea el código de la app (main.dart.js, assets, etc.).
// El proyecto compila con `--pwa-strategy=none` justamente para evitar que los
// usuarios queden atrapados en una versión vieja tras un redespliegue; cachear
// aquí reintroduciría ese problema. Lo único que se guarda es una página de
// respaldo estática para las navegaciones sin conexión.

const OFFLINE_CACHE = 'aptm-offline-v1';
const OFFLINE_URL = 'offline.html';

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(OFFLINE_CACHE)
      .then((cache) => cache.add(new Request(OFFLINE_URL, { cache: 'reload' })))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => key !== OFFLINE_CACHE)
            .map((key) => caches.delete(key))
        )
      )
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  // Sólo interceptamos navegaciones. Todo lo demás (JS, assets, llamadas a la
  // API) viaja directo a la red sin pasar por el service worker.
  if (event.request.mode !== 'navigate') {
    return;
  }

  event.respondWith(
    fetch(event.request).catch(() =>
      caches
        .open(OFFLINE_CACHE)
        .then((cache) => cache.match(OFFLINE_URL))
        .then((cached) => cached || Response.error())
    )
  );
});
