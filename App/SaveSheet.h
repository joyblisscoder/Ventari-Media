#import <AppKit/AppKit.h>

@interface SaveSheet : NSObject
- (void)beginOnWindow:(NSWindow *)parent
        suggestedName:(NSString *)name
           completion:(void (^)(NSString * _Nullable chosenName))completion;
@end
