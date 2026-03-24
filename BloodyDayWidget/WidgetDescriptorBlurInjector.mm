//
//  WidgetDescriptorBlurInjector.mm
//  BloodyDayWidget
//
//  Created by Yunki on 3/24/26.
//

#import "WidgetDescriptorBlurInjector.h"

#import <objc/message.h>
#import <objc/runtime.h>

static NSString * const kSmallWidgetKind = @"BloodyDayWidget";
static NSString * const kCircularWidgetKind = @"BloodyDayLockScreenCircularWidget";
static NSString * const kRectangularWidgetKind = @"BloodyDayLockScreenRectangularWidget";

@interface BDDescriptorFetchResult : NSObject <NSSecureCoding> {
    NSArray *_activityDescriptors;
    NSArray *_controlDescriptors;
    NSArray *_widgetDescriptors;
}
@end

@implementation BDDescriptorFetchResult

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    Class baseDescriptorClass = objc_lookUpClass("CHSBaseDescriptor");
    Class controlDescriptorClass = objc_lookUpClass("CHSControlDescriptor");
    Class widgetDescriptorClass = objc_lookUpClass("CHSWidgetDescriptor");

    NSSet *activityClasses = [NSSet setWithObjects:NSArray.class, baseDescriptorClass ?: NSObject.class, nil];
    NSSet *controlClasses = [NSSet setWithObjects:NSArray.class, controlDescriptorClass ?: NSObject.class, nil];
    NSSet *widgetClasses = [NSSet setWithObjects:NSArray.class, widgetDescriptorClass ?: NSObject.class, nil];

    NSArray *activityDescriptors = [coder decodeObjectOfClasses:activityClasses forKey:@"activityDescriptors"] ?: @[];
    NSArray *controlDescriptors = [coder decodeObjectOfClasses:controlClasses forKey:@"controlDescriptors"] ?: @[];
    NSArray *widgetDescriptors = [coder decodeObjectOfClasses:widgetClasses forKey:@"widgetDescriptors"] ?: @[];

    NSMutableArray *newWidgetDescriptors = [[NSMutableArray alloc] initWithCapacity:widgetDescriptors.count];
    for (id widgetDescriptor in widgetDescriptors) {
        SEL kindSelector = sel_registerName("kind");
        if (![widgetDescriptor respondsToSelector:kindSelector]) {
            [newWidgetDescriptors addObject:widgetDescriptor];
            continue;
        }

        NSString *(*kindCall)(id, SEL) = reinterpret_cast<NSString *(*)(id, SEL)>(objc_msgSend);
        NSString *kind = kindCall(widgetDescriptor, kindSelector);
        if (kind == nil) {
            [newWidgetDescriptors addObject:widgetDescriptor];
            continue;
        }

        if (![kind isEqualToString:kSmallWidgetKind]
            && ![kind isEqualToString:kCircularWidgetKind]
            && ![kind isEqualToString:kRectangularWidgetKind]) {
            [newWidgetDescriptors addObject:widgetDescriptor];
            continue;
        }

        id mutableWidgetDescriptor = [widgetDescriptor mutableCopy];
        if (mutableWidgetDescriptor == nil) {
            [newWidgetDescriptors addObject:widgetDescriptor];
            continue;
        }

        void (*boolCall)(id, SEL, BOOL) = reinterpret_cast<void (*)(id, SEL, BOOL)>(objc_msgSend);
        void (*integerCall)(id, SEL, NSInteger) = reinterpret_cast<void (*)(id, SEL, NSInteger)>(objc_msgSend);

        SEL backgroundRemovableSelector = sel_registerName("setBackgroundRemovable:");
        if ([mutableWidgetDescriptor respondsToSelector:backgroundRemovableSelector]) {
            boolCall(mutableWidgetDescriptor, backgroundRemovableSelector, YES);
        }

        SEL transparentSelector = sel_registerName("setTransparent:");
        if ([mutableWidgetDescriptor respondsToSelector:transparentSelector]) {
            boolCall(mutableWidgetDescriptor, transparentSelector, YES);
        }

        SEL vibrantSelector = sel_registerName("setSupportsVibrantContent:");
        if ([mutableWidgetDescriptor respondsToSelector:vibrantSelector]) {
            boolCall(mutableWidgetDescriptor, vibrantSelector, YES);
        }

        SEL preferredBackgroundStyleSelector = sel_registerName("setPreferredBackgroundStyle:");
        if ([mutableWidgetDescriptor respondsToSelector:preferredBackgroundStyleSelector]) {
            integerCall(mutableWidgetDescriptor, preferredBackgroundStyleSelector, 0x2);
        }

        [newWidgetDescriptors addObject:mutableWidgetDescriptor];
    }

    _activityDescriptors = [activityDescriptors copy];
    _controlDescriptors = [controlDescriptors copy];
    _widgetDescriptors = [newWidgetDescriptors copy];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_activityDescriptors forKey:@"activityDescriptors"];
    [coder encodeObject:_controlDescriptors forKey:@"controlDescriptors"];
    [coder encodeObject:_widgetDescriptors forKey:@"widgetDescriptors"];
}

