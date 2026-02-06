#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.lolados.sp.Sao-Paulo-Onibus";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "BackgroundColor" asset catalog color resource.
static NSString * const ACColorNameBackgroundColor AC_SWIFT_PRIVATE = @"BackgroundColor";

/// The "LightGray" asset catalog color resource.
static NSString * const ACColorNameLightGray AC_SWIFT_PRIVATE = @"LightGray";

/// The "PrimaryColor" asset catalog color resource.
static NSString * const ACColorNamePrimaryColor AC_SWIFT_PRIVATE = @"PrimaryColor";

/// The "TextColor" asset catalog color resource.
static NSString * const ACColorNameTextColor AC_SWIFT_PRIVATE = @"TextColor";

#undef AC_SWIFT_PRIVATE
