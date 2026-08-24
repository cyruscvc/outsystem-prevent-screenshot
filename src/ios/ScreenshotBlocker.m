#import "ScreenshotBlocker.h"
#import <QuartzCore/QuartzCore.h>

@interface ScreenshotBlocker () {
    CDVInvokedUrlCommand *_eventCommand;
}

@property(nonatomic, assign) BOOL screenshotsBlocked;
@property(nonatomic, strong) UIImageView *cover;
@property(nonatomic, strong) UILabel *stopRecordingLabel;
@property(nonatomic, copy) NSString *recordingTitle;
@property(nonatomic, copy) NSString *recordingContent;

// iOS does not expose a public screenshot-blocking API. These properties make the
// secure-text-entry window-layer workaround reversible when enable() is called.
@property(nonatomic, strong) UITextField *secureTextField;
@property(nonatomic, weak) UIWindow *protectedWindow;
@property(nonatomic, strong) CALayer *originalWindowSuperlayer;
@property(nonatomic, assign) NSUInteger originalWindowLayerIndex;

@end

@implementation ScreenshotBlocker

- (void)pluginInitialize {
    NSLog(@"Starting ScreenshotBlocker plugin");

    self.screenshotsBlocked = NO;
    self.recordingTitle = @"Please Turn Off Screen Recording or Sharing";
    self.recordingContent = @"Looks like your screen is being recorded or shared. Please turn it off to proceed.";

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(appDidBecomeActive)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(tookScreenshot)
                               name:UIApplicationUserDidTakeScreenshotNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(goingBackground)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(screenCaptureStatusChanged)
                               name:kScreenRecordingDetectorRecordingStatusChangedNotification
                             object:nil];
}

- (void)enable:(CDVInvokedUrlCommand *)command {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.screenshotsBlocked = NO;
        [self removeRecordingOverlay];
        [self restoreWindowProtection];
        [self sendSuccessForCommand:command];
    });
}

- (void)listen:(CDVInvokedUrlCommand *)command {
    _eventCommand = command;
}

- (void)disable:(CDVInvokedUrlCommand *)command {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recordingTitle = [self stringArgumentAtIndex:0
                                                  command:command
                                                 fallback:self.recordingTitle];
        self.recordingContent = [self stringArgumentAtIndex:1
                                                    command:command
                                                   fallback:self.recordingContent];
        self.screenshotsBlocked = YES;

        NSString *errorMessage = nil;
        if (![self applyWindowProtection:&errorMessage]) {
            self.screenshotsBlocked = NO;
            [self sendError:errorMessage command:command];
            return;
        }

        [self setupView];
        [self sendSuccessForCommand:command];
    });
}

- (UIWindow *)activeWindow {
    UIWindow *controllerWindow = self.viewController.view.window;
    if (controllerWindow != nil) {
        return controllerWindow;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
    if (keyWindow != nil) {
        return keyWindow;
    }

    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (!window.hidden && window.alpha > 0.0) {
            return window;
        }
    }

    return nil;
}

- (UIView *)secureCanvasInView:(UIView *)view {
    if ([NSStringFromClass([view class]) containsString:@"CanvasView"]) {
        return view;
    }

    for (UIView *subview in view.subviews) {
        UIView *canvas = [self secureCanvasInView:subview];
        if (canvas != nil) {
            return canvas;
        }
    }

    return nil;
}

- (BOOL)applyWindowProtection:(NSString **)errorMessage {
    UIWindow *window = [self activeWindow];
    if (window == nil) {
        if (errorMessage != NULL) {
            *errorMessage = @"Unable to find the active application window.";
        }
        return NO;
    }

    if (self.protectedWindow == window && self.secureTextField != nil) {
        return YES;
    }

    [self restoreWindowProtection];

    CALayer *originalSuperlayer = window.layer.superlayer;
    if (originalSuperlayer == nil) {
        if (errorMessage != NULL) {
            *errorMessage = @"Unable to access the active window layer.";
        }
        return NO;
    }

    NSUInteger originalIndex = [originalSuperlayer.sublayers indexOfObject:window.layer];
    if (originalIndex == NSNotFound) {
        originalIndex = originalSuperlayer.sublayers.count;
    }

    UITextField *secureTextField = [[UITextField alloc] initWithFrame:window.bounds];
    secureTextField.secureTextEntry = YES;
    secureTextField.userInteractionEnabled = NO;
    secureTextField.backgroundColor = [UIColor clearColor];
    secureTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [window addSubview:secureTextField];
    [secureTextField layoutIfNeeded];

    UIView *secureCanvas = [self secureCanvasInView:secureTextField];
    if (secureCanvas == nil) {
        [secureTextField removeFromSuperview];
        if (errorMessage != NULL) {
            *errorMessage = @"Unable to initialize the secure iOS rendering surface.";
        }
        return NO;
    }

    self.protectedWindow = window;
    self.originalWindowSuperlayer = originalSuperlayer;
    self.originalWindowLayerIndex = originalIndex;
    self.secureTextField = secureTextField;

    // Protect the entire UIWindow rather than only Cordova's WKWebView. The
    // OutSystems OpenInWebView UIHostingController is presented in this window.
    [secureTextField.layer removeFromSuperlayer];
    [originalSuperlayer addSublayer:secureTextField.layer];
    [secureCanvas.layer addSublayer:window.layer];

    return YES;
}

