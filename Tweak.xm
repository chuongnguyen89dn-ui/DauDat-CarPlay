#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <math.h>
#import <notify.h>
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
    if (DDCP(self.screen)) return DDCarPlayInsets(original);
    return original;
}
%end

%hook UIView
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets original = %orig;
    if (DDCP(self.window.screen)) return DDCarPlayInsets(original);
    return original;
}

- (void)didMoveToWindow {
    %orig;
    UIWindow *w = self.window;
    if (!w || !DDCP(w.screen)) return;
    NSString *cls = NSStringFromClass(self.class);
    if ([cls isEqualToString:@"DBStatusBarView"]) return;

    CGRect f = self.frame;
    if (DDReserved(f, w.screen)) {
        f.origin.x = 0.0;
        f.size.width = w.screen.bounds.size.width;
        self.frame = f;
        self.autoresizingMask |= UIViewAutoresizingFlexibleWidth;
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
- (void)didMoveToScreen:(UIScreen *)screen {
    %orig;
    if (DDCP(screen)) {
        CGRect f=((UIWindow *)self).frame;
        f.origin.x=-fabs(f.size.width > 1.0 ? f.size.width : DDSide);
        ((UIWindow *)self).frame=f;
    }
}
%end

%hook DBNotificationWindow
- (void)setFrame:(CGRect)frame {
    UIScreen *s=((UIWindow *)self).screen;
    if (DDCP(s) && DDReserved(frame,s)) {
        frame.origin.x=0.0;
        frame.size.width=s.bounds.size.width;
    }
    %orig(frame);
}
%end

%hook DBAnimationView
- (void)setFrame:(CGRect)frame {
    UIScreen *s=((UIView *)self).window.screen;
    if (DDCP(s) && DDReserved(frame,s)) {
        frame.origin.x=0.0;
        frame.size.width=s.bounds.size.width;
    }
    %orig(frame);
}
%end

%hook CPSNavigationBar
- (void)setFrame:(CGRect)frame {
    UIScreen *s=((UIView *)self).window.screen;
    if (DDCP(s) && DDReserved(frame,s)) {
        frame.origin.x=0.0;
        frame.size.width=s.bounds.size.width;
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
    (void)DDDoctorWrite;
    NSString *process = NSProcessInfo.processInfo.processName ?: @"Unknown";
    if (![process isEqualToString:@"CarPlay"] && ![process isEqualToString:@"CarPlayTemplateUIHost"]) return;

    UIWindow *bar = DDDiagnosticStatusBarWindow();
    NSMutableString *report = [[DDDoctorSnapshot(YES, bar) mutableCopy] ?: [NSMutableString string] mutableCopy];
    [report appendFormat:@"\n=== GEOMETRY ASSESSMENT ===\n%@\n", DDDoctorGeometryAssessment()];

    [report appendString:@"\n=== COMPLETE WINDOW TREE ===\n"];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        [report appendFormat:@"SCENE role=%@ screen=%@ native=%@ scale=%.3f windows=%lu\n",
         scene.session.role, NSStringFromCGRect(ws.screen.bounds), NSStringFromCGRect(ws.screen.nativeBounds),
         ws.screen.scale, (unsigned long)ws.windows.count];
        for (UIWindow *w in ws.windows) {
            [report appendFormat:@"WINDOW class=%@ frame=%@ bounds=%@ safe=%@ hidden=%d level=%.1f root=%@\n",
             NSStringFromClass(w.class), NSStringFromCGRect(w.frame), NSStringFromCGRect(w.bounds),
             NSStringFromUIEdgeInsets(w.safeAreaInsets), w.hidden, w.windowLevel,
             w.rootViewController ? NSStringFromClass(w.rootViewController.class) : @"(null)"];
            NSMutableArray *q=[NSMutableArray array];
            if (w.rootViewController.view) [q addObject:@[w.rootViewController.view,@0]];
            while (q.count) {
                NSArray *it=q.firstObject; [q removeObjectAtIndex:0];
                UIView *v=it[0]; NSInteger d=[it[1] integerValue];
                [report appendFormat:@"depth=%ld VIEW class=%@ frame=%@ bounds=%@ safe=%@ hidden=%d alpha=%.3f transform=%@ subviews=%lu\n",
                 (long)d, NSStringFromClass(v.class), NSStringFromCGRect(v.frame), NSStringFromCGRect(v.bounds),
                 NSStringFromUIEdgeInsets(v.safeAreaInsets), v.hidden, v.alpha,
                 NSStringFromCGAffineTransform(v.transform), (unsigned long)v.subviews.count];
                if (d < 16) for (UIView *child in v.subviews) [q addObject:@[child,@(d+1)]];
            }
        }
    }
    [report appendFormat:@"\n=== PROCESS ===\nname=%@ pid=%d args=%@\n", process, getpid(), NSProcessInfo.processInfo.arguments];

    NSString *safeName = [process stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    NSString *fileName = [NSString stringWithFormat:@"DauDat-%@.txt", safeName];

    // CarPlay processes may be sandboxed. Write to their own writable tmp first,
    // then publish the complete report through Darwin notification + shared prefs.
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    NSError *tmpError = nil;
    BOOL tmpOK = [report writeToFile:tmpPath atomically:YES encoding:NSUTF8StringEncoding error:&tmpError];

    CFPreferencesSetAppValue((__bridge CFStringRef)[@"payload." stringByAppendingString:safeName],
                             (__bridge CFStringRef)report,
                             CFSTR("com.chuong.daudat.diagnostic"));
    CFPreferencesAppSynchronize(CFSTR("com.chuong.daudat.diagnostic"));
    notify_post("com.chuong.daudat.diagnostic.ready");

    DDDoctorLogEvent(@"PROCESS_DIAGNOSTIC",
                     [NSString stringWithFormat:@"tmp=%d path=%@ err=%@", tmpOK, tmpPath, tmpError]);
}

static void DDExportPendingReports(void) {
    NSString *domain = @"com.chuong.daudat.diagnostic";
    for (NSString *name in @[@"CarPlay", @"CarPlayTemplateUIHost"]) {
        NSString *key = [@"payload." stringByAppendingString:name];
        CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)domain);
        if (value && CFGetTypeID(value) == CFStringGetTypeID()) {
            NSString *payload = CFBridgingRelease(value);
            NSString *path = [@"/var/mobile/Documents" stringByAppendingPathComponent:
                              [NSString stringWithFormat:@"DauDat-%@.txt", name]];
            NSError *error=nil;
            [payload writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
            if (!error) {
                CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, (__bridge CFStringRef)domain);
                CFPreferencesAppSynchronize((__bridge CFStringRef)domain);
            }
        } else if (value) CFRelease(value);
    }
}

static void DDDiagnosticReady(int token) {
    dispatch_async(dispatch_get_main_queue(), ^{ DDExportPendingReports(); });
}

%ctor {
    %init;
    NSString *process = NSProcessInfo.processInfo.processName ?: @"";
    if ([process isEqualToString:@"SpringBoard"]) {
        int token=0;
        notify_register_dispatch("com.chuong.daudat.diagnostic.ready", &token,
                                 dispatch_get_main_queue(), ^(int t){ DDDiagnosticReady(t); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ DDExportPendingReports(); });
    }
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
