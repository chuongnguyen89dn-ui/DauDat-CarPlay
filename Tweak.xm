#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "DauDatConfig.h"
#import "DauDatDoctor.h"

@interface DBStatusBarWindow : UIWindow @end
@interface DBDockWindow : UIWindow @end
@interface DBApplicationViewController : UIViewController @end

static BOOL DDFullscreen = NO;
static __weak DBApplicationViewController *DDHost = nil;
static UIEdgeInsets DDSavedInsets = {0,0,0,0};
static CGRect DDSavedRect = {{0,0},{0,0}};
static BOOL DDHaveSavedGeometry = NO;
static const NSInteger DDFullButtonTag = 771133;
static const NSInteger DDExitButtonTag = 771134;
static NSString * const DDChromeNotification = @"jp.airaw.carplay.chrome";

static id DDSceneForHost(id host) {
    SEL s = NSSelectorFromString(@"scene");
    if (!host || ![host respondsToSelector:s]) return nil;
    return ((id(*)(id,SEL))objc_msgSend)(host,s);
}

static void DDUpdateScene(id scene, void (^block)(id)) {
    SEL s = NSSelectorFromString(@"updateSettingsWithBlock:");
    if (!scene || ![scene respondsToSelector:s] || !block) return;
    ((void(*)(id,SEL,id))objc_msgSend)(scene,s,block);
}

static UIEdgeInsets DDGetInsets(id settings) {
    SEL s = NSSelectorFromString(@"safeAreaInsetsPortrait");
    if (!settings || ![settings respondsToSelector:s]) return UIEdgeInsetsZero;
    return ((UIEdgeInsets(*)(id,SEL))objc_msgSend)(settings,s);
}

static void DDSetInsets(id settings, UIEdgeInsets insets) {
    SEL s = NSSelectorFromString(@"setSafeAreaInsetsPortrait:");
    if (settings && [settings respondsToSelector:s])
        ((void(*)(id,SEL,UIEdgeInsets))objc_msgSend)(settings,s,insets);
}

static CGRect DDGetSettingsFrame(id settings) {
    SEL s = NSSelectorFromString(@"frame");
    if (!settings || ![settings respondsToSelector:s]) return CGRectZero;
    return ((CGRect(*)(id,SEL))objc_msgSend)(settings,s);
}

static void DDPostChromeHidden(BOOL hidden) {
    NSDictionary *info = @{@"nativeChromeHidden": @(hidden)};
    Class c = NSClassFromString(@"NSDistributedNotificationCenter");
    id center = c && [c respondsToSelector:@selector(defaultCenter)] ? [c defaultCenter] : nil;
    SEL post = NSSelectorFromString(@"postNotificationName:object:userInfo:");
    if (center && [center respondsToSelector:post])
        ((void(*)(id,SEL,id,id,id))objc_msgSend)(center,post,DDChromeNotification,nil,info);
}

static void DDApplyChromeWindow(UIWindow *window, BOOL hidden) {
    if (!window) return;
    window.hidden = hidden;
}

static NSString *DDSnapshot(void) {
    UIView *v = DDHost.view;
    id scene = DDSceneForHost(DDHost);
    return [NSString stringWithFormat:@"fullscreen=%d host=%@ viewFrame=%@ viewBounds=%@ scene=%@ saved=%d savedRect=%@ savedInsets=%@",
            DDFullscreen,
            DDHost ? NSStringFromClass(DDHost.class) : @"nil",
            v ? NSStringFromCGRect(v.frame) : @"nil",
            v ? NSStringFromCGRect(v.bounds) : @"nil",
            scene ? NSStringFromClass([scene class]) : @"nil",
            DDHaveSavedGeometry,
            NSStringFromCGRect(DDSavedRect),
            NSStringFromUIEdgeInsets(DDSavedInsets)];
}

static void DDTrace(NSString *event) {
    DDDoctorLogEvent(event,DDSnapshot());
    NSLog(@"[DauDat] %@ | %@",event,DDSnapshot());
}

static void DDInstallExitButton(void);

