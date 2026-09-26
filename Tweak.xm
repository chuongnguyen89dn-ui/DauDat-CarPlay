#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <notify.h>
#import "DauDatConfig.h"
#import "DauDatDoctor.h"

@interface DBStatusBarWindow : UIWindow @end
@interface DBAnimationView : UIView @end

static BOOL DDFullscreen=NO;
static CGRect DDNormalDashboardFrame={{0,0},{0,0}};
static BOOL DDHaveDashboardFrame=NO;
static const NSInteger DDFullButtonTag=771133;

static BOOL DDIsCarPlayScreen(UIScreen *screen) {
    if (!screen) return NO;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        if (ws.screen!=screen) continue;
        NSString *role=scene.session.role?:@"";
        if ([role rangeOfString:@"CarPlay" options:NSCaseInsensitiveSearch].location!=NSNotFound) return YES;
    }
    return NO;
}
static void DDWalkViews(UIView *v,void(^b)(UIView *)){ if(!v)return; b(v); for(UIView *c in v.subviews)DDWalkViews(c,b); }
static void DDWalkVC(UIViewController *v,void(^b)(UIViewController *)){ if(!v)return; b(v); for(UIViewController*c in v.childViewControllers)DDWalkVC(c,b); if(v.presentedViewController)DDWalkVC(v.presentedViewController,b); }
static UIWindow *DDStatusBarWindow(void){
    for(UIScene*s in UIApplication.sharedApplication.connectedScenes){ if(![s isKindOfClass:UIWindowScene.class])continue; UIWindowScene*ws=(UIWindowScene*)s; if(!DDIsCarPlayScreen(ws.screen))continue; for(UIWindow*w in ws.windows)if([NSStringFromClass(w.class) containsString:@"DBStatusBarWindow"])return w; } return nil;
}
static UIView *DDDashboardContentView(void){
    __block UIView*f=nil;
    for(UIScene*s in UIApplication.sharedApplication.connectedScenes){ if(![s isKindOfClass:UIWindowScene.class])continue; UIWindowScene*ws=(UIWindowScene*)s; if(!DDIsCarPlayScreen(ws.screen))continue; for(UIWindow*w in ws.windows){ if([NSStringFromClass(w.class) containsString:@"DBStatusBarWindow"])continue; DDWalkViews(w.rootViewController.view,^(UIView*v){ if(!f&&[NSStringFromClass(v.class) containsString:@"DBAnimationView"])f=v; }); }} return f;
}
static void DDInvokeBool(id o,NSString*n,BOOL x){ SEL s=NSSelectorFromString(n); if(!o||![o respondsToSelector:s])return; NSMethodSignature*g=[o methodSignatureForSelector:s]; if(!g||g.numberOfArguments!=3)return; NSInvocation*i=[NSInvocation invocationWithMethodSignature:g]; i.target=o;i.selector=s;[i setArgument:&x atIndex:2];[i invoke]; }
static void DDSetNativeChromeHidden(BOOL h){
    for(UIScene*s in UIApplication.sharedApplication.connectedScenes){ if(![s isKindOfClass:UIWindowScene.class])continue; UIWindowScene*ws=(UIWindowScene*)s;if(!DDIsCarPlayScreen(ws.screen))continue;for(UIWindow*w in ws.windows)DDWalkVC(w.rootViewController,^(UIViewController*v){NSString*c=NSStringFromClass(v.class);if([c containsString:@"DBApplicationViewController"]||[c containsString:@"DBDashboard"]){DDInvokeBool(v,@"setDefaultAppChromeHidden:",h);DDInvokeBool(v,@"setNativeChromeHidden:",h);}});}
}
static NSString *DDSnapshot(void){
    UIWindow*bar=DDStatusBarWindow(); UIView*c=DDDashboardContentView(); UIWindow*h=c.window; UIView*r=h.rootViewController.view; UIButton*b=(UIButton*)[bar viewWithTag:DDFullButtonTag];
    return [NSString stringWithFormat:@"fullscreen=%d bar=%@/%@ hidden=%d button=%@/%@ host=%@/%@ root=%@/%@ content=%@/%@ super=%@/%@",DDFullscreen,bar?NSStringFromCGRect(bar.frame):@"nil",bar?NSStringFromCGRect(bar.bounds):@"nil",bar?bar.hidden:-1,b?@"YES":@"NO",b?NSStringFromCGRect(b.frame):@"nil",h?NSStringFromCGRect(h.frame):@"nil",h?NSStringFromCGRect(h.bounds):@"nil",r?NSStringFromCGRect(r.frame):@"nil",r?NSStringFromCGRect(r.bounds):@"nil",c?NSStringFromCGRect(c.frame):@"nil",c?NSStringFromCGRect(c.bounds):@"nil",c.superview?NSStringFromCGRect(c.superview.frame):@"nil",c.superview?NSStringFromCGRect(c.superview.bounds):@"nil"];
}
static void DDTrace(NSString*event){
    NSString*line=[NSString stringWithFormat:@"%@ | %@ | %@\n",NSDate.date,event,DDSnapshot()];
    CFPropertyListRef old=CFPreferencesCopyAppValue(CFSTR("payload.DDTRACE"),CFSTR("com.chuong.daudat.diagnostic"));
    NSString*prev=(old&&CFGetTypeID(old)==CFStringGetTypeID())?[(__bridge NSString*)old copy]:@"";
    if(old)CFRelease(old);
    NSString*all=[prev stringByAppendingString:line];
    if(all.length>60000)all=[all substringFromIndex:all.length-60000];
    CFPreferencesSetAppValue(CFSTR("payload.DDTRACE"),(__bridge CFStringRef)all,CFSTR("com.chuong.daudat.diagnostic"));
    CFPreferencesAppSynchronize(CFSTR("com.chuong.daudat.diagnostic"));
    DDDoctorLogEvent(event,DDSnapshot());
    NSLog(@"[DauDat] %@",line);
}
static void DDForceDashboardGeometry(void){ UIView*c=DDDashboardContentView();if(!c||!c.superview)return;if(DDFullscreen){CGRect f=c.superview.bounds;if(!CGRectIsEmpty(f))c.frame=f;}else if(DDHaveDashboardFrame)c.frame=DDNormalDashboardFrame;[c setNeedsLayout]; }
static void DDInstallButton(UIWindow*bar);
static void DDSetFullscreen(BOOL e){
    if(e==DDFullscreen)return;UIWindow*bar=DDStatusBarWindow();UIView*c=DDDashboardContentView();if(!bar||!c||!c.superview){DDTrace(@"FULLSCREEN_ABORT_MISSING_HOST");return;}
    DDTrace(e?@"FULLSCREEN_ENTER_BEGIN":@"FULLSCREEN_EXIT_BEGIN");
    if(e){DDNormalDashboardFrame=c.frame;DDHaveDashboardFrame=YES;DDFullscreen=YES;DDSetNativeChromeHidden(YES);bar.hidden=YES;DDForceDashboardGeometry();}
    else{DDFullscreen=NO;bar.hidden=NO;DDSetNativeChromeHidden(NO);DDForceDashboardGeometry();DDInstallButton(bar);}
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(120*NSEC_PER_MSEC)),dispatch_get_main_queue(),^{DDForceDashboardGeometry();DDTrace(e?@"FULLSCREEN_ENTER_SETTLED":@"FULLSCREEN_EXIT_SETTLED");});
    DDTrace(e?@"FULLSCREEN_ENTER_END":@"FULLSCREEN_EXIT_END");
}
static void DDInstallButton(UIWindow*bar){
    if(!bar||![NSStringFromClass(bar.class) containsString:@"DBStatusBarWindow"])return;UIButton*b=(UIButton*)[bar viewWithTag:DDFullButtonTag];
    if(!b){b=[UIButton buttonWithType:UIButtonTypeCustom];b.tag=DDFullButtonTag;CGFloat side=38.0,y=MAX(4.0,bar.bounds.size.height-side-8.0);b.frame=CGRectMake(MAX(3.0,(bar.bounds.size.width-side)/2.0),y,side,side);b.backgroundColor=UIColor.clearColor;b.opaque=NO;b.autoresizingMask=UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;UIImageSymbolConfiguration*cfg=[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];[b setImage:[UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right" withConfiguration:cfg] forState:UIControlStateNormal];b.tintColor=UIColor.whiteColor;[b addAction:[UIAction actionWithHandler:^(__kindof UIAction*a){(void)a;DDSetFullscreen(YES);}] forControlEvents:UIControlEventTouchUpInside];[bar addSubview:b];DDTrace(@"FULLSCREEN_BUTTON_CREATED");}b.hidden=DDFullscreen;
}
%hook DBStatusBarWindow
-(void)didAddSubview:(UIView*)v {\n    %orig(v);\n    DDInstallButton((UIWindow*)self);\n}
-(void)didMoveToScreen:(UIScreen*)s {\n    %orig(s);\n    if(s) DDInstallButton((UIWindow*)self);\n}
-(void)layoutSubviews {\n    %orig;\n    if(!DDFullscreen) DDInstallButton((UIWindow*)self);\n}
%end
%hook DBAnimationView
-(void)layoutSubviews {\n    %orig;\n    if(DDFullscreen) DDForceDashboardGeometry();\n}
%end
%hook UIWindow
-(void)sendEvent:(UIEvent*)e{if(DDFullscreen&&DDIsCarPlayScreen(self.screen)&&e.type==UIEventTypeTouches){for(UITouch*t in e.allTouches){if(t.phase!=UITouchPhaseEnded)continue;CGPoint p=[t locationInView:self];if(p.x<=44&&p.y<=44){DDTrace(@"FULLSCREEN_RESTORE_HITZONE");DDSetFullscreen(NO);return;}}}%orig;}
%end
%ctor{ %init; NSString*p=NSProcessInfo.processInfo.processName?:@"";if([p isEqualToString:@"CarPlay"]||[p isEqualToString:@"CarPlayApp"])dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1*NSEC_PER_SEC)),dispatch_get_main_queue(),^{UIWindow*b=DDStatusBarWindow();if(b)DDInstallButton(b);else DDTrace(@"FULLSCREEN_BUTTON_NO_STATUSBAR");}); }
