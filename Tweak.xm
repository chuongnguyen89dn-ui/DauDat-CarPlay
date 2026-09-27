#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "DauDatConfig.h"
#import "DauDatDoctor.h"

@interface DBStatusBarWindow : UIWindow @end
@interface DBDockWindow : UIWindow @end

static NSString *DDAirawChromeNotification = @"jp.airaw.carplay.chrome";

static BOOL DDFullscreen = NO;
static const NSInteger DDEnterTag = 771133;
static const NSInteger DDExitTag  = 771134;
static BOOL DDNear(CGFloat a, CGFloat b) { return fabs(a-b) < 3.0; }
static BOOL DDIs427CarPlayScreen(UIScreen *screen) {
    if (!screen || screen == UIScreen.mainScreen) return NO;
    CGRect b=screen.bounds;
    return (DDNear(b.size.width,427.0)&&DDNear(b.size.height,240.0)) || (DDNear(b.size.width,240.0)&&DDNear(b.size.height,427.0));
}

static void DDWalk(UIView *v, void (^block)(UIView *)) {
    if(!v)return;
    block(v);
    for(UIView *c in v.subviews) DDWalk(c,block);
}

static NSArray<UIWindow *> *DDCarPlayWindows(void) {
    NSMutableArray *a=[NSMutableArray array];
    for(UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if(![s isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)s;
        if(!DDIs427CarPlayScreen(ws.screen)) continue;
        [a addObjectsFromArray:ws.windows];
    }
    return a;
}

static UIWindow *DDStatusWindow(void) {
    for(UIWindow *w in DDCarPlayWindows())
        if([NSStringFromClass(w.class) containsString:@"DBStatusBarWindow"]) return w;
    return nil;
}

static NSString *DDGeometrySnapshot(void) {
    NSMutableArray *rows=[NSMutableArray array];
    NSInteger wi=0;
    for(UIWindow *w in DDCarPlayWindows()) {
        NSMutableArray *interesting=[NSMutableArray array];
        DDWalk(w,^(UIView *v){
            CGRect f=v.frame, b=v.bounds;
            NSString *cn=NSStringFromClass(v.class);
            BOOL divider=[cn containsString:@"Divider"]||[cn containsString:@"Handle"];
            BOOL hostLike=(f.size.width>100.0 || b.size.width>100.0);
            if(divider || hostLike) {
                [interesting addObject:[NSString stringWithFormat:@"%@ f=%@ b=%@ super=%@",
                    cn,NSStringFromCGRect(f),NSStringFromCGRect(b),
                    v.superview?NSStringFromClass(v.superview.class):@"nil"]];
            }
        });
        [rows addObject:[NSString stringWithFormat:@"WIN[%ld] %@ f=%@ b=%@ hidden=%d\n%@",
            (long)wi++,NSStringFromClass(w.class),NSStringFromCGRect(w.frame),NSStringFromCGRect(w.bounds),
            w.hidden,[interesting componentsJoinedByString:@"\n"]]];
    }
    return [rows componentsJoinedByString:@"\n"];
}
static void DDTrace(NSString *event) {
    UIWindow *bar=DDStatusWindow();
    NSString *detail=[NSString stringWithFormat:@"fullscreen=%d barFrame=%@ barHidden=%d\n%@",
                      DDFullscreen,bar?NSStringFromCGRect(bar.frame):@"nil",bar?bar.hidden:-1,
                      DDGeometrySnapshot()];
    DDDoctorLogEvent(event,detail);
    NSLog(@"[DauDat] %@ | %@",event,detail);
}

static UIButton *DDButton(NSInteger tag, NSString *symbol, void (^action)(void)) {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];
    b.tag=tag;
    b.backgroundColor=UIColor.clearColor;
    UIImageSymbolConfiguration *cfg=[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    [b setImage:[UIImage systemImageNamed:symbol withConfiguration:cfg] forState:UIControlStateNormal];
    b.tintColor=UIColor.whiteColor;
    [b addAction:[UIAction actionWithHandler:^(__kindof UIAction *x){(void)x;if(action)action();}]
      forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static void DDSetFullscreen(BOOL enabled);

static void DDInstallEnterButton(UIWindow *bar) {
    if(!bar || DDFullscreen) return;
    UIButton *b=(UIButton *)[bar viewWithTag:DDEnterTag];
    if(!b) {
        b=DDButton(DDEnterTag,@"arrow.up.left.and.arrow.down.right",^{ DDSetFullscreen(YES); });
        [bar addSubview:b];
    }
    CGFloat side=30.0;
    b.frame=CGRectMake(MAX(3.0,(bar.bounds.size.width-side)/2.0),
                       MAX(4.0,bar.bounds.size.height-64.0),side,side);
    b.hidden=NO;
    [bar bringSubviewToFront:b];
}

static void DDInstallExitButton(void) {
    UIWindow *target=nil;
    for(UIWindow *w in DDCarPlayWindows()) {
        if([NSStringFromClass(w.class) containsString:@"DBStatusBarWindow"]) continue;
        if(!w.hidden && w.alpha>0.01) { target=w; break; }
    }
    if(!target) return;
    UIButton *b=(UIButton *)[target viewWithTag:DDExitTag];
    if(!b) {
        b=DDButton(DDExitTag,@"arrow.down.right.and.arrow.up.left",^{ DDSetFullscreen(NO); });
        b.autoresizingMask=UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
        [target addSubview:b];
    }
    b.frame=CGRectMake(5.0,5.0,30.0,30.0);
    [target bringSubviewToFront:b];
}

static void DDPostChromeHidden(BOOL hidden) {
    NSDictionary *info=@{ @"nativeChromeHidden":@(hidden), @"fullscreenButtonHidden":@(hidden) };
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:DDAirawChromeNotification object:nil userInfo:info deliverImmediately:YES];
}

static void DDApplySceneFullscreen(BOOL enabled) {
    for(UIWindow *w in DDCarPlayWindows()) {
        UIWindowScene *scene=w.windowScene;
        if(!scene) continue;
        SEL sel=NSSelectorFromString(@"updateSettingsWithBlock:");
        if(![scene respondsToSelector:sel]) continue;
        void (^block)(id)=^(id settings){
            SEL setInsets=NSSelectorFromString(@"setSafeAreaInsetsPortrait:");
            if(![settings respondsToSelector:setInsets]) return;
            UIEdgeInsets insets=enabled?UIEdgeInsetsZero:UIEdgeInsetsMake(0,45,0,0);
            NSMethodSignature *ms=[settings methodSignatureForSelector:setInsets];
            NSInvocation *iv=[NSInvocation invocationWithMethodSignature:ms];
            iv.target=settings; iv.selector=setInsets; [iv setArgument:&insets atIndex:2]; [iv invoke];
        };
        NSMethodSignature *ms=[scene methodSignatureForSelector:sel];
        NSInvocation *iv=[NSInvocation invocationWithMethodSignature:ms];
        iv.target=scene; iv.selector=sel; [iv setArgument:&block atIndex:2]; [iv invoke];
    }
}

static void DDApplyFullscreenNow(void) {
    DDPostChromeHidden(YES);
    DDApplySceneFullscreen(YES);
    if(DDFullscreen) DDInstallExitButton();
}

static void DDRestoreAll(void) {
    DDApplySceneFullscreen(NO);
    DDPostChromeHidden(NO);
    for(UIWindow *w in DDCarPlayWindows()) {
        UIButton *e=(UIButton *)[w viewWithTag:DDExitTag];
        [e removeFromSuperview];
        [w setNeedsLayout];
        [w layoutIfNeeded];
    }
    UIWindow *bar=DDStatusWindow();
    if(bar) DDInstallEnterButton(bar);
}

static void DDSetFullscreen(BOOL enabled) {
    if(enabled==DDFullscreen) return;
    DDTrace(enabled?@"FULLSCREEN_ENTER_BEGIN":@"FULLSCREEN_EXIT_BEGIN");
    DDFullscreen=enabled;
    if(enabled) {
        DDApplyFullscreenNow();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(80*NSEC_PER_MSEC)),dispatch_get_main_queue(),^{ DDApplyFullscreenNow(); DDTrace(@"FULLSCREEN_ENTER_SETTLED"); });
    } else {
        DDRestoreAll();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(80*NSEC_PER_MSEC)),dispatch_get_main_queue(),^{ DDRestoreAll(); DDTrace(@"FULLSCREEN_EXIT_SETTLED"); });
    }
}

%hook DBStatusBarWindow
- (void)setFrame:(CGRect)frame {
    if(DDFullscreen && DDIs427CarPlayScreen(self.screen))
        frame.origin.x=(frame.size.width>1.0)?-frame.size.width:-45.0;
    %orig(frame);
}
- (void)layoutSubviews {
    %orig;
    if(!DDFullscreen) DDInstallEnterButton((UIWindow *)self);
}
- (void)didMoveToScreen:(UIScreen *)screen {
    %orig(screen);
    if(!DDFullscreen && DDIs427CarPlayScreen(screen)) DDInstallEnterButton((UIWindow *)self);
}
%end

%ctor {
    %init;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        UIWindow *bar=DDStatusWindow();
        if(bar) DDInstallEnterButton(bar);
        else DDTrace(@"FULLSCREEN_BUTTON_NO_STATUSBAR");
    });
}
