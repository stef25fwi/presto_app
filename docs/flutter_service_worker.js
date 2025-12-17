'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/assets/images/chrono_1min.png": "0fcf0bfe7937ba8922948609bc8cd185",
"assets/assets/data/cities_compact.json": "02a75b17515e0f0a3962ae1fb4131646",
"assets/assets/data/cities/cities_86.json": "07e05db7b3b03774f796f5a3d66d10b6",
"assets/assets/data/cities/cities_2A.json": "4d45b664475181801565a86a92f4af7b",
"assets/assets/data/cities/cities_05.json": "b60c683196d649b571c271c4541ec7d0",
"assets/assets/data/cities/cities_43.json": "de883453744a6fa417d2bcc53dec87d9",
"assets/assets/data/cities/cities_94.json": "346a3a55130aa3b9b3804c51563ee19c",
"assets/assets/data/cities/cities_38.json": "86a4e0b7584309018b07fa8b7f4cfe4f",
"assets/assets/data/cities/cities_41.json": "b4a9c88a3b63f9075d0e0eefdd20901c",
"assets/assets/data/cities/cities_02.json": "7f8bd2efda46dc82d9e0ba2e68de4628",
"assets/assets/data/cities/cities_49.json": "b41dfe25d1525a8c3e3f751e1ccfd706",
"assets/assets/data/cities/cities_82.json": "9d5a59075e688b534a4401ed80c06fde",
"assets/assets/data/cities/cities_84.json": "c1f420534a2a79d31ee23575ef1a38f9",
"assets/assets/data/cities/cities_93.json": "e8fe2b1362f7ff76bd4248b1632d26bc",
"assets/assets/data/cities/cities_62.json": "fd80983fbe1c14c86150951d5d681678",
"assets/assets/data/cities/cities_88.json": "109f95a515c3f2d60d7b10cd2db00b81",
"assets/assets/data/cities/cities_80.json": "728433659a73936b6f8404dc37649f36",
"assets/assets/data/cities/cities_07.json": "dee1311b3e0fb8a773a377e118d3a59c",
"assets/assets/data/cities/cities_89.json": "3788ea48a23f598ef7a0e7e97c6c2485",
"assets/assets/data/cities/cities_976.json": "41907ac1992a6f0be72cc0feb02857f9",
"assets/assets/data/cities/cities_68.json": "5c3be42589edb6381e85f9d7337794a2",
"assets/assets/data/cities/cities_36.json": "f2e79de39eb72df37c9332cad029f784",
"assets/assets/data/cities/cities_87.json": "0b6f4cd7f0941bc20aec1ee49c6c5f4d",
"assets/assets/data/cities/cities_40.json": "22639bc8ccbb385725700c069a610375",
"assets/assets/data/cities/cities_11.json": "9806cbb24ece16b37727d7961c00a988",
"assets/assets/data/cities/cities_58.json": "6475d0b3e7ea1f2eeaeddebc23122f9e",
"assets/assets/data/cities/cities_01.json": "e47991b3ffc2695f45b3b70995dbea23",
"assets/assets/data/cities/cities_60.json": "1c6a96ac9cf5fa973f020343146cd6af",
"assets/assets/data/cities/cities_71.json": "9403e50524e27eabd8827eb464a4b070",
"assets/assets/data/cities/cities_57.json": "492b54e9e920394287b0940f318e4c15",
"assets/assets/data/cities/cities_04.json": "1ac8650f5d6ed16413880ab6c078a7e6",
"assets/assets/data/cities/cities_85.json": "3aafa6903dd9f114a4a1dbcecaa13bee",
"assets/assets/data/cities/cities_975.json": "76b65ca175cb766932dbce5ca88d3ac6",
"assets/assets/data/cities/cities_09.json": "15c49bb583fe710043a85d55a9c17414",
"assets/assets/data/cities/cities_75.json": "a23c054fd3589793731ff5fae1947f49",
"assets/assets/data/cities/cities_69.json": "91a098b890551b0a320a750688519208",
"assets/assets/data/cities/cities_92.json": "482a82e7c9f614a55c00cbc108915681",
"assets/assets/data/cities/cities_32.json": "d69bdf17d9e4eadde6f6879d0c14e77c",
"assets/assets/data/cities/cities_48.json": "95da36d6461f6abb19619a754754b8ca",
"assets/assets/data/cities/cities_46.json": "5a866ce26413a3bb9792af389d6948b5",
"assets/assets/data/cities/cities_67.json": "d06d7fbf8d57b09db3f7401366d369de",
"assets/assets/data/cities/cities_986.json": "fd82c8e510b5054173567b25f6159e8b",
"assets/assets/data/cities/cities_66.json": "fd1ee6334e824a377fa393ad3d7a7673",
"assets/assets/data/cities/cities_35.json": "06c62c454333d3ecfd56c8c2486b4110",
"assets/assets/data/cities/cities_83.json": "88bbfbe0cde57b6d31e2e61f5a88ea5d",
"assets/assets/data/cities/cities_14.json": "7dcfede27187b98b51240caa81a74ec0",
"assets/assets/data/cities/cities_13.json": "62ad9c097af15ff2b4d5129a140088e0",
"assets/assets/data/cities/cities_42.json": "a24581c9ed7cb8050fff7a7247b5e9db",
"assets/assets/data/cities/cities_81.json": "b2455f729813bdc4351bcbbb61a13d73",
"assets/assets/data/cities/cities_26.json": "053d41d4af506736b6fb0457cee463bb",
"assets/assets/data/cities/cities_974.json": "bca7a9893a408edf1b0463acbd8f435d",
"assets/assets/data/cities/cities_29.json": "c56f3183825718ed04d0b3e4002ccd71",
"assets/assets/data/cities/cities_76.json": "6a07a3a5b4ace8e8098a4468743e4396",
"assets/assets/data/cities/cities_987.json": "c53f419683db5654cbe0da1406c2ec32",
"assets/assets/data/cities/cities_12.json": "ac6e7cd5d311c08c949fde3be874899a",
"assets/assets/data/cities/cities_90.json": "3413e619f8a7dbd46c656d625fbe6879",
"assets/assets/data/cities/cities_55.json": "543daaeae9e1fe1b74dfadfbb62d3718",
"assets/assets/data/cities/cities_27.json": "dcd3bb4c9993816e03bf9c9db88c80e5",
"assets/assets/data/cities/cities_51.json": "be57be5364538fbd83c17de1f6a1bcd9",
"assets/assets/data/cities/cities_50.json": "5df42b2693cfe868c6ca6de1768edffb",
"assets/assets/data/cities/cities_56.json": "7fa62075999c8d38c4f99375a10401a6",
"assets/assets/data/cities/cities_28.json": "da665c5cb77641b400e6789a5e57195a",
"assets/assets/data/cities/cities_33.json": "47eef6bdc274848ff755f2723b2c9ba4",
"assets/assets/data/cities/cities_70.json": "b89759eb04114237cddadd61e35ead52",
"assets/assets/data/cities/cities_34.json": "f5f1b6aafa722bcdd79c2b1798f55a41",
"assets/assets/data/cities/cities_971.json": "d686b588d5f0be94f20ed1a64d1af84b",
"assets/assets/data/cities/cities_08.json": "70171fd397b19cd117b418783755cf1b",
"assets/assets/data/cities/cities_25.json": "947d4f79f949fdd050506db1102d3826",
"assets/assets/data/cities/cities_10.json": "b4f67f67efd834358293a8a75ed4d753",
"assets/assets/data/cities/cities_03.json": "e271ceaf8a55ae61b0c04ec1f1b1e043",
"assets/assets/data/cities/cities_22.json": "b9ce32861e3f499ef58197f9dfe1fba3",
"assets/assets/data/cities/cities_18.json": "b200ae55f898002829fa6ba380281464",
"assets/assets/data/cities/cities_52.json": "3772ecf0292fe7d5eb12fa990353b631",
"assets/assets/data/cities/cities_988.json": "5d59a477e310617ffa14959a331dd91b",
"assets/assets/data/cities/cities_39.json": "b24d1d9ba4723309fd5c094ad05fa9d0",
"assets/assets/data/cities/cities_54.json": "33b855a39330aec029bab9374828de61",
"assets/assets/data/cities/cities_65.json": "0e217bf9e30fb812997a26dc9944494c",
"assets/assets/data/cities/cities_79.json": "8714406de97db827e8a119db96e45417",
"assets/assets/data/cities/cities_95.json": "c8065f74d4bf45d89212e11921e2fe40",
"assets/assets/data/cities/cities_72.json": "366037ef526ee56113b0f43d00066ec6",
"assets/assets/data/cities/cities_23.json": "3d63199d8f6f6b56acc4f7cff47b8019",
"assets/assets/data/cities/cities_74.json": "f2881500160c2a6ee01342464e901a36",
"assets/assets/data/cities/cities_44.json": "a0549eb8b9c33d8453f09ceef9ee703a",
"assets/assets/data/cities/cities_73.json": "6e55a12b5faef223572bad00e85b0655",
"assets/assets/data/cities/cities_61.json": "2a6010ffbbf1db5273ac7334e54679eb",
"assets/assets/data/cities/cities_31.json": "3cccad5b2ca95858a7469a4ffe2ba7f8",
"assets/assets/data/cities/cities_78.json": "18e0d731af2dc1e1e97921307b8b821e",
"assets/assets/data/cities/cities_64.json": "2ff19800c6898cf7531fb0e415fdf0bb",
"assets/assets/data/cities/cities_77.json": "3c9a57b4269842df3871395bbe98802c",
"assets/assets/data/cities/cities_980.json": "261e09fbad5a30af9d28df2d3ee0fe88",
"assets/assets/data/cities/cities_2B.json": "9c279f700e27bbfcbd6a4f3e6f173bdd",
"assets/assets/data/cities/cities_973.json": "d86700db2aac36f39d60dd56d1987eea",
"assets/assets/data/cities/cities_24.json": "c191c144c1b58c405daef9ca50306a5a",
"assets/assets/data/cities/cities_63.json": "81ade154d8734d490208c6089ecd98f2",
"assets/assets/data/cities/cities_17.json": "efe02b27c6034ace78df6fadf58b5d57",
"assets/assets/data/cities/cities_45.json": "8ee682c12d9821f2caf6680163f37fb2",
"assets/assets/data/cities/cities_21.json": "c910d5911ef460c3e8a5d29d723b0660",
"assets/assets/data/cities/cities_47.json": "6fe4d6df7e20e43cf631b0142447ddfc",
"assets/assets/data/cities/cities_30.json": "1a0b00ee2f61177ea8b020b2c3a56aab",
"assets/assets/data/cities/cities_91.json": "c1699fa2b802db08563473c20a2f764e",
"assets/assets/data/cities/cities_19.json": "fba9793bdd3a01a4733a51cd470e12bd",
"assets/assets/data/cities/cities_16.json": "c4ebdc0c4b9a71adfbca2bfc39a82e44",
"assets/assets/data/cities/cities_53.json": "9c840a8c3e4f920faeff586ce94aaf18",
"assets/assets/data/cities/cities_972.json": "e32814a33e9184522e5fb2310eedc485",
"assets/assets/data/cities/cities_59.json": "b864627f72e5ea4ac5b29a395d70502b",
"assets/assets/data/cities/cities_06.json": "76e05bdb1e468a97d06ba7d20b5900b9",
"assets/assets/data/cities/cities_15.json": "ceea50dd919dcb0fa1992a48012d03a4",
"assets/assets/data/cities/cities_37.json": "65be20abca9cf1dbc5ed502c32601ec6",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/record_web/assets/js/record.fixwebmduration.js": "1f0108ea80c8951ba702ced40cf8cdce",
"assets/packages/record_web/assets/js/record.worklet.js": "6d247986689d283b7e45ccdf7214c2ff",
"assets/NOTICES": "759a6b4cf13ec6074a07d904ab22a9fd",
"assets/fonts/MaterialIcons-Regular.otf": "e266695ab1a11d99206840aa19966990",
"assets/AssetManifest.bin": "eefe07c4de9971c8407a70f0ca6fccc2",
"assets/AssetManifest.bin.json": "58faf267a35eb05abb021aa435e7c598",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"index.html": "d1d29f1335f0be2db7d4ad00eb2f68fc",
"/": "d1d29f1335f0be2db7d4ad00eb2f68fc",
"main.dart.js": "475cb81f888a1d9c88986e5483c1083c",
"flutter_bootstrap.js": "90c99efb19cd57bb1419d1e55f862ec3",
"version.json": "8df3cd3c7c223f3ebda8fbb9cdf0967f",
"manifest.json": "b8e012f650576f16cebd94a9a9003fb4",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e"};
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
