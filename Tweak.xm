#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
static const CGFloat DDW=427.0, DDH=240.0, DDSide=45.0;
static BOOL DDCP(UIScreen*s){if(!s||s==UIScreen.mainScreen)return NO;CGSize z=s.bounds.size;return (fabs(z.width-DDW)<3&&fabs(z.height-DDH)<3)||(fabs(z.height-DDW)<3&&fabs(z.width-DDH)<3);}
static BOOL DDR(CGRect f){return fabs(f.origin.x-DDSide)<3||(f.size.width>370&&f.size.width<390);}
%hook UIWindow
-(UIEdgeInsets)safeAreaInsets{UIEdgeInsets i=%orig;if(DDCP(self.screen))return UIEdgeInsetsZero;return i;}
%end
%hook UIView
-(UIEdgeInsets)safeAreaInsets{UIEdgeInsets i=%orig;if(DDCP(self.window.screen))return UIEdgeInsetsZero;return i;}
-(void)didMoveToWindow{%orig;UIWindow*w=self.window;if(!w||!DDCP(w.screen))return;if([NSStringFromClass(self.class) isEqualToString:@"DBStatusBarView"])return;CGRect f=self.frame;if(DDR(f)){f.origin.x=0;f.size.width=DDW;f.size.height=DDH;self.frame=f;self.autoresizingMask|=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;}}
%end
%hook DBStatusBarWindow
-(void)setFrame:(CGRect)f{if(DDCP(self.screen))f.origin.x=-fabs(f.size.width>1?f.size.width:DDSide);%orig;}
%end
%ctor{%init;}
