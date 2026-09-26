#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <notify.h>

@interface DBStatusBarWindow : UIWindow @end
@interface DBAnimationView : UIView @end

static BOOL DDFullscreen = NO;
static CGRect DDNormalDashboardFrame = {{0,0},{0,0}};
static BOOL DDHaveDashboardFrame = NO;
static const NSInteger DDFullButtonTag = 771133;

static BOOL DDIsCarPlayScreen(UIScreen *screen) {
    if (!screen) return NO;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        if (ws.screen != screen) continue;
        NSString *role=scene.session.role ?: @"";
        if ([role rangeOfString:@"CarPlay" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    }
    return NO;
}
static void DDWalkViews(UIView *view, void (^block)(UIView *)) {
    if (!view) return; block(view);
    for (UIView *child in view.subviews) DDWalkViews(child, block);
}
static void DDWalkVC(UIViewController *vc, void (^block)(UIViewController *)) {
    if (!vc) return; block(vc);
    for (UIViewController *child in vc.childViewControllers) DDWalkVC(child, block);
    if (vc.presentedViewController) DDWalkVC(vc.presentedViewController, block);
}
static UIWindow *DDStatusBarWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        if (!DDIsCarPlayScreen(ws.screen)) continue;
        for (UIWindow *w in ws.windows)
            if ([NSStringFromClass(w.class) containsString:@"DBStatusBarWindow"]) return w;
    }
    return nil;
}
static UIView *DDDashboardContentView(void) {
    __block UIView *found=nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        if (!DDIsCarPlayScreen(ws.screen)) continue;
        for (UIWindow *w in ws.windows) {
            if ([NSStringFromClass(w.class) containsString:@"DBStatusBarWindow"]) continue;
            DDWalkViews(w.rootViewController.view, ^(UIView *v){
                if (!found && [NSStringFromClass(v.class) containsString:@"DBAnimationView"]) found=v;
            });
        }
    }
    return found;
}
static void DDInvokeBool(id obj, NSString *name, BOOL value) {
    SEL sel=NSSelectorFromString(name);
    if (!obj || ![obj respondsToSelector:sel]) return;
    NSMethodSignature *sig=[obj methodSignatureForSelector:sel];
    if (!sig || sig.numberOfArguments != 3) return;
    NSInvocation *inv=[NSInvocation invocationWithMethodSignature:sig];
    inv.target=obj; inv.selector=sel; [inv setArgument:&value atIndex:2]; [inv invoke];
}
static void DDSetNativeChromeHidden(BOOL hidden) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        if (!DDIsCarPlayScreen(ws.screen)) continue;
        for (UIWindow *w in ws.windows) DDWalkVC(w.rootViewController, ^(UIViewController *vc){
            NSString *cn=NSStringFromClass(vc.class);
            if ([cn containsString:@"DBApplicationViewController"] || [cn containsString:@"DBDashboard"]) {
                DDInvokeBool(vc,@"setDefaultAppChromeHidden:",hidden);
                DDInvokeBool(vc,@"setNativeChromeHidden:",hidden);
            }
        });
    }
}
static void DDForceDashboardGeometry(void) {
    UIView *content=DDDashboardContentView();
    if (!content || !content.superview) return;
    if (DDFullscreen) {
        CGRect full=content.superview.bounds;
        if (!CGRectIsEmpty(full)) content.frame=full;
    } else if (DDHaveDashboardFrame) content.frame=DDNormalDashboardFrame;
    [content setNeedsLayout];
}
static void DDTrace(NSString *event) {
    UIWindow *bar=DDStatusBarWindow(); UIView *content=DDDashboardContentView();
    NSString *line=[NSString stringWithFormat:@"%@ fullscreen=%d bar=%@ barHidden=%d content=%@ super=%@ process=%@\n",
                    event,DDFullscreen,bar?NSStringFromCGRect(bar.frame):@"nil",bar?bar.hidden:-1,
                    content?NSStringFromCGRect(content.frame):@"nil",
                    content.superview?NSStringFromCGRect(content.superview.bounds):@"nil",
                    NSProcessInfo.processInfo.processName];
    CFPropertyListRef old=CFPreferencesCopyAppValue(CFSTR("payload.DDTRACE"),CFSTR("com.chuong.daudat.diagnostic"));
    NSString *prev=(old && CFGetTypeID(old)==CFStringGetTypeID())?[(__bridge NSString *)old copy]:@"";
    NSString *all=[prev stringByAppendingString:line]; if (old) CFRelease(old);
    CFPreferencesSetAppValue(CFSTR("payload.DDTRACE"),(__bridge CFStringRef)all,CFSTR("com.chuong.daudat.diagnostic"));
    CFPreferencesAppSynchronize(CFSTR("com.chuong.daudat.diagnostic"));
    NSLog(@"[DauDat] %@",line);
    NSData *data=[line dataUsingEncoding:NSUTF8StringEncoding];
    NSString *path=@"/var/mobile/Documents/DauDat-CarPlay.log";
    NSFileManager *fm=NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:path]) [data writeToFile:path atomically:YES];
    else {
        NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:path];
        [h seekToEndOfFile]; [h writeData:data]; [h closeFile];
    }
}
static void DDInstallButton(UIWindow *bar);
static void DDSetFullscreen(BOOL enabled) {
    if (enabled==DDFullscreen) return;
    UIWindow *bar=DDStatusBarWindow(); UIView *content=DDDashboardContentView();
    if (!bar || !content || !content.superview) { DDTrace(@"FULLSCREEN_ABORT_MISSING_HOST"); return; }
    DDTrace(enabled?@"FULLSCREEN_ENTER_BEGIN":@"FULLSCREEN_EXIT_BEGIN");
    if (enabled) {
        DDNormalDashboardFrame=content.frame; DDHaveDashboardFrame=YES;\n        DDNormalHostWindowFrame=content.window.frame; DDHaveHostWindowFrame=YES; DDFullscreen=YES;
        DDSetNativeChromeHidden(YES); bar.hidden=YES; DDForceDashboardGeometry();
    } else {
        DDFullscreen=NO; bar.hidden=NO; DDSetNativeChromeHidden(NO);
        DDForceDashboardGeometry(); DDInstallButton(bar);
    }
    dispatch_async(dispatch_get_main_queue(), ^{ DDForceDashboardGeometry(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(120*NSEC_PER_MSEC)),dispatch_get_main_queue(),^{ DDForceDashboardGeometry(); });
    DDTrace(enabled?@"FULLSCREEN_ENTER_END":@"FULLSCREEN_EXIT_END");
}
static void DDInstallButton(UIWindow *bar) {
    if (!bar || ![NSStringFromClass(bar.class) containsString:@"DBStatusBarWindow"]) return;
    UIButton *b=(UIButton *)[bar viewWithTag:DDFullButtonTag];
    if (!b) {
        b=[UIButton buttonWithType:UIButtonTypeSystem]; b.tag=DDFullButtonTag;
        CGFloat side=34.0;
        b.frame=CGRectMake(MAX(3.0,(bar.bounds.size.width-side)/2.0),4.0,side,side);
        b.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
        UIImageSymbolConfiguration *cfg=[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
        [b setImage:[UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right" withConfiguration:cfg] forState:UIControlStateNormal];
        b.tintColor=UIColor.whiteColor; b.imageView.backgroundColor=UIColor.clearColor; b.accessibilityLabel=@"Fullscreen";
        [b addAction:[UIAction actionWithHandler:^(__kindof UIAction *a){ (void)a; DDSetFullscreen(YES); }]
          forControlEvents:UIControlEventTouchUpInside];
        [bar addSubview:b]; DDTrace(@"FULLSCREEN_BUTTON_CREATED");
    }
    b.hidden=DDFullscreen;
}
%hook DBStatusBarWindow
- (void)didAddSubview:(UIView *)view {
    %orig;
    (void)view;
    DDInstallButton((UIWindow *)self);
}
- (void)didMoveToScreen:(UIScreen *)screen {
    %orig;
    if (screen) DDInstallButton((UIWindow *)self);
}
- (void)layoutSubviews {
    %orig;
    if (!DDFullscreen) DDInstallButton((UIWindow *)self);
}
%end

%hook DBAnimationView
- (void)layoutSubviews {
    %orig;
    if (DDFullscreen) DDForceDashboardGeometry();
}
%end
%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (DDFullscreen && DDIsCarPlayScreen(self.screen) && event.type==UIEventTypeTouches) {
        for (UITouch *t in event.allTouches) {
            if (t.phase!=UITouchPhaseEnded) continue;
            CGPoint p=[t locationInView:self];
            if (p.x<=44.0 && p.y<=44.0) { DDTrace(@"FULLSCREEN_RESTORE_HITZONE"); DDSetFullscreen(NO); return; }
        }
    }
    %orig;
}
%end
%ctor {
    %init;
    NSString *process=NSProcessInfo.processInfo.processName ?: @"";
    if ([process isEqualToString:@"CarPlay"] || [process isEqualToString:@"CarPlayApp"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            UIWindow *bar=DDStatusBarWindow();
            if (bar) DDInstallButton(bar); else DDTrace(@"FULLSCREEN_BUTTON_NO_STATUSBAR");
        });
    }
}