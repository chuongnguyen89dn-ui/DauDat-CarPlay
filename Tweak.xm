#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static UIWindow *DDBarWindow(void) {
    Class cls = NSClassFromString(@"DBStatusBarWindow");
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (cls && [w isKindOfClass:cls]) return w;
        }
    }
    return nil;
}

static void DDShowBar(BOOL show) {
    UIWindow *bar=DDBarWindow();
    if (!bar) return;
    CGRect f=bar.frame;
    CGFloat width=f.size.width > 1.0 ? f.size.width : 45.0;
    f.origin.x=show ? 0.0 : -width;
    bar.frame=f;
}

@interface DDBarRevealHandle : UIControl @end
@implementation DDBarRevealHandle
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.backgroundColor=[UIColor colorWithWhite:1.0 alpha:0.18];
        self.layer.cornerRadius=3.0;
        [self addTarget:self action:@selector(dd_show) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}
- (void)dd_show { DDShowBar(YES); self.hidden=YES; }
@end

static DDBarRevealHandle *gHandle;

static void DDInstallHandle(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (w.screen == UIScreen.mainScreen || w.hidden) continue;
            if ([w isKindOfClass:NSClassFromString(@"DBStatusBarWindow")]) continue;
            if ([w viewWithTag:0x444448]) continue;
            DDBarRevealHandle *h=[[DDBarRevealHandle alloc] initWithFrame:CGRectMake(2,96,8,48)];
            h.tag=0x444448; h.hidden=YES;
            [w addSubview:h]; [w bringSubviewToFront:h];
            gHandle=h;
            return;
        }
    }
}

%hook DBStatusBarView
- (void)didMoveToWindow {
    %orig;
    UIView *v=(UIView *)self;
    if (!v.window || [v viewWithTag:0x44444C]) return;
    UILongPressGestureRecognizer *lp=[[UILongPressGestureRecognizer alloc] initWithTarget:v action:@selector(dd_hideSidebar:)];
    lp.minimumPressDuration=0.65;
    lp.cancelsTouchesInView=NO;
    [v addGestureRecognizer:lp];
    UIView *marker=[[UIView alloc] initWithFrame:CGRectZero];
    marker.tag=0x44444C; marker.hidden=YES; [v addSubview:marker];
}
%new
- (void)dd_hideSidebar:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    DDShowBar(NO);
    DDInstallHandle();
    gHandle.hidden=NO;
}
%end

%hook DBStatusBarWindow
- (void)setFrame:(CGRect)frame {
    %orig(frame);
}
%end

%ctor {
    NSString *p=NSProcessInfo.processInfo.processName;
    if ([p containsString:@"CarPlay"]) {
        %init;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ DDInstallHandle(); });
    }
}
