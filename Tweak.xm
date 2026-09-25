#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "DauDatConfig.h"
#import "DauDatDoctor.h"

static const CGFloat DDTargetW = 427.0;
static const CGFloat DDTargetH = 240.0;
@class DDRevealHandle;
static BOOL gDDFullscreen = NO;
static DDRevealHandle *gDDHandle = nil;
static NSMapTable<UIView *, NSValue *> *gDDOriginalFrames = nil;

static BOOL DDIsCarPlayScreen(UIScreen *screen) {
    if (!screen || screen == UIScreen.mainScreen) return NO;
    CGSize s = screen.bounds.size;
    return fabs(s.width-DDTargetW)<2.0 && fabs(s.height-DDTargetH)<2.0;
}

static NSArray<UIWindow *> *DDAllWindows(void) {
    NSMutableArray<UIWindow *> *out=[NSMutableArray array];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        [out addObjectsFromArray:ws.windows];
    }
    return out;
}

static UIWindow *DDStatusBarWindow(void) {
    Class cls = NSClassFromString(@"DBStatusBarWindow");
    for (UIWindow *w in DDAllWindows()) {
        if (cls && [w isKindOfClass:cls]) return w;
    }
    return nil;
}

static BOOL DDLooksSidebarReserved(CGRect f) {
    return ((f.origin.x >= 40.0 && f.origin.x <= 50.0) ||
            (f.size.width >= 370.0 && f.size.width <= 390.0));
}

static void DDApplyContentFullscreen(BOOL enabled) {
    if (!gDDOriginalFrames) gDDOriginalFrames=[NSMapTable weakToStrongObjectsMapTable];
    for (UIWindow *w in DDAllWindows()) {
        if (!DDIsCarPlayScreen(w.screen) || w.hidden || !w.rootViewController) continue;
        if ([w isKindOfClass:NSClassFromString(@"DBStatusBarWindow")]) continue;
        UIView *root=w.rootViewController.view;
        NSMutableArray<UIView *> *targets=[NSMutableArray arrayWithObject:root];
        [targets addObjectsFromArray:root.subviews];
        for (UIView *v in targets) {
            if (enabled) {
                CGRect f=v.frame;
                if (!DDLooksSidebarReserved(f)) continue;
                if (![gDDOriginalFrames objectForKey:v]) [gDDOriginalFrames setObject:[NSValue valueWithCGRect:f] forKey:v];
                CGRect full=f;
                full.origin.x=0.0;
                full.size.width=DDTargetW;
                v.frame=full;
                [v setNeedsLayout];
            } else {
                NSValue *saved=[gDDOriginalFrames objectForKey:v];
                if (saved) {
                    v.frame=saved.CGRectValue;
                    [v setNeedsLayout];
                    [gDDOriginalFrames removeObjectForKey:v];
                }
            }
        }
    }
}

static void DDSetSidebarVisible(BOOL visible) {
    UIWindow *bar = DDStatusBarWindow();
    if (!bar) return;
    CGRect f=bar.frame;
    if (f.size.width < 1.0) f.size.width=45.0;
    f.origin.x = visible ? 0.0 : -fabs(f.size.width);
    bar.frame=f;
}

@interface DDRevealHandle : UIControl
@end
@implementation DDRevealHandle
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.backgroundColor=[UIColor colorWithWhite:1 alpha:.16];
        self.layer.cornerRadius=3.0;
        [self addTarget:self action:@selector(showBar) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}
- (void)showBar { gDDFullscreen=NO; DDApplyContentFullscreen(NO); DDSetSidebarVisible(YES); self.hidden=YES; }
@end

static void DDInstallRevealHandle(void) {
    for (UIWindow *w in DDAllWindows()) {
        if (!DDIsCarPlayScreen(w.screen)) continue;
        if ([w viewWithTag:0x444448]) continue;
        DDRevealHandle *h=[[DDRevealHandle alloc] initWithFrame:CGRectMake(2,96,8,48)];
        h.tag=0x444448; h.hidden=YES; gDDHandle=h;
        [w addSubview:h];
        [w bringSubviewToFront:h];
    }
}

%group DauDatCarPlay

%hook UIWindow
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets v=%orig;
    if (DDIsCarPlayScreen(self.screen)) return UIEdgeInsetsZero;
    return v;
}
%end

%hook UIView
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets v=%orig;
    if (DDIsCarPlayScreen(self.window.screen)) return UIEdgeInsetsZero;
    return v;
}
%end

%hook DBStatusBarWindow
- (void)setFrame:(CGRect)frame {
    if (gDDFullscreen && frame.size.width > 0.0) frame.origin.x=-fabs(frame.size.width);
    %orig(frame);
}
%end

// Long-press the native CarPlay status/sidebar to enter full screen.
// The native six-dot Home control is not intercepted; a separate edge handle exits full screen.
%hook DBStatusBarView
- (void)didMoveToWindow {
    UIView *view=(UIView *)self;
    %orig;
    if (!view.window || [view viewWithTag:0x44444C]) return;
    UILongPressGestureRecognizer *lp=[[UILongPressGestureRecognizer alloc] initWithTarget:view action:@selector(dd_toggleFull:)];
    lp.minimumPressDuration=0.65;
    lp.cancelsTouchesInView=NO;
    [view addGestureRecognizer:lp];
    UIView *marker=[[UIView alloc] initWithFrame:CGRectZero]; marker.tag=0x44444C; marker.hidden=YES; [view addSubview:marker];
}
%new
- (void)dd_toggleFull:(UILongPressGestureRecognizer *)g {
    if (g.state!=UIGestureRecognizerStateBegan) return;
    gDDFullscreen=YES;
    DDSetSidebarVisible(NO);
    DDApplyContentFullscreen(YES);
    if (gDDHandle) gDDHandle.hidden=NO;
}
%end

%end

%ctor {
    NSDictionary *cfg=DDLoadConfiguration();
    (void)cfg;
    NSString *p=NSProcessInfo.processInfo.processName;
    if ([p containsString:@"CarPlay"]) {
        %init(DauDatCarPlay);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC*2), dispatch_get_main_queue(), ^{
            DDInstallRevealHandle();
        DDDoctorWrite(NO, gDDFullscreen, DDStatusBarWindow());
        });
    }
}
