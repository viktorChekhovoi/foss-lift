{{flutter_js}}
{{flutter_build_config}}

// Replaced after compilation by tool/prepare-web.mjs. Keeping the loader small
// and revalidated lets immutable app assets survive across repeat visits.
const local = (value) => value.startsWith('__') ? './' : value;
const base = local("__FOSS_LIFT_APP_ROOT__");
const assets = local("__FOSS_LIFT_ASSET_ROOT__");
const engine = local("__FOSS_LIFT_ENGINE_ROOT__");
const status = document.getElementById('boot-status');
const fail = () => window.dispatchEvent(new Event('fosslift-failed'));

const config = {
    entrypointBaseUrl: base,
    assetBase: assets,
    canvasKitBaseUrl: `${engine}canvaskit/`,
    fontFallbackBaseUrl: `${base}font-fallback/`,
};
_flutter.loader.load({
  config,
  onEntrypointLoaded: async (engineInitializer) => {
    try {
      if (status) status.textContent = 'Opening your training log…';
      const runner = await engineInitializer.initializeEngine(config);
      await runner.runApp();
    } catch (_) {
      fail();
    }
  },
}).catch(fail);
