#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <math.h>
#import <notify.h>
#import "DauDatConfig.h"
#import "DauDatDoctor.h"

@interface DDz1 : NSObject
+ (instancetype)shared;
- (BOOL)visible;
- (CGRect)shellBounds;
- (CGRect)carPlayUsableBounds;
- (UIView *)splitHostView;
- (void)setAppContentFrame:(CGRect)frame;
- (void)layoutGutterStripMatInHost:(UIView *)host;
@end

@interface DDz3 : NSObject
- (instancetype)initWithHost:(UIView *)host leftBid:(NSString *)left rightBid:(NSString *)right;
- (instancetype)initWithHost:(UIView *)host slotBids:(NSArray *)bids;
- (void)placeGutterControls;
- (void)nudgePillsClearOfGutter;
- (void)refreshResizeVisuals;
- (void)detach;
@end

@interface CNABHandleView : UIView
- (UIView *)chip;
@end

@interface CNABDividerView : UIView
- (BOOL)vertical;
- (UIView *)knob;
- (NSArray *)dots;
@end

static BOOL DDFullscreen = NO;
static BOOL DDHaveNormalFrame = NO;
static CGRect DDNormalFrame;
static __weak DDz3 *DDActiveUI = nil;
static NSMapTable<UIWindow *, NSNumber *> *DDChromeState = nil;
static NSUInteger DDTraceSeq = 0;

static NSString *DDTraceRect(CGRect r) { return NSStringFromCGRect(r); }

static BOOL DDCP(UIScreen *s) {
    if (!s) return NO;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        if (ws.screen != s) continue;
        NSString *role=scene.session.role ?: @"";
        if ([role rangeOfString:@"CarPlay" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    }
    return NO;
}

static DDz1 *DDHost(void) {
    Class cls=NSClassFromString(@"DDz1");
    if (!cls || ![cls respondsToSelector:@selector(shared)]) return nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return (DDz1 *)[cls performSelector:@selector(shared)];
#pragma clang diagnostic pop
}

static BOOL DDDuoDashPresent(void) {
    return NSClassFromString(@"DDz1") != Nil;
}

static BOOL DDDuoDashVisible(void) {
    DDz1 *host=DDHost();
    return host && [host respondsToSelector:@selector(visible)] && host.visible;
}

static void DDTrace(NSString *event) {
    NSMutableString *s=[NSMutableString stringWithFormat:@"DDTRACE #%lu event=%@ fullscreen=%d process=%@\n",
                        (unsigned long)++DDTraceSeq,event,DDFullscreen,NSProcessInfo.processInfo.processName];
    DDz1 *host=DDHost();
    if (host) {
        CGRect shell=[host shellBounds];
        CGRect usable=[host carPlayUsableBounds];
        UIView *split=[host splitHostView];
        [s appendFormat:@"DUODASH visible=%d shell=%@ usable=%@ splitFrame=%@ splitBounds=%@\n",
         host.visible,DDTraceRect(shell),DDTraceRect(usable),
         split?DDTraceRect(split.frame):@"nil",split?DDTraceRect(split.bounds):@"nil"];
    }
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        if (!DDCP(ws.screen)) continue;
        [s appendFormat:@"SCENE role=%@ screen=%@ scale=%.2f windows=%lu\n",
         scene.session.role,DDTraceRect(ws.screen.bounds),ws.screen.scale,(unsigned long)ws.windows.count];
        for (UIWindow *w in ws.windows) {
            [s appendFormat:@"WIN %@ frame=%@ safe=%@ hidden=%d root=%@\n",
             NSStringFromClass(w.class),DDTraceRect(w.frame),NSStringFromUIEdgeInsets(w.safeAreaInsets),w.hidden,
             w.rootViewController?NSStringFromClass(w.rootViewController.class):@"nil"];
        }
    }
    NSString *key=@"payload.DDTRACE";
    CFPropertyListRef old=CFPreferencesCopyAppValue((__bridge CFStringRef)key,CFSTR("com.chuong.daudat.diagnostic"));
    NSString *prev=(old && CFGetTypeID(old)==CFStringGetTypeID()) ? [(__bridge NSString *)old copy] : @"";
    NSString *all=[prev stringByAppendingFormat:@"\n%@",s];
    if (old) CFRelease(old);
    CFPreferencesSetAppValue((__bridge CFStringRef)key,(__bridge CFStringRef)all,CFSTR("com.chuong.daudat.diagnostic"));
    CFPreferencesAppSynchronize(CFSTR("com.chuong.daudat.diagnostic"));
    NSLog(@"%@",s);
}

