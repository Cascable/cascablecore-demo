#import <Foundation/Foundation.h>

@interface CascableCoreLicense : NSObject

/// Returns a CascableCore license.
+(NSData *)license __attribute__((unavailable("You must supply your own CascableCore license.")));

@end
