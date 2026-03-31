#import <Cordova/CDV.h>
#import "ScreenRecordingDetector.h"


@interface ScreenshotBlocker : CDVPlugin

- (void)enable:(CDVInvokedUrlCommand*)command;
-(void)listen:(CDVInvokedUrlCommand*)command;
-(void)disable:(CDVInvokedUrlCommand*)command;

@end

@interface CustomView : UITextField

@end

