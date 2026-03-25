#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

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
    return %orig([NSURL URLWithString:fixDomain(URL.absoluteString)]);
}
%end

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
- (BOOL)directFileDownload {
    return YES;
}
- (void)setDirectFileDownload:(BOOL)v {
    %orig(YES);
}
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
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *dir = [[paths firstObject] stringByAppendingPathComponent:@"DOWNLOADEDFILES"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir])
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    });
}
