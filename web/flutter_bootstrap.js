// Flutter's loader, then our own service worker (docs/07 §12). Flutter's service worker is
// deprecated and does not cache anything any more; sw.js keeps the app shell for offline use.
// The tokens are filled in by `flutter build web`.
{{flutter_js}}
{{flutter_build_config}}

// The build version keys the service worker's shell cache; tool/web/build_web.py rewrites this
// line with a hash of the shell files (Flutter's own token no longer changes between builds).
const buildVersion = {{flutter_service_worker_version}};
if ('serviceWorker' in navigator) {
  // After a new build, the worker of the old one still controls this page load and serves the
  // old app from its cache. The new worker installs now; once it takes over (controllerchange),
  // reload once so that the app, its assets and the worker are all the new build.
  const current = navigator.serviceWorker.controller;
  const stale = current != null && !current.scriptURL.endsWith('v=' + buildVersion);
  if (stale) navigator.serviceWorker.addEventListener('controllerchange', () => location.reload(), { once: true });
  navigator.serviceWorker.register('sw.js?v=' + buildVersion).catch((e) => console.warn('service worker', e));
}

_flutter.loader.load({});
