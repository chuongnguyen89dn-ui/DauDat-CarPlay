#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <math.h>
#import "DauDatConfig.h"
#import "DauDatDoctor.h"

static const CGFloat DDW = 427.0;
static const CGFloat DDH = 240.0;
static const CGFloat DDSide = 45.0;

static BOOL DDCP(UIScreen *s) {
    if (!s || s == UIScreen.mainScreen) return NO;
    CGSize z = s.bounds.size;
    return (fabs(z.width-DDW)<3.0 && fabs(z.height-DDH)<3.0) ||
           (fabs(z.height-DDW)<3.0 && fabs(z.width-DDH)<3.0);
}

static BOOL DDReserved(CGRect f) {
    return fabs(f.origin.x-DDSide)<3.0 || (f.size.width>370.0 && f.size.width<390.0);
}

%hook UIWindow
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets original = %orig;
    if (DDCP(self.screen)) return UIEdgeInsetsZero;
    return original;
}
%end

%hook UIView
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets original = %orig;
    if (DDCP(self.window.screen)) return UIEdgeInsetsZero;
    return original;
}

- (void)didMoveToWindow {
    %orig;
    UIWindow *w = self.window;
    if (!w || !DDCP(w.screen)) return;
    if ([NSStringFromClass(self.class) isEqualToString:@"DBStatusBarView"]) return;

    CGRect f = self.frame;
    if (DDReserved(f)) {
        f.origin.x = 0.0;
        f.size.width = DDW;
        f.size.height = DDH;
        self.frame = f;
        self.autoresizingMask |= UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
}
%end

%hook DBStatusBarWindow
- (void)setFrame:(CGRect)frame {
    if (DDCP(((UIWindow *)self).screen)) {
        CGFloat width = frame.size.width > 1.0 ? frame.size.width : DDSide;
        frame.origin.x = -fabs(width);
    }
    %orig(frame);
}
%end

static UIWindow *DDDiagnosticStatusBarWindow(void) {
    Class cls = NSClassFromString(@"DBStatusBarWindow");
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (cls && [w isKindOfClass:cls]) return w;
        }
    }
    return nil;
}

static void DDWriteProcessDiagnostic(void) {
    NSString *process = NSProcessInfo.processInfo.processName ?: @"Unknown";
    if (![process isEqualToString:@"CarPlay"] && ![process isEqualToString:@"CarPlayTemplateUIHost"]) return;

    UIWindow *bar = DDDiagnosticStatusBarWindow();
    NSMutableString *report = [[DDDoctorSnapshot(YES, bar) mutableCopy] ?: [NSMutableString string] mutableCopy];
    [report appendFormat:@"\n=== GEOMETRY ASSESSMENT ===\n%@\n", DDDoctorGeometryAssessment()];

    NSString *safeName = [process stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    NSString *path = [@"/var/mobile/Documents" stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"DauDat-%@.txt", safeName]];
    [report writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    DDDoctorLogEvent(@"PROCESS_DIAGNOSTIC", path);
}

%ctor {
    %init;
    NSString *process = NSProcessInfo.processInfo.processName ?: @"";
    if ([process isEqualToString:@"CarPlay"] || [process isEqualToString:@"CarPlayTemplateUIHost"]) {
        DDDoctorLogEvent(@"INJECT_PROCESS_LOGGER", process);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            DDWriteProcessDiagnostic();
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            DDWriteProcessDiagnostic();
        });
    }
}
