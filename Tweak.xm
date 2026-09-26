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

%ctor {
    %init;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DDDoctorLogEvent(@"AUTO_DIAGNOSTIC", @"Unified fullscreen runtime snapshot");
        DDDoctorWrite(NO, YES, DDDiagnosticStatusBarWindow());
    });
}