static BOOL DDChromeWindow(UIWindow *w) {
    NSString *cn=NSStringFromClass(w.class);
    return [cn containsString:@"DBStatusBarWindow"] || [cn containsString:@"DBDockWindow"];
}

static void DDSetChromeHidden(BOOL hidden) {
    if (!DDChromeState) DDChromeState=[NSMapTable weakToStrongObjectsMapTable];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        if (!DDCP(ws.screen)) continue;
        for (UIWindow *w in ws.windows) {
            if (!DDChromeWindow(w)) continue;
            if (hidden) {
                if (![DDChromeState objectForKey:w]) [DDChromeState setObject:@(w.hidden) forKey:w];
                w.hidden=YES;
            } else {
                NSNumber *prior=[DDChromeState objectForKey:w];
                if (prior) w.hidden=prior.boolValue;
                [DDChromeState removeObjectForKey:w];
            }
        }
    }
}

static void DDRelayoutDuoDash(void) {
    DDz1 *host=DDHost();
    if (!host) return;
    UIView *split=[host splitHostView];
    if (split) {
        [split setNeedsLayout];
        [split layoutIfNeeded];
        if ([host respondsToSelector:@selector(layoutGutterStripMatInHost:)]) [host layoutGutterStripMatInHost:split];
    }
    DDz3 *ui=DDActiveUI;
    if (ui) {
        if ([ui respondsToSelector:@selector(placeGutterControls)]) [ui placeGutterControls];
        if ([ui respondsToSelector:@selector(nudgePillsClearOfGutter)]) [ui nudgePillsClearOfGutter];
        if ([ui respondsToSelector:@selector(refreshResizeVisuals)]) [ui refreshResizeVisuals];
    }
}

static void DDApplyContentFrame(CGRect frame) {
    DDz1 *host=DDHost();
    if (!host || CGRectIsEmpty(frame) || frame.size.width < 40.0 || frame.size.height < 40.0) return;
    [host setAppContentFrame:frame];
    DDRelayoutDuoDash();
    dispatch_async(dispatch_get_main_queue(), ^{ DDRelayoutDuoDash(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(120*NSEC_PER_MSEC)),dispatch_get_main_queue(),^{ DDRelayoutDuoDash(); });
}

static void DDInstallFullscreenButton(UIWindow *w);
static void DDUpdateButtonVisibility(void) {
    BOOL show=DDDuoDashVisible() && !DDFullscreen;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        if (!DDCP(ws.screen)) continue;
        for (UIWindow *w in ws.windows) {
            if (![NSStringFromClass(w.class) containsString:@"DBStatusBarWindow"]) continue;
            DDInstallFullscreenButton(w);
            UIView *button=[w viewWithTag:771133];
            button.hidden=!show;
        }
    }
}

