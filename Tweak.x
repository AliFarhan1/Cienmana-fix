#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ─────────────────────────────────────────────
// MARK: - Forward declarations
// ─────────────────────────────────────────────

@interface MovieDetailsViewController : UIViewController
@property (nonatomic, assign) BOOL directFileDownload;
@end

@interface NotSubscriberViewController : UIViewController
@end

@interface DMRFile : NSObject
@property (nonatomic, assign) NSInteger downloadStatus;
@property (nonatomic, assign) double downloadProgress;
@end

// ─────────────────────────────────────────────
// MARK: - Hook 1: Domain Swizzling
// يستبدل .com بـ .cc في كل الطلبات
// ─────────────────────────────────────────────

static NSString *fixDomain(NSString *str) {
    if (!str) return str;
    str = [str stringByReplacingOccurrencesOfString:@"https://cinemana.shabakaty.com"
                                         withString:@"https://cinemana.shabakaty.cc"];
    str = [str stringByReplacingOccurrencesOfString:@"https://cnth2.shabakaty.com"
                                         withString:@"https://cnth2.shabakaty.cc"];
    str = [str stringByReplacingOccurrencesOfString:@"https://share.shabakaty.com"
                                         withString:@"https://share.shabakaty.cc"];
    str = [str stringByReplacingOccurrencesOfString:@"https://account.shabakaty.com"
                                         withString:@"https://account.shabakaty.cc"];
    str = [str stringByReplacingOccurrencesOfString:@"https://updates.shabakaty.com"
                                         withString:@"https://updates.shabakaty.cc"];
    return str;
}

%hook NSURL

+ (instancetype)URLWithString:(NSString *)URLString {
    return %orig(fixDomain(URLString));
}

+ (instancetype)URLWithString:(NSString *)URLString relativeToURL:(NSURL *)baseURL {
    return %orig(fixDomain(URLString), baseURL);
}

- (instancetype)initWithString:(NSString *)URLString {
    return %orig(fixDomain(URLString));
}

%end

%hook NSMutableURLRequest

- (instancetype)initWithURL:(NSURL *)URL {
    NSString *fixed = fixDomain(URL.absoluteString);
    return %orig([NSURL URLWithString:fixed]);
}

%end

// ─────────────────────────────────────────────
// MARK: - Hook 2: إخفاء شاشة "غير مشترك"
// ─────────────────────────────────────────────

%hook NotSubscriberViewController

- (void)viewDidLoad {
    %orig;
    [self dismissViewControllerAnimated:NO completion:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    [self dismissViewControllerAnimated:NO completion:nil];
}

%​​​​​​​​​​​​​​​​
