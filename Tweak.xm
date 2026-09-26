#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <notify.h>\n#import "DauDatConfig.h"\n#import "DauDatDoctor.h"
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
    UIWindow *bar=DDStatusBarWindow();
    UIView *content=DDDashboardContentView();
    UIWindow *host=content.window;
    UIView *root=host.rootViewController.view;
    UIButton *button=(UIButton *)[bar viewWithTag:DDFullButtonTag];
    NSString *detail=[NSString stringWithFormat:
        @"fullscreen=%d process=%@ bar.frame=%@ bar.bounds=%@ bar.hidden=%d "
         "button=%@ button.frame=%@ button.hidden=%d "
         "host=%@ host.frame=%@ host.bounds=%@ root.frame=%@ root.bounds=%@ "
         "content=%@ content.frame=%@ content.bounds=%@ super.frame=%@ super.bounds=%@",
        DDFullscreen,NSProcessInfo.processInfo.processName,
        bar?NSStringFromCGRect(bar.frame):@"nil",bar?NSStringFromCGRect(bar.bounds):@"nil",bar?bar.hidden:-1,
        button?@"YES":@"NO",button?NSStringFromCGRect(button.frame):@"nil",button?button.hidden:-1,
        host?NSStringFromClass(host.class):@"nil",host?NSStringFromCGRect(host.frame):@"nil",host?NSStringFromCGRect(host.bounds):@"nil",
        root?NSStringFromCGRect(root.frame):@"nil",root?NSStringFromCGRect(root.bounds):@"nil",
        content?NSStringFromClass(content.class):@"nil",content?NSStringFromCGRect(content.frame):@"nil",content?NSStringFromCGRect(content.bounds):@"nil",
        content.superview?NSStringFromCGRect(content.superview.frame):@"nil",
        content.superview?NSStringFromCGRect(content.superview.bounds):@"nil"];
    DDDoctorLogEvent(event,detail);
    DDDoctorWrite(NO,DDFullscreen,bar);
    NSLog(@"[DauDat] %@ | %@",event,detail);
}}