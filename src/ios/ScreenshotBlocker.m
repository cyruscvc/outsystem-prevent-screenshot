#import "ScreenshotBlocker.h"
@interface ScreenshotBlocker() {
    CDVInvokedUrlCommand * _eventCommand;
}
@end

@implementation ScreenshotBlocker
UIImageView* cover;
CustomView* preventedView;
UIView *secureView;
BOOL stopRecording = false;
NSString* title = @"Please Turn Off Screen Recording or Sharing";
NSString* content = @"Looks like your screen is being recorded or shared. Please turn it off to proceed.";
UILabel *stopRecordingLabel;

- (void)pluginInitialize {
    NSLog(@"Starting ScreenshotBlocker plugin");

    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(appDidBecomeActive)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(applicationWillResignActive)
                                                name:UIApplicationWillResignActiveNotification
                                              object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(tookScreeshot)
                                                 name:UIApplicationUserDidTakeScreenshotNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(goingBackground)
                                                name:UIApplicationWillResignActiveNotification
                                              object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(screenCaptureStatusChanged)
                                                 name:kScreenRecordingDetectorRecordingStatusChangedNotification
                                               object:nil];

    /*
     userDidTakeScreenshotNotification
     */

}

- (void)enable:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult* pluginResult = nil;
    stopRecording = false;
    [secureView removeFromSuperview];
    [self.viewController.view addSubview:self.webView];
    secureView = nil;
    preventedView = nil;
}
-(void)listen:(CDVInvokedUrlCommand*)command {
    _eventCommand = command;
}

-(void)disable:(CDVInvokedUrlCommand*)command {
    NSLog(@"Disable recording");

    title = [command.arguments objectAtIndex:0];
    content = [command.arguments objectAtIndex:1];
    
    stopRecording = true;
    [self setupView];
    preventedView = [[CustomView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    preventedView.secureTextEntry = YES;
    preventedView.translatesAutoresizingMaskIntoConstraints = YES;
    
    for (UIView *subview in preventedView.subviews) {
        if ([NSStringFromClass([subview class]) containsString:@"CanvasView"]) {
            secureView = subview;
            secureView.frame = preventedView.frame;
            secureView.userInteractionEnabled = YES;
            secureView.translatesAutoresizingMaskIntoConstraints = NO;
            
            break;
        }
    }
    
    [secureView addSubview:self.webView];
    
    [self.viewController.view addSubview:secureView];

    [NSLayoutConstraint activateConstraints:@[
        [secureView.topAnchor constraintEqualToAnchor:self.viewController.view.topAnchor],
        [secureView.bottomAnchor constraintEqualToAnchor:self.viewController.view.bottomAnchor],
        [secureView.leadingAnchor constraintEqualToAnchor:self.viewController.view.leadingAnchor],
        [secureView.trailingAnchor constraintEqualToAnchor:self.viewController.view.trailingAnchor]
    ]];
    
    // Below code to add it to front
    [self.viewController.view bringSubviewToFront:self.webView];
    [self.webView becomeFirstResponder];
}


-(void) goingBackground {
    NSLog(@"Me la scattion in bck");
    if(_eventCommand!=nil) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"background"];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:_eventCommand.callbackId];
    }
}
-(void)tookScreeshot {
    NSLog(@"fatta la foto?");
    if(_eventCommand!=nil) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"tookScreenshot"];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:_eventCommand.callbackId];
    }

}

-(void)setupView {
    BOOL isCaptured = [[UIScreen mainScreen] isCaptured];
    NSLog(@"Is screen captured? %@", (isCaptured?@"SI":@"NO"));

    if ([[ScreenRecordingDetector sharedInstance] isRecording] && stopRecording) {
        [self webView].alpha = 0.f;

//        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
//                                                                       message:content
//                                                                preferredStyle:UIAlertControllerStyleAlert];
//
//        UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK"
//                                                     style:UIAlertActionStyleDefault
//                                                   handler:nil];
//
//        [alert addAction:ok];
//
//        // Present the alert from your view controller
//        [self.viewController presentViewController:alert animated:YES completion:nil];

        // Create the label
        
        NSString *notification = [NSString stringWithFormat:@"%@\n%@", title, content];

        
        stopRecordingLabel = [[UILabel alloc] init];
        stopRecordingLabel.text = notification;
        stopRecordingLabel.textColor = [UIColor blackColor];
//        stopRecordingLabel.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
        stopRecordingLabel.textAlignment = NSTextAlignmentCenter;
        stopRecordingLabel.font = [UIFont boldSystemFontOfSize:14];
        stopRecordingLabel.clipsToBounds = YES;
        stopRecordingLabel.numberOfLines = 0;
        
        // Get the superview of the webView
        UIView *parentView = self.webView.superview;

        CGFloat labelWidth = parentView.bounds.size.width - 60;
        CGFloat labelHeight = parentView.bounds.size.height - 60;

        // Center horizontally and vertically
        CGFloat x = 30;
        CGFloat y = 30;

        stopRecordingLabel.frame = CGRectMake(x, y, labelWidth, labelHeight);

        // Add to the main view above the webview
        [self.webView.superview addSubview:stopRecordingLabel];

        NSLog(@"Registro o prendo screenshots");
    } else {
        if (stopRecordingLabel) {
            [stopRecordingLabel removeFromSuperview];
            stopRecordingLabel = nil;
        }
        [self webView].alpha = 1.f;
        NSLog(@"Non registro");

    }
    

}

-(void)appDidBecomeActive {
    [ScreenRecordingDetector triggerDetectorTimer];
    if(cover!=nil) {
        [cover removeFromSuperview];
        cover = nil;
    }
}
-(void)applicationWillResignActive {
    [ScreenRecordingDetector stopDetectorTimer];
    if (cover == nil) {
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        UIView *overlayView = [[UIView alloc] initWithFrame:screenBounds];
        overlayView.backgroundColor = [UIColor whiteColor];
        overlayView.alpha = 0.0;
        overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        cover = [[UIImageView alloc] initWithFrame:screenBounds];
        [cover addSubview:overlayView];
        [self.webView addSubview:cover];
        [UIView animateWithDuration:0.5
                         animations:^{
                             overlayView.alpha = 0.95;
                         }];
    }
}

-(void)screenCaptureStatusChanged {
    [self setupView];
}

@end

@implementation CustomView

// Allow this view to become the first responder
- (BOOL)canBecomeFirstResponder {
    return YES;
}

// Called when the view becomes the first responder
- (BOOL)becomeFirstResponder {
    return YES;
}

@end
