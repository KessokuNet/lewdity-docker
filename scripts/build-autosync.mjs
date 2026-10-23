// Bundles dol-server's autosync extension for the image build. Run from the
// root of a dol-server checkout with esbuild installed; see the Containerfile.

import * as esbuild from "esbuild";

// The upstream sources import via the "#/" alias from deno.json. esbuild has
// no equivalent config, so map "#" onto the project root instead.
await esbuild.build({
  entryPoints: ["extension/autosync/autosync.ts"],
  bundle: true,
  format: "esm",
  platform: "browser",
  outfile: "out/autosync_generated.js",
  alias: { "#": "." },
});
