#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString *DDDoctorDir(void) {
    NSString *base=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/DauDat"];
    [[NSFileManager defaultManager] createDirectoryAtPath:base withIntermediateDirectories:YES attributes:nil error:nil];
    return base;
}
static NSString *DDDoctorReportPath(void) { return [DDDoctorDir() stringByAppendingPathComponent:@"DauDat-Diagnostic.txt"]; }
static NSString *DDDoctorBaselinePath(void) { return [DDDoctorDir() stringByAppendingPathComponent:@"DauDat-Baseline.txt"]; }

static NSString *DDDoctorSnapshot(void) {
    NSMutableString *o=[NSMutableString string];
    [o appendFormat:@"=== DAUDAT DOCTOR ===\nDate: %@\nProcess: %@ pid=%d\nDevice: %@ %@\n",
      NSDate.date, NSProcessInfo.processInfo.processName, getpid(), UIDevice.currentDevice.model, UIDevice.currentDevice.systemVersion];
    NSDictionary *cfg=DDLoadConfiguration();
    [o appendFormat:@"Config: %@\nFullscreen: %d\n",cfg,gDDFullscreen];
    NSArray *screens=UIScreen.screens;
    [o appendFormat:@"Screens: %lu\n",(unsigned long)screens.count];
    [screens enumerateObjectsUsingBlock:^(UIScreen *s, NSUInteger i, BOOL *stop){
        [o appendFormat:@"SCREEN[%lu] bounds=%@ native=%@ scale=%.3f nativeScale=%.3f\n",
         (unsigned long)i,NSStringFromCGRect(s.bounds),NSStringFromCGRect(s.nativeBounds),s.scale,s.nativeScale];
    }];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        [o appendFormat:@"SCENE role=%@ state=%ld screen=%@ windows=%lu\n",scene.session.role,(long)scene.activationState,
         NSStringFromCGRect(ws.screen.bounds),(unsigned long)ws.windows.count];
        [ws.windows enumerateObjectsUsingBlock:^(UIWindow *w, NSUInteger i, BOOL *stop){
            NSString *root=w.rootViewController?NSStringFromClass(w.rootViewController.class):@"(null)";
            [o appendFormat:@" WIN[%lu] class=%@ frame=%@ bounds=%@ safe=%@ hidden=%d level=%.1f root=%@\n",
             (unsigned long)i,NSStringFromClass(w.class),NSStringFromCGRect(w.frame),NSStringFromCGRect(w.bounds),
             NSStringFromUIEdgeInsets(w.safeAreaInsets),w.hidden,w.windowLevel,root];
        }];
    }
    UIWindow *bar=DDStatusBarWindow();
    [o appendFormat:@"Sidebar: %@\n",bar?NSStringFromCGRect(bar.frame):@"NOT_FOUND"];
    return o;
}
static NSString *DDDoctorWrite(BOOL baseline) {
    NSString *snap=DDDoctorSnapshot();
    NSString *path=baseline?DDDoctorBaselinePath():DDDoctorReportPath();
    if (!baseline) {
        NSString *b=[NSString stringWithContentsOfFile:DDDoctorBaselinePath() encoding:NSUTF8StringEncoding error:nil];
        if (b.length) [snap=[snap mutableCopy] appendFormat:@"\n=== BASELINE PRESENT ===\nBaseline bytes: %lu\n",(unsigned long)[b lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
        else [snap=[snap mutableCopy] appendString:@"\n=== BASELINE ===\nMISSING\n"];
    }
    [snap writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    return path;
}
