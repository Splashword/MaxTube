// PersoTube - bottom bar: choose which tabs are shown, and in which order.
//
// The bottom bar ("pivot bar") is described by a guide response that YouTube
// downloads at launch. We rebuild its list of tabs before the app reads it.
//
// TAB_ORDER is set at build time, e.g. "home,subscriptions,you":
//   - listed tabs are shown in that order,
//   - tabs not listed are removed.
// Known names: home, shorts, upload, subscriptions, you, explore.
// If none of the listed tabs is found (unknown YouTube version), the bar is
// left untouched. An empty TAB_ORDER disables this file entirely.
//
// Each hook is installed only if the class and method exist in the running
// YouTube version.

#import <objc/message.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <YouTubeHeader/YTIBrowseRequest.h>
#import <YouTubeHeader/YTIGuideResponse.h>
#import <YouTubeHeader/YTIGuideResponseSupportedRenderers.h>
#import <YouTubeHeader/YTIPivotBarRenderer.h>
#import <YouTubeHeader/YTIPivotBarSupportedRenderers.h>

#ifndef TAB_ORDER
#define TAB_ORDER ""
#endif

static NSArray<NSString *> *gWantedNames;              // e.g. @[@"home", @"subscriptions", @"you"]
static NSDictionary<NSString *, NSString *> *gIdToName; // pivot identifier -> tab name

static void PTAddIds(NSMutableDictionary *map, NSString *name, NSArray *ids) {
    for (id identifier in ids)
        if ([identifier isKindOfClass:[NSString class]] && [identifier length]) map[identifier] = name;
}

static NSString *PTBrowseId(SEL selector) {
    Class cls = objc_getClass("YTIBrowseRequest");
    if (cls && [cls respondsToSelector:selector]) return ((NSString *(*)(id, SEL))objc_msgSend)(cls, selector);
    return nil;
}

static void PTBuildIdMap(void) {
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    // Literal identifiers first, then whatever this YouTube version reports.
    PTAddIds(map, @"home", @[ @"FEwhat_to_watch" ]);
    PTAddIds(map, @"shorts", @[ @"FEshorts" ]);
    PTAddIds(map, @"upload", @[ @"FEuploads" ]);
    PTAddIds(map, @"subscriptions", @[ @"FEsubscriptions" ]);
    PTAddIds(map, @"you", @[ @"FElibrary", @"FEyou" ]);
    PTAddIds(map, @"explore", @[ @"FEexplore", @"FEtrending" ]);
    NSString *s;
    if ((s = PTBrowseId(@selector(browseIDForHomeTab)))) map[s] = @"home";
    if ((s = PTBrowseId(@selector(browseIDForSubscriptionsTab)))) map[s] = @"subscriptions";
    if ((s = PTBrowseId(@selector(browseIDForLibraryTab)))) map[s] = @"you";
    if ((s = PTBrowseId(@selector(browseIDForAccountTab)))) map[s] = @"you";
    if ((s = PTBrowseId(@selector(browseIDForExploreTab)))) map[s] = @"explore";
    if ((s = PTBrowseId(@selector(browseIDForTrendingTab)))) map[s] = @"explore";
    gIdToName = map;
}

static NSString *PTTabName(YTIPivotBarSupportedRenderers *tab) {
    NSString *identifier = [[tab pivotBarItemRenderer] pivotIdentifier];
    if (identifier.length == 0) identifier = [[tab pivotBarIconOnlyItemRenderer] pivotIdentifier];
    return identifier.length ? gIdToName[identifier] : nil;
}

static void PTRearrange(YTIGuideResponse *response) {
    if (gWantedNames.count == 0) return;
    if (!gIdToName) PTBuildIdMap(); // YTIBrowseRequest is loaded by now
    if (![response respondsToSelector:@selector(itemsArray)]) return;
    for (YTIGuideResponseSupportedRenderers *guideItem in [response itemsArray]) {
        if (![guideItem respondsToSelector:@selector(pivotBarRenderer)]) continue;
        NSMutableArray<YTIPivotBarSupportedRenderers *> *tabs = [[guideItem pivotBarRenderer] itemsArray];
        if (tabs.count == 0) continue;
        NSMutableArray *result = [NSMutableArray array];
        for (NSString *wanted in gWantedNames)
            for (YTIPivotBarSupportedRenderers *tab in tabs)
                if ([PTTabName(tab) isEqualToString:wanted] && ![result containsObject:tab])
                    [result addObject:tab];
        // Never leave the bar empty, whatever YouTube sends.
        if (result.count > 0) [tabs setArray:result];
    }
}

// One original-implementation slot per (class, selector) pair we hook.
#define PT_HOOK2(NAME)                                                                  \
    static void (*orig_##NAME)(id, SEL, id, id);                                        \
    static void hook_##NAME(id self, SEL _cmd, id response, id completion) {            \
        PTRearrange(response);                                                          \
        orig_##NAME(self, _cmd, response, completion);                                  \
    }
#define PT_HOOK3(NAME)                                                                  \
    static void (*orig_##NAME)(id, SEL, id, id, id);                                    \
    static void hook_##NAME(id self, SEL _cmd, id response, id error, id completion) {  \
        PTRearrange(response);                                                          \
        orig_##NAME(self, _cmd, response, error, completion);                           \
    }

PT_HOOK2(GuideWithCompletion)
PT_HOOK3(GuideErrorCompletion)
PT_HOOK3(AppGuideErrorCompletion)
PT_HOOK3(ImplErrorCompletion)
PT_HOOK3(ImplLegacyErrorCompletion)

static void PTHookIfPresent(const char *className, SEL selector, IMP replacement, IMP *original) {
    Class cls = objc_getClass(className);
    if (cls && class_getInstanceMethod(cls, selector))
        MSHookMessageEx(cls, selector, replacement, original);
}

%ctor {
    NSMutableArray *names = [NSMutableArray array];
    for (NSString *part in [@TAB_ORDER componentsSeparatedByString:@","]) {
        NSString *name = [[part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString];
        if (name.length) [names addObject:name];
    }
    gWantedNames = names;
    if (names.count == 0) return;

    PTHookIfPresent("YTGuideServiceCoordinator", @selector(handleResponse:withCompletion:),
                    (IMP)hook_GuideWithCompletion, (IMP *)&orig_GuideWithCompletion);
    PTHookIfPresent("YTGuideServiceCoordinator", @selector(handleResponse:error:completion:),
                    (IMP)hook_GuideErrorCompletion, (IMP *)&orig_GuideErrorCompletion);
    PTHookIfPresent("YTAppGuideServiceCoordinator", @selector(handleResponse:error:completion:),
                    (IMP)hook_AppGuideErrorCompletion, (IMP *)&orig_AppGuideErrorCompletion);
    PTHookIfPresent("YTGuideServiceCoordinatorImpl", @selector(handleResponse:error:completion:),
                    (IMP)hook_ImplErrorCompletion, (IMP *)&orig_ImplErrorCompletion);
    PTHookIfPresent("YTGuideServiceCoordinatorImpl", @selector(handleLegacyResponse:error:completion:),
                    (IMP)hook_ImplLegacyErrorCompletion, (IMP *)&orig_ImplLegacyErrorCompletion);
}
