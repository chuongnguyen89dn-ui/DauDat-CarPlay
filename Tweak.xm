#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static BOOL DDGeometryFullscreen = NO;
static const void *DDSavedFrameKey = &DDSavedFrameKey;

static BOOL DDNear(CGFloat a, CGFloat b) { return fabs(a-b) < 3.0; }
static BOOL DDIs427CarPlayScreen(UIScreen *screen) {
    if (!screen || screen == UIScreen.mainScreen) return NO;
    CGRect b=screen.bounds;
    return (DDNear(b.size.width,427.0)&&DDNear(b.size.height,240.0)) ||
           (DDNear(b.size.width,240.0)&&DDNear(b.size.height,427.0));
}
static BOOL DDViewIsCarPlay(UIView *v) { return v.window && DDIs427CarPlayScreen(v.window.screen); }
static void DDSaveFrameIfNeeded(UIView *v) {
    if(!v || objc_getAssociatedObject(v,DDSavedFrameKey)) return;
    objc_setAssociatedObject(v,DDSavedFrameKey,[NSValue valueWithCGRect:v.frame],OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void DDRestoreFrameIfSaved(UIView *v) {
    NSValue *n=v?objc_getAssociatedObject(v,DDSavedFrameKey):nil;
    if(!n)return; v.frame=n.CGRectValue;
    objc_setAssociatedObject(v,DDSavedFrameKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static BOOL DDShouldExpandHostView(UIView *v) {
    if(!v || !DDViewIsCarPlay(v)) return NO;
    if([NSStringFromClass(v.class) isEqualToString:@"DBStatusBarView"]) return NO;
    CGRect f=v.frame;
    return DDNear(f.origin.x,45.0) || (f.size.width>370.0 && f.size.width<390.0);
}
static void DDExpandHostView(UIView *v) {
    if(!DDGeometryFullscreen || !DDShouldExpandHostView(v)) return;
    DDSaveFrameIfNeeded(v);
    CGRect f=v.frame; f.origin.x=0.0; f.size.width=427.0; f.size.height=240.0;
    v.frame=f;
    v.autoresizingMask |= UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
}
static void DDWalk(UIView *v, void (^block)(UIView *)) {
    if(!v)return; block(v); for(UIView *c in v.subviews) DDWalk(c,block);
}
static NSArray<UIWindow *> *DDCarPlayWindows(void) {
    NSMutableArray *a=[NSMutableArray array];
    for(UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if(![s isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)s;
        if(DDIs427CarPlayScreen(ws.screen)) [a addObjectsFromArray:ws.windows];
    }
    return a;
}
static void DDApplyGeometry(void) {
    for(UIWindow *w in DDCarPlayWindows()) {
        if([NSStringFromClass(w.class) containsString:@"DBStatusBarWindow"]) continue;
        DDWalk(w,^(UIView *v){ DDExpandHostView(v); });
        [w setNeedsLayout]; [w layoutIfNeeded];
    }
}
static void DDRestoreGeometry(void) {
    for(UIWindow *w in DDCarPlayWindows()) {
        DDWalk(w,^(UIView *v){ DDRestoreFrameIfSaved(v); });
        [w setNeedsLayout]; [w layoutIfNeeded];
    }
}
static void DDAirawFullscreenNotification(NSNotification *note) {
    (void)note;
    // Airaw's notification is a toggle request. Mirror only the proven 427x240
    // geometry correction from the working Fullscreen427 implementation.
    DDGeometryFullscreen=!DDGeometryFullscreen;
    if(DDGeometryFullscreen) {
        DDApplyGeometry();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,80*NSEC_PER_MSEC),dispatch_get_main_queue(),^{ DDApplyGeometry(); });
    } else {
        DDRestoreGeometry();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,80*NSEC_PER_MSEC),dispatch_get_main_queue(),^{ DDRestoreGeometry(); });
    }
}
static void DDNoAirawHostMenu(id self, SEL _cmd) { (void)self; (void)_cmd; }
static void DDInstallHostMenuSuppressor(void) {
    const char *classes[]={"DBApplicationSceneViewController","CARApplicationSceneViewController","CBBridgedUIApp","DBApplicationViewController"};
    SEL sel=NSSelectorFromString(@"arwInstallHostMenuIfNeeded");
    for(NSUInteger i=0;i<sizeof(classes)/sizeof(classes[0]);i++) {
        Class cls=objc_getClass(classes[i]); if(!cls)continue;
        Method m=class_getInstanceMethod(cls,sel); if(m) method_setImplementation(m,(IMP)DDNoAirawHostMenu);
    }
}

%hook UIWindow
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets x=%orig;
    if(DDGeometryFullscreen && DDIs427CarPlayScreen(self.screen)) return UIEdgeInsetsZero;
    return x;
}
%end
%hook UIView
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets x=%orig;
    if(DDGeometryFullscreen && DDViewIsCarPlay(self)) return UIEdgeInsetsZero;
    return x;
}
- (void)didMoveToWindow { %orig; if(DDGeometryFullscreen) DDExpandHostView(self); }
%end

%ctor {
    %init;
    NSDistributedNotificationCenter *dc=[NSDistributedNotificationCenter defaultCenter];
    [dc addObserverForName:@"jp.airaw.host.fullscreen" object:nil queue:[NSOperationQueue mainQueue]
               usingBlock:^(NSNotification *n){ DDAirawFullscreenNotification(n); }];
    dispatch_async(dispatch_get_main_queue(),^{ DDInstallHostMenuSuppressor(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{ DDInstallHostMenuSuppressor(); });
}
