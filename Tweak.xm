#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <math.h>

static const CGFloat DDW = 427.0;
static const CGFloat DDH = 240.0;
static const CGFloat DDSide = 45.0;

static BOOL DDCP(UIScreen *s) {
    if (!s || s == UIScreen.mainScreen) return NO;
    CGSize z = s.bounds.size;
    return (fabs(z.width-DDW)<3.0 && fabs(z.height-DDH)<3.0) ||
           (fabs(z.height-DDW)<3.0 && fabs(z.width-DDH)<3.0);
}

static BOOL DDReserved(CGRect f) {
    return fabs(f.origin.x-DDSide)<3.0 || (f.size.width>370.0 && f.size.width<390.0);
}

%hook UIWindow
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets original = %orig;
    if (DDCP(self.screen)) return UIEdgeInsetsZero;
    return original;
}
%end

%hook UIView
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets original = %orig;
    if (DDCP(self.window.screen)) return UIEdgeInsetsZero;
    return original;
}

- (void)didMoveToWindow {
    %orig;
    UIWindow *w = self.window;
    if (!w || !DDCP(w.screen)) return;
    if ([NSStringFromClass(self.class) isEqualToString:@"DBStatusBarView"]) return;

    CGRect f = self.frame;
    if (DDReserved(f)) {
        f.origin.x = 0.0;
        f.size.width = DDW;
        f.size.height = DDH;
        self.frame = f;
        self.autoresizingMask |= UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
}
%end

%hook DBStatusBarWindow
- (void)setFrame:(CGRect)frame {
    if (DDCP(self.screen)) {
        CGFloat width = frame.size.width > 1.0 ? frame.size.width : DDSide;
        frame.origin.x = -fabs(width);
    }
    %orig(frame);
}
%end

%ctor {
    %init;
}