@end

namespace bd_widget_private_blur {
namespace exported_object_swizzle {
    using OriginalImplementation = void (*)(id, SEL, id);
    static OriginalImplementation original = nullptr;

    static void custom(id self, SEL _cmd, void (^completion)(id fetchResult)) {
        original(self, _cmd, ^(id fetchResult_1) {
            NSError *error = nil;
            NSKeyedArchiver *archiver_1 = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
            [fetchResult_1 encodeWithCoder:archiver_1];
            NSData *encodedData_1 = archiver_1.encodedData;

            NSKeyedUnarchiver *unarchiver_1 = [[NSKeyedUnarchiver alloc] initForReadingFromData:encodedData_1 error:&error];
            if (unarchiver_1 == nil || error != nil) {
                completion(fetchResult_1);
                return;
            }

            BDDescriptorFetchResult *fetchResult_2 = [[BDDescriptorFetchResult alloc] initWithCoder:unarchiver_1];

            NSKeyedArchiver *archiver_2 = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
            [fetchResult_2 encodeWithCoder:archiver_2];
            NSData *encodedData_2 = archiver_2.encodedData;

            NSError *secondError = nil;
            NSKeyedUnarchiver *unarchiver_3 = [[NSKeyedUnarchiver alloc] initForReadingFromData:encodedData_2 error:&secondError];
            if (unarchiver_3 == nil || secondError != nil) {
                completion(fetchResult_1);
                return;
            }

            Class descriptorFetchResultClass = objc_lookUpClass("_TtC9WidgetKit21DescriptorFetchResult");
            if (descriptorFetchResultClass == Nil) {
                completion(fetchResult_1);
                return;
            }

            id fetchResult_3 = [[descriptorFetchResultClass alloc] initWithCoder:unarchiver_3];
            if (fetchResult_3 == nil) {
                completion(fetchResult_1);
                return;
            }

            completion(fetchResult_3);
        });
    }

    static void swizzle() {
        Class exportedObjectClass = objc_lookUpClass("_TtCC9WidgetKit24WidgetExtensionXPCServer14ExportedObject");
        if (exportedObjectClass == Nil) {
            return;
        }

        SEL selector = sel_registerName("getAllCurrentDescriptorsWithCompletion:");
        Method method = class_getInstanceMethod(exportedObjectClass, selector);
        if (method == nullptr) {
            return;
        }

        original = reinterpret_cast<OriginalImplementation>(method_getImplementation(method));
        method_setImplementation(method, reinterpret_cast<IMP>(custom));
    }
}
}

@implementation WidgetDescriptorBlurInjector

+ (void)load {
    bd_widget_private_blur::exported_object_swizzle::swizzle();
}

@end