static void DDApplyNativeFullscreen(BOOL enabled) {
    DDz1 *host=DDHost();
    if (!host || !DDDuoDashVisible() || enabled==DDFullscreen) return;

    DDTrace(enabled?@"FULLSCREEN_ENTER_BEGIN":@"FULLSCREEN_EXIT_BEGIN");

    if (enabled) {
        CGRect normal=[host carPlayUsableBounds];
        if (!CGRectIsEmpty(normal)) { DDNormalFrame=normal; DDHaveNormalFrame=YES; }
        CGRect full=[host shellBounds];
        DDFullscreen=YES;
        // Airaw order: resize hosted root first, then hide native chrome, then relayout controls/scenes.
        DDApplyContentFrame(full);
        DDSetChromeHidden(YES);
        DDRelayoutDuoDash();
    } else {
        DDFullscreen=NO;
        DDSetChromeHidden(NO);
        CGRect normal=DDHaveNormalFrame?DDNormalFrame:[host carPlayUsableBounds];
        DDApplyContentFrame(normal);
        // Re-read DuoDash's own normal usable geometry after CarPlay chrome is visible again.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(180*NSEC_PER_MSEC)),dispatch_get_main_queue(),^{
            if (DDFullscreen) return;
            DDz1 *h=DDHost();
            if (!h) return;
            CGRect refreshed=[h carPlayUsableBounds];
            if (!CGRectIsEmpty(refreshed)) {
                DDNormalFrame=refreshed; DDHaveNormalFrame=YES;
                DDApplyContentFrame(refreshed);
            }
            DDUpdateButtonVisibility();
        });
    }
    DDUpdateButtonVisibility();
    DDTrace(enabled?@"FULLSCREEN_ENTER_END":@"FULLSCREEN_EXIT_END");
}

static void DDToggleFullscreen(void) {
    if (DDDuoDashPresent() && DDDuoDashVisible()) DDApplyNativeFullscreen(!DDFullscreen);
}

