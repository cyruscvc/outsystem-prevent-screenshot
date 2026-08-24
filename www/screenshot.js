var screenshot = {
  enable: function (successCallback, errorCallback) {
    cordova.exec(successCallback, errorCallback, 'screenshotName', 'enable', []);
  },
  disable: function (title, message, successCallback, errorCallback) {
    // Preserve the documented disable(success, error) signature while also
    // supporting disable(title, message, success, error).
    if (typeof title === 'function') {
      errorCallback = message;
      successCallback = title;
      title = null;
      message = null;
    }

    cordova.exec(successCallback, errorCallback, 'screenshotName', 'disable', [title, message]);
  },
  registerListener : function(callback) {
    cordova.exec(callback, callback, 'screenshotName', 'listen', []);

  }
};

cordova.addConstructor(function () {
  if (!window.plugins) {window.plugins = {};}

  window.plugins.preventscreenshot = screenshot;
  document.addEventListener("onTookScreenshot",function(){
    console.log('tookScreenshot');
  });
  document.addEventListener("onGoingBackground",function(){
    console.log('BackgroundCalled');
  });
  screenshot.registerListener(function(me) {
    console.log('received listener:',me);
    if(me === "background") {
      var event = new Event('onGoingBackground');
      document.dispatchEvent(event);
      return;
    }
    if(me === "tookScreenshot") {
      var event = new Event('onTookScreenshot');
      document.dispatchEvent(event);
      return;
    }
  });
  return window.plugins.preventscreenshot;
});
