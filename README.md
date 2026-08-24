# cordova-plugin-prevent-screenshot-coffice

Cordova plugin to enable or disable screenshot and screen-recording protection on Android and iOS.

## OutSystems `OpenInWebView` support

Version 1.1.0 extends protection beyond Cordova's original WebView so it also covers the native screen opened by `OpenInWebView` in `cordova-outsystems-inappbrowser` 1.6.3.

- Android applies `FLAG_SECURE` to the Cordova Activity and every Activity created later by the application. This includes the OutSystems `OSIABWebViewActivity`.
- iOS applies the existing secure-text-entry technique at the application-window level. This includes the separately presented `UIHostingController` used by `OpenInWebView`.
- `OpenInSystemBrowser` and external-browser windows are outside the application and cannot be protected by this plugin.

Call `disable` before calling `OpenInWebView`. The protection remains active until `enable` is called.

> iOS does not provide a public API that prevents screenshots. The iOS implementation is an unsupported UIKit workaround and must be tested on the physical-device/iOS combinations supported by the application after every MABS or iOS upgrade.

## Installation

```sh
cordova plugin add https://github.com/cyruscvc/outsystem-prevent-screenshot.git
```

For OutSystems, reference the Git URL or a release ZIP from the plugin's Extensibility Configuration and generate a new mobile-app build.

## JavaScript usage

```js
document.addEventListener('deviceready', function () {
  // Block screenshots before opening OpenInWebView.
  window.plugins.preventscreenshot.disable(successCallback, errorCallback);
}, false);

function successCallback(result) {
  console.log(result); // "Success"
}

function errorCallback(error) {
  console.error(error);
}
```

An optional recording warning title and message can be supplied for iOS:

```js
window.plugins.preventscreenshot.disable(
  'Screen recording detected',
  'Stop recording or sharing your screen to continue.',
  successCallback,
  errorCallback
);
```

Allow screenshots again:

```js
window.plugins.preventscreenshot.enable(successCallback, errorCallback);
```

Screenshot and background notifications remain available:

```js
document.addEventListener('onTookScreenshot', function () {
  // iOS reports that a screenshot was taken. This event is after the attempt.
});

document.addEventListener('onGoingBackground', function () {
  // The app is moving to the background or showing system UI.
});
```

## TypeScript usage

```ts
const screenshotPlugin = (<any>window).plugins.preventscreenshot;

screenshotPlugin.disable(
  (result: string) => console.log(result),
  (error: string) => console.error(error)
);

screenshotPlugin.enable(
  (result: string) => console.log(result),
  (error: string) => console.error(error)
);
```

## Validation checklist

Use a physical Android and iOS device for the final validation:

1. Call `disable`, then open a URL with OutSystems `OpenInWebView`.
2. Attempt a screenshot while the Cordova screen is visible and while `OpenInWebView` is visible.
3. Start screen recording or screen sharing and repeat the test.
4. Close `OpenInWebView`, call `enable`, and verify screenshots work again.
5. Repeat after an MABS, Cordova, InAppBrowser, Android, or iOS upgrade.

## Supported platforms

- Android
- iOS

## License

MIT
