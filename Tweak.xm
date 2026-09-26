#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <notify.h>
#import "DauDatConfig.h"
#import "DauDatDoctor.h"

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
static NSString *DDGeometryDetail(void) {
    UIWindow *bar=DDStatusBarWindow();
    UIView *content=DDDashboardContentView();
    UIWindow *host=content.window;
    UIView *root=host.rootViewController.view;
    return [NSString stringWithFormat:@"fullscreen=%d barClass=%@ barFrame=%@ barBounds=%@ barHidden=%d hostClass=%@ hostFrame=%@ hostBounds=%@ rootClass=%@ rootFrame=%@ rootBounds=%@ contentClass=%@ contentFrame=%@ contentBounds=%@ superClass=%@ superFrame=%@ superBounds=%@",
        DDFullscreen,
        bar?NSStringFromClass(bar.class):@"nil",
        bar?NSStringFromCGRect(bar.frame):@"nil",
        bar?NSStringFromCGRect(bar.bounds):@"nil",
        bar?bar.hidden:-1,
        host?NSStringFromClass(host.class):@"nil",
        host?NSStringFromCGRect(host.frame):@"nil",
        host?NSStringFromCGRect(host.bounds):@"nil",
        root?NSStringFromClass(root.class):@"nil",
        root?NSStringFromCGRect(root.frame):@"nil",
        root?NSStringFromCGRect(root.bounds):@"nil",
        content?NSStringFromClass(content.class):@"nil",
        content?NSStringFromCGRect(content.frame):@"nil",
        content?NSStringFromCGRect(content.bounds):@"nil",
        content.superview?NSStringFromClass(content.superview.class):@"nil",
        content.superview?NSStringFromCGRect(content.superview.frame):@"nil",
        content.superview?NSStringFromCGRect(content.superview.bounds):@"nil"];
}
static void DDTrace(NSString *event) {
    NSString *detail=DDGeometryDetail();
    DDDoctorLogEvent(event,detail);
    NSLog(@"[DauDat] %@ | %@",event,detail);
    DDDoctorWrite(NO,DDFullscreen,DDStatusBarWindow());
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
    } else if (DDHaveDashboardFrame) {
        content.frame=DDNormalDashboardFrame;
    }
    [content setNeedsLayout];
}
static void DDInstallButton(UIWindow *bar);
static void DDSetFullscreen(BOOL enabled) {
    if (enabled==DDFullscreen) return;
    UIWindow *bar=DDStatusBarWindow(); UIView *content=DDDashboardContentView();
    if (!bar || !content || !content.superview) { DDTrace(@"FULLSCREEN_ABORT_MISSING_HOST"); return; }
    DDTrace(enabled?@"FULLSCREEN_ENTER_BEFORE":@"FULLSCREEN_EXIT_BEFORE");
    if (enabled) {
        DDNormalDashboardFrame=content.frame; DDHaveDashboardFrame=YES; DDFullscreen=YES;
        DDSetNativeChromeHidden(YES); bar.hidden=YES; DDForceDashboardGeometry();
    } else {
        DDFullscreen=NO; bar.hidden=NO; DDSetNativeChromeHidden(NO);
        DDForceDashboardGeometry(); DDInstallButton(bar);
    }
    DDTrace(enabled?@"FULLSCREEN_ENTER_IMMEDIATE":@"FULLSCREEN_EXIT_IMMEDIATE");
    dispatch_async(dispatch_get_main_queue(), ^{
        DDForceDashboardGeometry();
        DDTrace(enabled?@"FULLSCREEN_ENTER_NEXT_RUNLOOP":@"FULLSCREEN_EXIT_NEXT_RUNLOOP");
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(120*NSEC_PER_MSEC)),dispatch_get_main_queue(),^{
        DDForceDashboardGeometry();
        DDTrace(enabled?@"FULLSCREEN_ENTER_120MS":@"FULLSCREEN_EXIT_120MS");
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(500*NSEC_PER_MSEC)),dispatch_get_main_queue(),^{
        DDTrace(enabled?@"FULLSCREEN_ENTER_500MS":@"FULLSCREEN_EXIT_500MS");
    });
}
static void DDInstallButton(UIWindow *bar) {
    if (!bar || ![NSStringFromClass(bar.class) containsString:@"DBStatusBarWindow"]) return;
    UIButton *b=(UIButton *)[bar viewWithTag:DDFullButtonTag];
    if (!b) {
        b=[UIButton buttonWithType:UIButtonTypeCustom]; b.tag=DDFullButtonTag;
        CGFloat side=38.0;
        CGFloat y=MAX(4.0,bar.bounds.size.height-side-8.0);
        b.frame=CGRectMake(MAX(3.0,(bar.bounds.size.width-side)/2.0),y,side,side);
        b.autoresizingMask=UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
        b.backgroundColor=UIColor.clearColor; b.opaque=NO;
        UIImageSymbolConfiguration *cfg=[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
        [b setImage:[UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right" withConfiguration:cfg] forState:UIControlStateNormal];
        b.tintColor=UIColor.whiteColor; b.accessibilityLabel=@"Fullscreen";
        [b addAction:[UIAction actionWithHandler:^(__kindof UIAction *a){ (void)a; DDSetFullscreen(YES); }]
          forControlEvents:UIControlEventTouchUpInside];
        [bar addSubview:b]; DDTrace(@"FULLSCREEN_BUTTON_CREATED");
    }
    b.hidden=DDFullscreen;
}
%hook DBStatusBarWindow
- (void)didAddSubview:(UIView *)view { %orig; (void)view; DDInstallButton((UIWindow *)self); }
- (void)didMoveToScreen:(UIScreen *)screen { %orig; if (screen) DDInstallButton((UIWindow *)self); }
- (void)layoutSubviews { %orig; if (!DDFullscreen) DDInstallButton((UIWindow *)self); }
%end

%hook DBAnimationView
- (void)layoutSubviews { %orig; if (DDFullscreen) DDForceDashboardGeometry(); }
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
            DDTrace(@"CARPLAY_ATTACH");
            UIWindow *bar=DDStatusBarWindow();
            if (bar) DDInstallButton(bar); else DDTrace(@"FULLSCREEN_BUTTON_NO_STATUSBAR");
        });
    }
}