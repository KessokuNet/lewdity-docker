// Bundles dol-server's autosync extension for the image build. Run from the
// root of a dol-server checkout with esbuild installed; see the Containerfile.

import * as esbuild from "esbuild";

// The upstream sources import some modules by URL, Deno-style (e.g.
// https://deno.land/x/html). esbuild leaves URL imports external by default,
// which breaks the bundle in the browser, so download and inline them like
// `deno bundle` did.
const httpImports = {
  name: "http-imports",
  setup(build) {
    build.onResolve({ filter: /^https?:\/\// }, (args) => ({
      path: args.path,
      namespace: "http-url",
    }));
    // Relative imports inside a downloaded module resolve against its URL
    build.onResolve({ filter: /.*/, namespace: "http-url" }, (args) => ({
      path: new URL(args.path, args.importer).toString(),
      namespace: "http-url",
    }));
    build.onLoad({ filter: /.*/, namespace: "http-url" }, async (args) => {
      const resp = await fetch(args.path);
      if (!resp.ok) {
        throw new Error(`fetching ${args.path}: ${resp.status} ${resp.statusText}`);
      }
      return {
        contents: await resp.text(),
        loader: /\.tsx?$/.test(new URL(args.path).pathname) ? "ts" : "js",
      };
    });
  },
};

// The upstream sources import via the "#/" alias from deno.json. esbuild has
// no equivalent config, so map "#" onto the project root instead.
await esbuild.build({
  entryPoints: ["extension/autosync/autosync.ts"],
  bundle: true,
  format: "esm",
  platform: "browser",
  outfile: "out/autosync_generated.js",
  alias: { "#": "." },
  plugins: [httpImports],
});
