// https://docs.expo.dev/guides/using-eslint/
const { defineConfig } = require('eslint/config');
const expoConfig = require("eslint-config-expo/flat");

module.exports = defineConfig([
  expoConfig,
  {
    ignores: ["dist/*", "build/*", "ios/*", "android/*"],
  },
  {
    // three.js props on R3F intrinsics (args, position, …) aren't DOM props
    files: ["src/components/canvas/**"],
    rules: { "react/no-unknown-property": "off" },
  },
]);
