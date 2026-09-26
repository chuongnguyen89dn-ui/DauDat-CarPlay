#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "DauDatConfig.h"
#import "DauDatDoctor.h"

@interface DBStatusBarWindow : UIWindow @end
@interface DBAnimationView : UIView @end

static BOOL DDFullscreen=NO;
static const NSInteger DDFullButtonTag=771133;

static BOOL DDIsCarPlayScreen(UIScreen *screen) {
    if (!screen) return NO;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        if (ws.screen!=screen) continue;
        NSString *role=scene.session.role ?: @"";
        if ([role rangeOfString:@"CarPlay" options:NSCaseInsensitiveSearch].location!=NSNotFound) return YES;
    }
    return NO;
}
static void DDWalkViews(UIView *view, void (^block)(UIView *)) {
    if (!view) return; block(view);
    for (UIView *child in view.subviews) DDWalkViews(child,block);
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
            DDWalkViews(w.rootViewController.view,^(UIView *v){
                if (!found && [NSStringFromClass(v.class) containsString:@"DBAnimationView"]) found=v;
            });
        }
    }
    return found;
}
static void DDTrace(NSString *event) {
    UIWindow *bar=DDStatusBarWindow();
    UIView *content=DDDashboardContentView();
    UIWindow *host=content.window;
    UIView *root=host.rootViewController.view;
    UIButton *button=(UIButton *)[bar viewWithTag:DDFullButtonTag];
    NSString *detail=[NSString stringWithFormat:
      @"fullscreen=%d process=%@ bar=%@ barFrame=%@ barBounds=%@ barHidden=%d "
       "button=%@ buttonFrame=%@ buttonHidden=%d "
       "host=%@ hostFrame=%@ hostBounds=%@ root=%@ rootFrame=%@ rootBounds=%@ "
       "content=%@ contentFrame=%@ contentBounds=%@ super=%@ superFrame=%@ superBounds=%@",
      DDFullscreen,NSProcessInfo.processInfo.processName,
      bar?NSStringFromClass(bar.class):@"nil",bar?NSStringFromCGRect(bar.frame):@"nil",
      bar?NSStringFromCGRect(bar.bounds):@"nil",bar?bar.hidden:-1,
      button?@"YES":@"NO",button?NSStringFromCGRect(button.frame):@"nil",button?button.hidden:-1,
      host?NSStringFromClass(host.class):@"nil",host?NSStringFromCGRect(host.frame):@"nil",
      host?NSStringFromCGRect(host.bounds):@"nil",
      root?NSStringFromClass(root.class):@"nil",root?NSStringFromCGRect(root.frame):@"nil",
      root?NSStringFromCGRect(root.bounds):@"nil",
      content?NSStringFromClass(content.class):@"nil",content?NSStringFromCGRect(content.frame):@"nil",
      content?NSStringFromCGRect(content.bounds):@"nil",
      content.superview?NSStringFromClass(content.superview.class):@"nil",
      content.superview?NSStringFromCGRect(content.superview.frame):@"nil",
      content.superview?NSStringFromCGRect(content.superview.bounds):@"nil"];
    DDDoctorLogEvent(event,detail);
    DDDoctorWrite(NO,DDFullscreen,bar);
    NSLog(@"[DauDat] %@ | %@",event,detail);
}
static void DDInstallButton(UIWindow *bar);
static void DDSetFullscreen(BOOL enabled) {
    if (enabled==DDFullscreen) return;
    DDTrace(enabled?@"FULLSCREEN_ENTER_BEGIN":@"FULLSCREEN_EXIT_BEGIN");
    DDFullscreen=enabled;
    // Diagnostic build: do not mutate DuoDash/CarPlay geometry while Airaw host-scene port is being verified.
    if (enabled) {
        bar.hidden=YES;
    } else {
        UIWindow *bar=DDStatusBarWindow();
        bar.hidden=NO;
        DDInstallButton(bar);
    }
    DDTrace(enabled?@"FULLSCREEN_ENTER_END":@"FULLSCREEN_EXIT_END");
}
static void DDInstallButton(UIWindow *bar) {
    if (!bar || ![NSStringFromClass(bar.class) containsString:@"DBStatusBarWindow"]) return;
    UIButton *b=(UIButton *)[bar viewWithTag:DDFullButtonTag];
    if (!b) {
        b=[UIButton buttonWithType:UIButtonTypeCustom];
        b.tag=DDFullButtonTag;
        CGFloat side=38.0;
        CGFloat y=MAX(4.0,bar.bounds.size.height-side-8.0);
        b.frame=CGRectMake(MAX(3.0,(bar.bounds.size.width-side)/2.0),y,side,side);
        b.backgroundColor=UIColor.clearColor;
        b.opaque=NO;
        UIImageSymbolConfiguration *cfg=[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
        [b setImage:[UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right" withConfiguration:cfg] forState:UIControlStateNormal];
        b.tintColor=UIColor.whiteColor;
        b.accessibilityLabel=@"Fullscreen";
        [b addAction:[UIAction actionWithHandler:^(__kindof UIAction *a){ (void)a; DDSetFullscreen(YES); }]
          forControlEvents:UIControlEventTouchUpInside];
        [bar addSubview:b];
        DDTrace(@"FULLSCREEN_BUTTON_CREATED");
    }
    b.hidden=DDFullscreen;
}
%hook DBStatusBarWindow
- (void)didAddSubview:(UIView *)view { %orig; (void)view; DDInstallButton((UIWindow *)self); }
- (void)didMoveToScreen:(UIScreen *)screen { %orig; if (screen) DDInstallButton((UIWindow *)self); }
- (void)layoutSubviews { %orig; if (!DDFullscreen) DDInstallButton((UIWindow *)self); }
%end

%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (DDFullscreen && DDIsCarPlayScreen(self.screen) && event.type==UIEventTypeTouches) {
        for (UITouch *t in event.allTouches) {
            if (t.phase!=UITouchPhaseEnded) continue;
            CGPoint p=[t locationInView:self];
            if (p.x<=44.0 && p.y<=44.0) {
                DDTrace(@"FULLSCREEN_RESTORE_HITZONE");
                DDSetFullscreen(NO);
                return;
            }
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
            if (bar) DDInstallButton(bar);
            DDTrace(bar?@"DIAGNOSTIC_READY":@"DIAGNOSTIC_NO_STATUSBAR");
        });
    }
}