static void DDSetFullscreen(BOOL enabled) {
    DBApplicationViewController *host = DDHost;
    id scene = DDSceneForHost(host);
    if (!host || !scene) {
        DDTrace(@"FULLSCREEN_ABORT_NO_DBAPPLICATION_HOST");
        return;
    }
    if (enabled == DDFullscreen) return;

    if (enabled) {
        DDTrace(@"FULLSCREEN_ENTER_BEGIN");
        DDUpdateScene(scene, ^(id settings) {
            if (!DDHaveSavedGeometry) {
                DDSavedInsets = DDGetInsets(settings);
                DDSavedRect = DDGetSettingsFrame(settings);
                if (CGRectIsEmpty(DDSavedRect)) DDSavedRect = host.view.frame;
                DDHaveSavedGeometry = YES;
            }
            DDSetInsets(settings, UIEdgeInsetsZero);
        });
        DDFullscreen = YES;
        DDPostChromeHidden(YES);
        DDInstallExitButton();
        DDTrace(@"FULLSCREEN_ENTER_END");
    } else {
        DDTrace(@"FULLSCREEN_EXIT_BEGIN");
        DDFullscreen = NO;
        DDUpdateScene(scene, ^(id settings) {
            if (DDHaveSavedGeometry) DDSetInsets(settings,DDSavedInsets);
            UIView *v = host.view;
            v.hidden = NO;
            v.alpha = 1.0;
            v.transform = CGAffineTransformIdentity;
            if (DDHaveSavedGeometry && !CGRectIsEmpty(DDSavedRect)) v.frame = DDSavedRect;
            if (v.superview) [v.superview bringSubviewToFront:v];
        });
        DDPostChromeHidden(NO);
        UIButton *exit = (UIButton *)[host.view viewWithTag:DDExitButtonTag];
        [exit removeFromSuperview];
        DDTrace(@"FULLSCREEN_EXIT_END");
    }
}

static UIButton *DDMakeButton(NSInteger tag, NSString *symbol, void (^handler)(void)) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.tag = tag;
    b.frame = CGRectMake(0,0,38,38);
    b.backgroundColor = UIColor.clearColor;
    b.opaque = NO;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    [b setImage:[UIImage systemImageNamed:symbol withConfiguration:cfg] forState:UIControlStateNormal];
    b.tintColor = UIColor.whiteColor;
    [b addAction:[UIAction actionWithHandler:^(__kindof UIAction *a){ (void)a; if(handler) handler(); }]
      forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static void DDInstallEnterButton(UIWindow *bar) {
    if (!bar || DDFullscreen) return;
    UIButton *b = (UIButton *)[bar viewWithTag:DDFullButtonTag];
    if (!b) {
        b = DDMakeButton(DDFullButtonTag,@"arrow.up.left.and.arrow.down.right",^{ DDSetFullscreen(YES); });
        [bar addSubview:b];
    }
    CGFloat side=38.0;
    b.frame=CGRectMake(MAX(3.0,(bar.bounds.size.width-side)/2.0),MAX(4.0,bar.bounds.size.height-side-8.0),side,side);
    b.hidden=NO;
}

static void DDInstallExitButton(void) {
    if (!DDFullscreen || !DDHost.view) return;
    UIButton *b = (UIButton *)[DDHost.view viewWithTag:DDExitButtonTag];
    if (!b) {
        b = DDMakeButton(DDExitButtonTag,@"arrow.down.right.and.arrow.up.left",^{ DDSetFullscreen(NO); });
        b.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        [DDHost.view addSubview:b];
    }
    b.frame = CGRectMake(MAX(4.0,DDHost.view.bounds.size.width-44.0),6.0,38.0,38.0);
    [DDHost.view bringSubviewToFront:b];
}

static void DDRegisterChromeObserver(UIWindow *window) {
    if (!window || objc_getAssociatedObject(window,@selector(DDRegisterChromeObserver))) return;
    objc_setAssociatedObject(window,@selector(DDRegisterChromeObserver),@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    Class c=NSClassFromString(@"NSDistributedNotificationCenter");
    id center=c && [c respondsToSelector:@selector(defaultCenter)] ? [c defaultCenter] : nil;
    SEL add=NSSelectorFromString(@"addObserverForName:object:queue:usingBlock:");
    if (center && [center respondsToSelector:add]) {
        __weak UIWindow *weakWindow=window;
        id block=^(NSNotification *n){
            NSNumber *x=n.userInfo[@"nativeChromeHidden"];
            if(x) DDApplyChromeWindow(weakWindow,x.boolValue);
        };
        ((id(*)(id,SEL,id,id,id,id))objc_msgSend)(center,add,DDChromeNotification,nil,[NSOperationQueue mainQueue],block);
    }
}

%hook DBApplicationViewController
- (void)viewDidLoad {
    %orig;
    DDHost=(DBApplicationViewController *)self;
    DDTrace(@"DBAPPLICATION_HOST_CAPTURED");
}
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    DDHost=(DBApplicationViewController *)self;
    if(DDFullscreen) DDInstallExitButton();
}
- (void)viewDidLayoutSubviews {
    %orig;
    DDHost=(DBApplicationViewController *)self;
    if(DDFullscreen) DDInstallExitButton();
}
%end

%hook DBStatusBarWindow
- (void)layoutSubviews {
    %orig;
    DDRegisterChromeObserver((UIWindow *)self);
    if(!DDFullscreen) DDInstallEnterButton((UIWindow *)self);
}
- (void)didMoveToScreen:(UIScreen *)screen {
    %orig(screen);
    DDRegisterChromeObserver((UIWindow *)self);
    if(!DDFullscreen) DDInstallEnterButton((UIWindow *)self);
}
%end

%hook DBDockWindow
- (void)layoutSubviews {
    %orig;
    DDRegisterChromeObserver((UIWindow *)self);
}
%end

%ctor {
    %init;
}
