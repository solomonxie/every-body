// Signing identity stays out of git: set IOS_BUNDLE_ID in the gitignored .env.local.
module.exports = ({ config }) => ({
  ...config,
  ios: { ...config.ios, bundleIdentifier: process.env.IOS_BUNDLE_ID ?? 'com.example.bodyatlas' },
});
