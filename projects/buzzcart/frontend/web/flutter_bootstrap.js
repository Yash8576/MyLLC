{{flutter_js}}
{{flutter_build_config}}

// Intentionally avoid registering Flutter's service worker for BuzzCart web.
// We prefer fresh deployments over offline-first caching for this app.
_flutter.loader.load();
