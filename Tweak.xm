#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/*
 Minimal integration only:
 - Airaw keeps its original fullscreen button and fullscreen engine.
 - DuoDash keeps its original split/divider/drag UI.
 - Suppress only Airaw's hosted-app menu/grabber so it cannot overlap DuoDash.
 No geometry, safe-area, chrome, frame, split, or fullscreen implementation lives here.
*/

static void DDNoAirawHostMenu(id self, SEL _cmd) {
    (void)self;
    (void)_cmd;
}

static void DDInstallHostMenuSuppressorOnClass(Class cls) {
    if (!cls) return;
    SEL sel = NSSelectorFromString(@"arwInstallHostMenuIfNeeded");

    // Airaw adds this method dynamically. Replacing the IMP after it exists leaves
    // Airaw's fullscreen path intact while preventing ARWHostMenuView installation.
    Method m = class_getInstanceMethod(cls, sel);
    if (m) {
        method_setImplementation(m, (IMP)DDNoAirawHostMenu);
    }
}

static void DDInstallHostMenuSuppressor(void) {
    const char *classes[] = {
        "DBApplicationSceneViewController",
        "CARApplicationSceneViewController",
        "CBBridgedUIApp",
        "DBApplicationViewController"
    };

    for (NSUInteger i = 0; i < sizeof(classes)/sizeof(classes[0]); i++) {
        DDInstallHostMenuSuppressorOnClass(objc_getClass(classes[i]));
    }
}

%ctor {
    // Airaw installs methods during tweak initialization, so run after constructors
    // have had a chance to register its host methods. No UI is created by this shim.
    dispatch_async(dispatch_get_main_queue(), ^{
        DDInstallHostMenuSuppressor();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            DDInstallHostMenuSuppressor();
        });
    });
}
