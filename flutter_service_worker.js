'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter.js": "383e55f7f3cce5be08fcf1f3881f585c",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-512.png": "1f06100bb6c1e9e4a858d4b69abf92ac",
"icons/Icon-192.png": "1f06100bb6c1e9e4a858d4b69abf92ac",
"icons/Icon-maskable-192.png": "1f06100bb6c1e9e4a858d4b69abf92ac",
"manifest.json": "99790618e685d581e18b54c764c3bfee",
"three_particle_system.js": "ba65acffab33d08b7fc8013383f78669",
"social_preview.png": "1f06100bb6c1e9e4a858d4b69abf92ac",
"index.html": "69967faa36602cfbbbffbd04730f46e6",
"/": "69967faa36602cfbbbffbd04730f46e6",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin.json": "40fd0468b7f0137f47ee60e0b57190dd",
"assets/assets/announcements.json": "a1fc45c9f9026239243a0f5348388940",
"assets/assets/images/gacha_banner.webp": "d405ca451509204105399caaa12abd59",
"assets/assets/persona_display_names.json": "71b0a8a91037fa485917af841abafc64",
"assets/assets/gacha/gacha_items.json": "b06977151f9b625d5bfc6e8e9e92224e",
"assets/assets/gacha/gacha_config.json": "133797ee44e87d4d5f2c154935168af0",
"assets/assets/gacha/three_gacha_scene.html": "459c6bcefb5c1c646f56d0fc931e2c81",
"assets/assets/persona_definitions.json": "076a6046a75ba210354e53627539f6eb",
"assets/fonts/MPLUSRounded1c-Medium.ttf": "22e0b5f50d889a011b32dba7ca806b6b",
"assets/fonts/MaterialIcons-Regular.otf": "cabf220e555585d40f4685574a780192",
"assets/fonts/MPLUSRounded1c-Bold.ttf": "9cd5c0b9269ecc2335307ff09861c38f",
"assets/fonts/MPLUSRounded1c-Black.ttf": "5dc0dbd15beac01ee14c34130e16e323",
"assets/fonts/MPLUSRounded1c-Thin.ttf": "121fefdeb00aa8e9855f909dd6f3708d",
"assets/fonts/MPLUSRounded1c-ExtraBold.ttf": "a2a87364a555f4f8c0845ebbe2d81ced",
"assets/fonts/MPLUSRounded1c-Regular.ttf": "5357a97f9e4df48d4eed3949fc697b42",
"assets/fonts/MPLUSRounded1c-Light.ttf": "0444b601b083f779cf3b1e8ae020f135",
"assets/NOTICES": "b2887fbcf08d566cc8921e5e0d28b0c5",
"assets/FontManifest.json": "41e1a095755b90f1cdeeb93af5c9da27",
"assets/AssetManifest.bin": "4d19def563125d3a8e5fc26c9566b38d",
"assets/AssetManifest.json": "b61c8157b7b5bab2765ffde86aa17b46",
"canvaskit/chromium/canvaskit.wasm": "399e2344480862e2dfa26f12fa5891d7",
"canvaskit/chromium/canvaskit.js": "901bb9e28fac643b7da75ecfd3339f3f",
"canvaskit/chromium/canvaskit.js.symbols": "ee7e331f7f5bbf5ec937737542112372",
"canvaskit/skwasm.worker.js": "bfb704a6c714a75da9ef320991e88b03",
"canvaskit/skwasm.js": "5d4f9263ec93efeb022bb14a3881d240",
"canvaskit/canvaskit.wasm": "9251bb81ae8464c4df3b072f84aa969b",
"canvaskit/canvaskit.js": "738255d00768497e86aa4ca510cce1e1",
"canvaskit/skwasm.wasm": "4051bfc27ba29bf420d17aa0c3a98bce",
"canvaskit/canvaskit.js.symbols": "74a84c23f5ada42fe063514c587968c6",
"canvaskit/skwasm.js.symbols": "c3c05bd50bdf59da8626bbe446ce65a3",
"three_effect_container.js": "d46610e336b6cd97101bdfa482bf7f84",
"three_gacha_scene.js": "e12d9c1cbfbc31b6d82ccb4c9b38a26b",
"favicon.png": "1f06100bb6c1e9e4a858d4b69abf92ac",
"flutter_bootstrap.js": "752340f62b0fcefa50e1f5733a5bf767",
"version.json": "368ed262cb56c596e7b99730580af037",
"main.dart.js": "c3923b86438804820dff2ff2ae66a69d"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
