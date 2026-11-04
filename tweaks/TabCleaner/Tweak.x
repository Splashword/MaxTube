// TabCleaner: removes chosen tabs (Shorts, "+" upload) from the YouTube bottom bar.
//
// The bottom bar ("pivot bar") is described by a guide response that YouTube
// downloads at launch. We drop the unwanted items from that response before the
// app reads it. Which tabs are removed is decided at build time (see Makefile).
//
// Each hook is installed only if the class and method exist in the running
// YouTube version, so an unknown version simply leaves the bar untouched.

#import <objc/runtime.h>
#import <substrate.h>
#import <YouTubeHeader/YTIGuideResponse.h>
#import <YouTubeHeader/YTIGuideResponseSupportedRenderers.h>
#import <YouTubeHeader/YTIPivotBarRenderer.h>
#import <YouTubeHeader/YTIPivotBarSupportedRenderers.h>

#ifndef HIDE_SHORTS_TAB
#define HIDE_SHORTS_TAB 1
#endif
#ifndef HIDE_UPLOAD_TAB
#define HIDE_UPLOAD_TAB 0
#endif

static BOOL TCShouldHide(NSString *identifier) {
    if (identifier.length == 0) return NO;
#if HIDE_SHORTS_TAB
    if ([identifier isEqualToString:@"FEshorts"]) return YES;
#endif
#if HIDE_UPLOAD_TAB
    if ([identifier isEqualToString:@"FEuploads"]) return YES;
#endif
    return NO;
}

static void TCCleanResponse(YTIGuideResponse *response) {
    if (![response respondsToSelector:@selector(itemsArray)]) return;
    for (YTIGuideResponseSupportedRenderers *guideItem in [response itemsArray]) {
        if (![guideItem respondsToSelector:@selector(pivotBarRenderer)]) continue;
        NSMutableArray<YTIPivotBarSupportedRenderers *> *tabs = [[guideItem pivotBarRenderer] itemsArray];
        if (tabs.count == 0) continue;
        NSIndexSet *toRemove = [tabs indexesOfObjectsPassingTest:^BOOL(YTIPivotBarSupportedRenderers *tab, NSUInteger idx, BOOL *stop) {
            NSString *identifier = [[tab pivotBarItemRenderer] pivotIdentifier];
            if (identifier.length == 0) identifier = [[tab pivotBarIconOnlyItemRenderer] pivotIdentifier];
            return TCShouldHide(identifier);
        }];
        // Never leave the bar empty, whatever YouTube sends.
        if (toRemove.count > 0 && toRemove.count < tabs.count)
            [tabs removeObjectsAtIndexes:toRemove];
    }
}

// One original-implementation slot per (class, selector) pair we hook.
#define TC_HOOK2(NAME)                                                                  \
    static void (*orig_##NAME)(id, SEL, id, id);                                        \
    static void hook_##NAME(id self, SEL _cmd, id response, id completion) {            \
        TCCleanResponse(response);                                                      \
        orig_##NAME(self, _cmd, response, completion);                                  \
    }
#define TC_HOOK3(NAME)                                                                  \
    static void (*orig_##NAME)(id, SEL, id, id, id);                                    \
    static void hook_##NAME(id self, SEL _cmd, id response, id error, id completion) {  \
        TCCleanResponse(response);                                                      \
        orig_##NAME(self, _cmd, response, error, completion);                           \
    }

TC_HOOK2(GuideWithCompletion)
TC_HOOK3(GuideErrorCompletion)
TC_HOOK3(AppGuideErrorCompletion)
TC_HOOK3(ImplErrorCompletion)
TC_HOOK3(ImplLegacyErrorCompletion)

static void TCHookIfPresent(const char *className, SEL selector, IMP replacement, IMP *original) {
    Class cls = objc_getClass(className);
    if (cls && class_getInstanceMethod(cls, selector))
        MSHookMessageEx(cls, selector, replacement, original);
}

%ctor {
    TCHookIfPresent("YTGuideServiceCoordinator", @selector(handleResponse:withCompletion:),
                    (IMP)hook_GuideWithCompletion, (IMP *)&orig_GuideWithCompletion);
    TCHookIfPresent("YTGuideServiceCoordinator", @selector(handleResponse:error:completion:),
                    (IMP)hook_GuideErrorCompletion, (IMP *)&orig_GuideErrorCompletion);
    TCHookIfPresent("YTAppGuideServiceCoordinator", @selector(handleResponse:error:completion:),
                    (IMP)hook_AppGuideErrorCompletion, (IMP *)&orig_AppGuideErrorCompletion);
    TCHookIfPresent("YTGuideServiceCoordinatorImpl", @selector(handleResponse:error:completion:),
                    (IMP)hook_ImplErrorCompletion, (IMP *)&orig_ImplErrorCompletion);
    TCHookIfPresent("YTGuideServiceCoordinatorImpl", @selector(handleLegacyResponse:error:completion:),
                    (IMP)hook_ImplLegacyErrorCompletion, (IMP *)&orig_ImplLegacyErrorCompletion);
}