static void DDInstallFullscreenButton(UIWindow *w) {
    if (!w || ![NSStringFromClass(w.class) containsString:@"DBStatusBarWindow"]) return;
    UIButton *existing=(UIButton *)[w viewWithTag:771133];
    if (existing) {
        existing.hidden=!(DDDuoDashVisible() && !DDFullscreen);
        return;
    }
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
    b.tag=771133;
    CGFloat side=MIN(MAX(32.0,MIN(w.bounds.size.width-6.0,36.0)),36.0);
    b.frame=CGRectMake(MAX(3.0,(w.bounds.size.width-side)/2.0),4.0,side,side);
    b.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
    b.layer.cornerRadius=9.0;
    b.backgroundColor=UIColor.clearColor;
    UIImageSymbolConfiguration *cfg=[UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
    [b setImage:[UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right" withConfiguration:cfg] forState:UIControlStateNormal];
    b.tintColor=UIColor.whiteColor;
    b.accessibilityLabel=@"DuoDash Fullscreen";
    [b addAction:[UIAction actionWithHandler:^(__kindof UIAction *a){ (void)a; DDToggleFullscreen(); }]
 forControlEvents:UIControlEventTouchUpInside];
    [w addSubview:b];
    b.hidden=!(DDDuoDashVisible() && !DDFullscreen);
}

static void DDStyleGlassView(UIView *v) {
    if (!v) return;
    v.backgroundColor=[UIColor colorWithWhite:0.08 alpha:0.42];
    v.layer.borderWidth=0.75;
    v.layer.borderColor=[UIColor colorWithWhite:1.0 alpha:0.24].CGColor;
    v.layer.cornerRadius=MIN(v.bounds.size.height,v.bounds.size.width)/2.0;
    v.layer.masksToBounds=NO;
}

static void DDStyleDivider(CNABDividerView *d) {
    UIView *knob=[d knob];
    if (!knob) return;
    knob.backgroundColor=[UIColor colorWithWhite:0.05 alpha:0.62];
    knob.layer.cornerRadius=MIN(knob.bounds.size.width,knob.bounds.size.height)/2.0;
    knob.layer.borderWidth=0.65;
    knob.layer.borderColor=[UIColor colorWithWhite:1.0 alpha:0.30].CGColor;
    for (id oldDot in [d dots]) if ([oldDot isKindOfClass:UIView.class]) ((UIView *)oldDot).hidden=YES;

    UIView *six=[knob viewWithTag:771136];
    if (!six) {
        six=[[UIView alloc] initWithFrame:knob.bounds];
        six.tag=771136;
        six.userInteractionEnabled=NO;
        six.backgroundColor=UIColor.clearColor;
        [knob addSubview:six];
        for (NSInteger i=0;i<6;i++) {
            UIView *dot=[[UIView alloc] initWithFrame:CGRectZero];
            dot.tag=771140+i;
            dot.backgroundColor=[UIColor colorWithWhite:1.0 alpha:0.88];
            dot.layer.cornerRadius=1.15;
            [six addSubview:dot];
        }
    }
    six.frame=knob.bounds;
    CGFloat cx=CGRectGetMidX(six.bounds), cy=CGRectGetMidY(six.bounds);
    CGFloat sx=4.2, sy=4.2, dot=2.3;
    for (NSInteger i=0;i<6;i++) {
        NSInteger col=i%2, row=i/2;
        UIView *v=[six viewWithTag:771140+i];
        v.frame=CGRectMake(cx+(col?0.5:-1.5)*sx-dot/2.0,
                           cy+(row-1)*sy-dot/2.0,dot,dot);
        v.layer.cornerRadius=dot/2.0;
    }
}

static UILabel *DDPercentLabel(CNABDividerView *d) {
    UILabel *l=(UILabel *)[d viewWithTag:771137];
    if (!l) {
        l=[[UILabel alloc] initWithFrame:CGRectMake((d.bounds.size.width-48.0)/2.0,-24.0,48.0,20.0)];
        l.tag=771137;
        l.textAlignment=NSTextAlignmentCenter;
        l.font=[UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
        l.textColor=UIColor.whiteColor;
        l.backgroundColor=[UIColor colorWithWhite:0.04 alpha:0.78];
        l.layer.cornerRadius=8.0;
        l.layer.masksToBounds=YES;
        l.hidden=YES;
        l.userInteractionEnabled=NO;
        [d addSubview:l];
    }
    return l;
}

static void DDUpdatePercent(CNABDividerView *d, UITouch *touch) {
    if (!d.superview || !touch) return;
    CGPoint p=[touch locationInView:d.superview];
    CGFloat denom=[d vertical]?d.superview.bounds.size.width:d.superview.bounds.size.height;
    CGFloat pos=[d vertical]?p.x:p.y;
    if (denom < 1.0) return;
    NSInteger pct=(NSInteger)llround(MAX(0.0,MIN(1.0,pos/denom))*100.0);
    UILabel *l=DDPercentLabel(d);
    l.frame=CGRectMake((d.bounds.size.width-48.0)/2.0,-24.0,48.0,20.0);
    l.text=[NSString stringWithFormat:@"%ld%%",(long)pct];
    l.hidden=NO;
}

%hook DDz1
- (CGRect)carPlayUsableBounds {
    CGRect normal=%orig;
    if (!DDFullscreen) return normal;
    CGRect full=[self shellBounds];
    return CGRectIsEmpty(full)?normal:full;
}
- (BOOL)present {
    BOOL ok=%orig;
    dispatch_async(dispatch_get_main_queue(), ^{ DDUpdateButtonVisibility(); });
    return ok;
}
- (void)hide {
    if (DDFullscreen) DDApplyNativeFullscreen(NO);
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{ DDUpdateButtonVisibility(); });
}
%end

%hook DDz3
- (id)initWithHost:(UIView *)host leftBid:(NSString *)left rightBid:(NSString *)right {
    id obj=%orig;
    if (obj) DDActiveUI=(DDz3 *)obj;
    return obj;
}
- (id)initWithHost:(UIView *)host slotBids:(NSArray *)bids {
    id obj=%orig;
    if (obj) DDActiveUI=(DDz3 *)obj;
    return obj;
}
- (void)detach {
    BOOL was=(DDActiveUI==(DDz3 *)self);
    %orig;
    if (was) DDActiveUI=nil;
}
- (id)makeChromeButton:(NSString *)title frame:(CGRect)frame action:(SEL)action {
    UIControl *c=(UIControl *)%orig;
    if (!c) return c;
    DDStyleGlassView(c);
    NSString *sel=NSStringFromSelector(action);
    BOOL isSwap=[sel isEqualToString:@"onSwapPressed:"] || [sel isEqualToString:@"onGutterSwapPressed:"] ||
                [title rangeOfString:@"swap" options:NSCaseInsensitiveSearch].location!=NSNotFound;
    if (isSwap) {
        UILabel *label=(UILabel *)[c viewWithTag:0x1b5d];
        label.hidden=YES;
        UIImageView *iv=(UIImageView *)[c viewWithTag:771138];
        if (!iv) {
            UIImageSymbolConfiguration *cfg=[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
            iv=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"arrow.left.arrow.right" withConfiguration:cfg]];
            iv.tag=771138;
            iv.contentMode=UIViewContentModeCenter;
            iv.tintColor=UIColor.whiteColor;
            iv.userInteractionEnabled=NO;
            [c addSubview:iv];
        }
        iv.frame=c.bounds;
        iv.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    }
    return c;
}
%end

%hook CNABHandleView
- (void)layoutSubviews {
    %orig;
    UIView *chip=[self chip];
    if (chip) {
        DDStyleGlassView(chip);
        chip.layer.cornerRadius=MIN(chip.bounds.size.height,chip.bounds.size.width)/2.0;
    }
}
- (void)setPressed:(BOOL)pressed {
    %orig;
    UIView *chip=[self chip];
    if (!chip) return;
    chip.layer.shadowColor=UIColor.whiteColor.CGColor;
    chip.layer.shadowRadius=pressed?8.0:0.0;
    chip.layer.shadowOpacity=pressed?0.32:0.0;
    chip.layer.shadowOffset=CGSizeZero;
    [UIView animateWithDuration:0.12 animations:^{ chip.transform=pressed?CGAffineTransformMakeScale(1.05,1.05):CGAffineTransformIdentity; }];
}
%end

%hook CNABDividerView
- (void)layoutSubviews {
    %orig;
    self.clipsToBounds=NO;
    DDStyleDivider((CNABDividerView *)self);
}
- (void)setHighlighted:(BOOL)highlighted {
    %orig;
    UIView *knob=[self knob];
    if (!knob) return;
    knob.layer.shadowColor=UIColor.whiteColor.CGColor;
    knob.layer.shadowRadius=highlighted?9.0:0.0;
    knob.layer.shadowOpacity=highlighted?0.42:0.0;
    knob.layer.shadowOffset=CGSizeZero;
    [UIView animateWithDuration:0.12 animations:^{ knob.transform=highlighted?CGAffineTransformMakeScale(1.10,1.10):CGAffineTransformIdentity; }];
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    DDUpdatePercent((CNABDividerView *)self,touches.anyObject);
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    DDUpdatePercent((CNABDividerView *)self,touches.anyObject);
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    UILabel *l=(UILabel *)[self viewWithTag:771137]; l.hidden=YES;
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    UILabel *l=(UILabel *)[self viewWithTag:771137]; l.hidden=YES;
}
%end

%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (DDFullscreen && DDDuoDashVisible() && DDCP(self.screen) && event.type==UIEventTypeTouches) {
        for (UITouch *t in event.allTouches) {
            if (t.phase!=UITouchPhaseEnded) continue;
            CGPoint p=[t locationInView:self];
            if (p.x<=44.0 && p.y<=44.0) {
                DDTrace(@"FULLSCREEN_RESTORE_HITZONE");
                DDApplyNativeFullscreen(NO);
                return;
            }
        }
    }
    %orig;
}
%end

%hook DBStatusBarWindow
- (void)didAddSubview:(UIView *)subview {
    %orig;
    (void)subview;
    if (DDDuoDashPresent()) DDInstallFullscreenButton((UIWindow *)self);
}
- (void)didMoveToScreen:(UIScreen *)screen {
    %orig;
    if (screen && DDDuoDashPresent()) DDInstallFullscreenButton((UIWindow *)self);
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
    CFPropertyListRef trace=CFPreferencesCopyAppValue(CFSTR("payload.DDTRACE"),CFSTR("com.chuong.daudat.diagnostic"));
    if (trace && CFGetTypeID(trace)==CFStringGetTypeID()) {
        NSString *path=@"/var/mobile/Documents/DuoDash-DDTRACE.txt";
        [(__bridge NSString *)trace writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    if (trace) CFRelease(trace);
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
