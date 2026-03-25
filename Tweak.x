الخطأ %hook inside a %hook at line 4 يعني أن الملف القديم لازال موجود ونُسخ فوقه. امسح محتوى Tweak.x كاملاً ثم ضع هذا فقط:

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface MovieDetailsViewController : UIViewController
@property (nonatomic, assign) BOOL directFileDownload;
@end

@interface NotSubscriberViewController : UIViewController
@end

@interface DMRFile : NSObject
@property (nonatomic, assign) NSInteger downloadStatus;
@property (nonatomic, assign) double downloadProgress;
@end

static NSString *fixDomain(NSString *str) {
    if (!str) return str;
    str = [str stringByReplacingOccurrencesOfString:@"https://cinemana.shabakaty.com" withString:@"https://cinemana.shabakaty.cc"];
    str = [str stringByReplacingOccurrencesOfString:@"https://cnth2.shabakaty.com" withString:@"https://cnth2.shabakaty.cc"];
    str = [str stringByReplacingOccurrencesOfString:@"https://share.shabakaty.com" withString:@"https://share.shabakaty.cc"];
    str = [str stringByReplacingOccurrencesOfString:@"https://account.shabakaty.com" withString:@"https://account.shabakaty.cc"];
    str = [str stringByReplacingOccurrencesOfString:@"https://updates.shabakaty.com" withString:@"https://updates.shabakaty.cc"];
    str = [str stringByReplacingOccurrencesOfString:@"https://recommend.shabakaty.com" withString:@"https://recommend.shabakaty.cc"];
    return str;
}

static NSURL *(*orig_URLWithString)(id, SEL, NSString *) = NULL;
static NSURL *ct_URLWithString(id self, SEL _cmd, NSString *str) {
    return orig_URLWithString(self, _cmd, fixDomain(str));
}

static NSURL *(*orig_URLWithStringRelative)(id, SEL, NSString *, NSURL *) = NULL;
static NSURL *ct_URLWithStringRelative(id self, SEL _cmd, NSString *str, NSURL *base) {
    return orig_URLWithStringRelative(self, _cmd, fixDomain(str), base);
}

static id (*orig_initWithURL)(id, SEL, NSURL *) = NULL;
static id ct_initWithURL(id self, SEL _cmd, NSURL *url) {
    return orig_initWithURL(self, _cmd, [NSURL URLWithString:fixDomain(url.absoluteString)]);
}

static id (*orig_initWithURLCachePolicy)(id, SEL, NSURL *, NSURLRequestCachePolicy, NSTimeInterval) = NULL;
static id ct_initWithURLCachePolicy(id self, SEL _cmd, NSURL *url, NSURLRequestCachePolicy p, NSTimeInterval t) {
    return orig_initWithURLCachePolicy(self, _cmd, [NSURL URLWithString:fixDomain(url.absoluteString)], p, t);
}

%hook NotSubscriberViewController
- (void)viewDidLoad {
    %orig;
    [self dismissViewControllerAnimated:NO completion:nil];
}
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    [self dismissViewControllerAnimated:NO completion:nil];
}
%end

%hook MovieDetailsViewController
- (BOOL)directFileDownload { return YES; }
- (void)setDirectFileDownload:(BOOL)v { %orig(YES); }
%end

%hook DMRFile
- (void)setDownloadProgress:(double)p {
    %orig(p);
    if (p >= 1.0) [self setDownloadStatus:2];
}
%end

%hook NSFileManager
- (BOOL)moveItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error {
    NSString *dst = dstURL.path;
    if ([dst containsString:@"DOWNLOADEDFILES"]) {
        NSString *dir = [dst stringByDeletingLastPathComponent];
        if (![self fileExistsAtPath:dir])
            [self createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    BOOL ok = %orig(srcURL, dstURL, error);
    if (!ok && [dst containsString:@"DOWNLOADEDFILES"]) {
        if ([self fileExistsAtPath:dst]) [self removeItemAtURL:dstURL error:nil];
        NSError *e = nil;
        if ([self copyItemAtURL:srcURL toURL:dstURL error:&e]) {
            [self removeItemAtURL:srcURL error:nil];
            if (error) *error = nil;
            return YES;
        }
    }
    return ok;
}
- (BOOL)moveItemAtPath:(NSString *)src toPath:(NSString *)dst error:(NSError **)error {
    if ([dst containsString:@"DOWNLOADEDFILES"]) {
        NSString *dir = [dst stringByDeletingLastPathComponent];
        if (![self fileExistsAtPath:dir])
            [self createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    BOOL ok = %orig(src, dst, error);
    if (!ok && [dst containsString:@"DOWNLOADEDFILES"]) {
        if ([self fileExistsAtPath:dst]) [self removeItemAtPath:dst error:nil];
        NSError *e = nil;
        if ([self copyItemAtPath:src toPath:dst error:&e]) {
            [self removeItemAtPath:src error:nil];
            if (error) *error = nil;
            return YES;
        }
    }
    return ok;
}
%end

%ctor {
    NSLog(@"[CinemanaFix] Loaded");

    Class urlClass = [NSURL class];
    Class reqClass = [NSMutableURLRequest class];

    Method m1 = class_getClassMethod(urlClass, @selector(URLWithString:));
    orig_URLWithString = (void *)method_getImplementation(m1);
    class_replaceMethod(object_getClass(urlClass), @selector(URLWithString:), (IMP)ct_URLWithString, method_getTypeEncoding(m1));

    Method m2 = class_getClassMethod(urlClass, @selector(URLWithString:relativeToURL:));
    orig_URLWithStringRelative = (void *)method_getImplementation(m2);
    class_replaceMethod(object_getClass(urlClass), @selector(URLWithString:relativeToURL:), (IMP)ct_URLWithStringRelative, method_getTypeEncoding(m2));

    Method m3 = class_getInstanceMethod(reqClass, @selector(initWithURL:));
    orig_initWithURL = (void *)method_getImplementation(m3);
    class_replaceMethod(reqClass, @selector(initWithURL:), (IMP)ct_initWithURL, method_getTypeEncoding(m3));

    Method m4 = class_getInstanceMethod(reqClass, @selector(initWithURL:cachePolicy:timeoutInterval:));
    orig_initWithURLCachePolicy = (void *)method_getImplementation(m4);
    class_replaceMethod(reqClass, @selector(initWithURL:cachePolicy:timeoutInterval:), (IMP)ct_initWithURLCachePolicy, method_getTypeEncoding(m4));

    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *dir = [[paths firstObject] stringByAppendingPathComponent:@"DOWNLOADEDFILES"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir])
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    });
}
