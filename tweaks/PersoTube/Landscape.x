// PersoTube - landscape lock: allow only ONE landscape side.
//
// LANDSCAPE_SIDE is set at build time:
//   0 = off (normal behaviour)
//   1 = camera on the RIGHT (phone turned so its top points right)
//   2 = camera on the LEFT  (phone turned so its top points left)
//
// Apple naming is confusing: UIInterfaceOrientationLandscapeLeft means the
// home side is on the left, so the top of the phone (camera) is on the RIGHT.
//
// Wherever YouTube or iOS asks "which orientations are allowed?", the unwanted
// landscape side is replaced by the wanted one. This covers both turning the
// phone and YouTube's own full-screen / rotate button.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

#ifndef LANDSCAPE_SIDE
#define LANDSCAPE_SIDE 0
#endif

#if LANDSCAPE_SIDE != 0

#if LANDSCAPE_SIDE == 1
static const UIInterfaceOrientationMask kKeepMask = UIInterfaceOrientationMaskLandscapeLeft;
static const UIInterfaceOrientationMask kDropMask = UIInterfaceOrientationMaskLandscapeRight;
static const UIDeviceOrientation kKeepDevice = UIDeviceOrientationLandscapeRight; // device and interface sides are mirrored
static const UIDeviceOrientation kDropDevice = UIDeviceOrientationLandscapeLeft;
#else
static const UIInterfaceOrientationMask kKeepMask = UIInterfaceOrientationMaskLandscapeRight;
static const UIInterfaceOrientationMask kDropMask = UIInterfaceOrientationMaskLandscapeLeft;
static const UIDeviceOrientation kKeepDevice = UIDeviceOrientationLandscapeLeft;
static const UIDeviceOrientation kDropDevice = UIDeviceOrientationLandscapeRight;
#endif

// Replace the unwanted landscape side by the wanted one; keep everything else.
// Applied to every mask (app, view controllers, rotation requests), so they
// always agree and iOS never ends up with "no allowed orientation".
static UIInterfaceOrientationMask LLFilter(UIInterfaceOrientationMask mask) {
    if ((mask & kDropMask) == 0) return mask;
    return (mask & ~kDropMask) | kKeepMask;
}

// -[UIApplication supportedInterfaceOrientationsForWindow:] (app-wide mask)
static UIInterfaceOrientationMask (*orig_appMask)(id, SEL, id);
static UIInterfaceOrientationMask hook_appMask(id self, SEL _cmd, id window) {
    return LLFilter(orig_appMask(self, _cmd, window));
}

// -[UIViewController __supportedInterfaceOrientations] (UIKit's internal entry
// point that wraps every view controller's supportedInterfaceOrientations)
static UIInterfaceOrientationMask (*orig_vcMask)(id, SEL);
static UIInterfaceOrientationMask hook_vcMask(id self, SEL _cmd) {
    return LLFilter(orig_vcMask(self, _cmd));
}

// -[UIWindowScene requestGeometryUpdateWithPreferences:errorHandler:] (iOS 16+,
// used by apps to force a rotation, e.g. the full-screen button)
static void (*orig_geometry)(id, SEL, id, id);
static void hook_geometry(id self, SEL _cmd, id preferences, id errorHandler) {
    Class iosPrefs = NSClassFromString(@"UIWindowSceneGeometryPreferencesIOS");
    if (iosPrefs && [preferences isKindOfClass:iosPrefs]) {
        // Key-value access keeps this building against the iOS 14 deployment target.
        NSUInteger mask = [[preferences valueForKey:@"interfaceOrientations"] unsignedIntegerValue];
        [preferences setValue:@(LLFilter(mask)) forKey:@"interfaceOrientations"];
    }
    orig_geometry(self, _cmd, preferences, errorHandler);
}

// -[UIDevice setOrientation:] (older way to force a rotation, via KVC "orientation")
static void (*orig_setOrientation)(id, SEL, UIDeviceOrientation);
static void hook_setOrientation(id self, SEL _cmd, UIDeviceOrientation orientation) {
    orig_setOrientation(self, _cmd, orientation == kDropDevice ? kKeepDevice : orientation);
}
static void (*orig_setOrientationAnimated)(id, SEL, UIDeviceOrientation, BOOL);
static void hook_setOrientationAnimated(id self, SEL _cmd, UIDeviceOrientation orientation, BOOL animated) {
    orig_setOrientationAnimated(self, _cmd, orientation == kDropDevice ? kKeepDevice : orientation, animated);
}

static void LLHookIfPresent(Class cls, SEL selector, IMP replacement, IMP *original) {
    if (cls && class_getInstanceMethod(cls, selector))
        MSHookMessageEx(cls, selector, replacement, original);
}

__attribute__((constructor)) static void LLInit(void) {
    LLHookIfPresent([UIApplication class], @selector(supportedInterfaceOrientationsForWindow:),
                    (IMP)hook_appMask, (IMP *)&orig_appMask);
    LLHookIfPresent([UIViewController class], NSSelectorFromString(@"__supportedInterfaceOrientations"),
                    (IMP)hook_vcMask, (IMP *)&orig_vcMask);
    LLHookIfPresent(NSClassFromString(@"UIWindowScene"), @selector(requestGeometryUpdateWithPreferences:errorHandler:),
                    (IMP)hook_geometry, (IMP *)&orig_geometry);
    LLHookIfPresent([UIDevice class], NSSelectorFromString(@"setOrientation:"),
                    (IMP)hook_setOrientation, (IMP *)&orig_setOrientation);
    LLHookIfPresent([UIDevice class], NSSelectorFromString(@"setOrientation:animated:"),
                    (IMP)hook_setOrientationAnimated, (IMP *)&orig_setOrientationAnimated);
}

#endif
