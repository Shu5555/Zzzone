'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter.js": "888483df48293866f9f41d3d9274a779",
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
"assets/AssetManifest.bin.json": "985fa706b943f86c4785051324d87895",
"assets/assets/announcements.json": "505e0554246ea9c643b02aca88ebf2dd",
"assets/assets/images/gacha_banner.webp": "d405ca451509204105399caaa12abd59",
"assets/assets/persona_display_names.json": "c16feb33014a96833d80b99bb23e5fa4",
"assets/assets/gacha/gacha_items.json": "de300c0cac93a762ba6b1f9d2dd0f9ee",
"assets/assets/gacha/gacha_config.json": "133797ee44e87d4d5f2c154935168af0",
"assets/assets/gacha/three_gacha_scene.html": "459c6bcefb5c1c646f56d0fc931e2c81",
"assets/assets/persona_definitions.json": "95e01516d69ebf1a21b71bb5673b1ef3",
"assets/fonts/MPLUSRounded1c-Medium.ttf": "22e0b5f50d889a011b32dba7ca806b6b",
"assets/fonts/MaterialIcons-Regular.otf": "5bb7e784375b606d8035ed740a330b80",
"assets/fonts/MPLUSRounded1c-Bold.ttf": "9cd5c0b9269ecc2335307ff09861c38f",
"assets/fonts/MPLUSRounded1c-Black.ttf": "5dc0dbd15beac01ee14c34130e16e323",
"assets/fonts/MPLUSRounded1c-Thin.ttf": "121fefdeb00aa8e9855f909dd6f3708d",
"assets/fonts/MPLUSRounded1c-ExtraBold.ttf": "a2a87364a555f4f8c0845ebbe2d81ced",
"assets/fonts/MPLUSRounded1c-Regular.ttf": "5357a97f9e4df48d4eed3949fc697b42",
"assets/fonts/MPLUSRounded1c-Light.ttf": "0444b601b083f779cf3b1e8ae020f135",
"assets/NOTICES": "d648544b95e15c93ff8c017ab9a25c01",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/FontManifest.json": "6159997947b582a3335df8d811289a49",
"assets/AssetManifest.bin": "af905f86fa4369c555275b3b75585072",
"assets/AssetManifest.json": "3d70ffef1ef5d62c193e9f22bd17492f",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"three_effect_container.js": "d46610e336b6cd97101bdfa482bf7f84",
"three_gacha_scene.js": "d1706d99eef415f104d5f9c626ca24d2",
"favicon.png": "1f06100bb6c1e9e4a858d4b69abf92ac",
"flutter_bootstrap.js": "f2d1d4c7bb5775697cd145c24c6d39dd",
"version.json": "368ed262cb56c596e7b99730580af037",
"main.dart.js": "40de0cb472523c6b630f983cb81e8e60"};
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
