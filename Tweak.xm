#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static const CGFloat DDTargetW = 427.0;
static const CGFloat DDTargetH = 240.0;
static BOOL DDIsCarPlayScreen(UIScreen *screen) {
    if (!screen || screen == UIScreen.mainScreen) return NO;
    CGSize s = screen.bounds.size;
    return fabs(s.width-DDTargetW)<2.0 && fabs(s.height-DDTargetH)<2.0;
}

static UIWindow *DDStatusBarWindow(void) {
    Class cls = NSClassFromString(@"DBStatusBarWindow");
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (cls && [w isKindOfClass:cls]) return w;
    }
    return nil;
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
- (void)showBar { DDSetSidebarVisible(YES); self.hidden=YES; }
@end

static void DDInstallRevealHandle(void) {
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (!DDIsCarPlayScreen(w.screen)) continue;
        if ([w viewWithTag:0x444448]) continue;
        DDRevealHandle *h=[[DDRevealHandle alloc] initWithFrame:CGRectMake(2,96,8,48)];
        h.tag=0x444448;
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
    %orig(frame);
}
%end

%end

%ctor {
    NSString *p=NSProcessInfo.processInfo.processName;
    if ([p containsString:@"CarPlay"]) {
        %init(DauDatCarPlay);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC*2), dispatch_get_main_queue(), ^{
            DDInstallRevealHandle();
        });
    }
}