- (void)restoreWindowProtection {
    UIWindow *window = self.protectedWindow;
    CALayer *originalSuperlayer = self.originalWindowSuperlayer;

    if (window != nil && originalSuperlayer != nil) {
        [window.layer removeFromSuperlayer];
        NSUInteger layerCount = originalSuperlayer.sublayers.count;
        if (self.originalWindowLayerIndex <= layerCount) {
            [originalSuperlayer insertSublayer:window.layer
                                      atIndex:(unsigned int)self.originalWindowLayerIndex];
        } else {
            [originalSuperlayer addSublayer:window.layer];
        }
    }

    [self.secureTextField removeFromSuperview];
    [self.secureTextField.layer removeFromSuperlayer];
    self.secureTextField = nil;
    self.protectedWindow = nil;
    self.originalWindowSuperlayer = nil;
    self.originalWindowLayerIndex = 0;
}

- (NSString *)stringArgumentAtIndex:(NSUInteger)index
                            command:(CDVInvokedUrlCommand *)command
                           fallback:(NSString *)fallback {
    if (command.arguments.count <= index) {
        return fallback;
    }

    id value = command.arguments[index];
    if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
        return value;
    }

    return fallback;
}

- (void)sendSuccessForCommand:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                               messageAsString:@"Success"];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)sendError:(NSString *)message command:(CDVInvokedUrlCommand *)command {
    NSString *safeMessage = message ?: @"Unable to update screenshot protection.";
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                               messageAsString:safeMessage];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)goingBackground {
    if (_eventCommand != nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                   messageAsString:@"background"];
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:_eventCommand.callbackId];
    }
}

- (void)tookScreenshot {
    if (_eventCommand != nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                   messageAsString:@"tookScreenshot"];
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:_eventCommand.callbackId];
    }
}

- (void)setupView {
    BOOL isRecording = [[ScreenRecordingDetector sharedInstance] isRecording];
    if (isRecording && self.screenshotsBlocked) {
        UIWindow *window = [self activeWindow];
        if (window == nil) {
            return;
        }

        [self removeRecordingOverlay];
        NSString *notification = [NSString stringWithFormat:@"%@\n%@",
                                  self.recordingTitle,
                                  self.recordingContent];

        UILabel *label = [[UILabel alloc] initWithFrame:window.bounds];
        label.text = notification;
        label.textColor = [UIColor blackColor];
        label.backgroundColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont boldSystemFontOfSize:14];
        label.numberOfLines = 0;
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [window addSubview:label];
        [window bringSubviewToFront:label];
        self.stopRecordingLabel = label;
    } else {
        [self removeRecordingOverlay];
    }
}

- (void)removeRecordingOverlay {
    [self.stopRecordingLabel removeFromSuperview];
    self.stopRecordingLabel = nil;
}

- (void)appDidBecomeActive {
    [ScreenRecordingDetector triggerDetectorTimer];
    [self.cover removeFromSuperview];
    self.cover = nil;

    if (self.screenshotsBlocked) {
        NSString *errorMessage = nil;
        if (![self applyWindowProtection:&errorMessage]) {
            NSLog(@"ScreenshotBlocker could not restore window protection: %@", errorMessage);
        }
        [self setupView];
    }
}

- (void)applicationWillResignActive {
    [ScreenRecordingDetector stopDetectorTimer];
    if (!self.screenshotsBlocked || self.cover != nil) {
        return;
    }

    UIWindow *window = [self activeWindow];
    if (window == nil) {
        return;
    }

    UIImageView *cover = [[UIImageView alloc] initWithFrame:window.bounds];
    cover.backgroundColor = [UIColor whiteColor];
    cover.alpha = 0.0;
    cover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [window addSubview:cover];
    [window bringSubviewToFront:cover];
    self.cover = cover;

    [UIView animateWithDuration:0.2 animations:^{
        cover.alpha = 0.95;
    }];
}

- (void)screenCaptureStatusChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setupView];
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
