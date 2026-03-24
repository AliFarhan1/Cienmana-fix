#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ─────────────────────────────────────────────
// السبب الجذري:
// التطبيق يستخدم Background URL Session بـ identifier = ".background"
// عند تغيير الـ Bundle ID أو Team ID بالتوقيع،
// يفشل iOS في ربط الـ session المكتملة بالتطبيق الجديد
// فيحذف الـ temp file دون إشعار الـ app
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
// MARK: - Forward declarations
// ─────────────────────────────────────────────

@interface DMRFile : NSObject
@property (nonatomic, assign) NSInteger downloadStatus;
@property (nonatomic, assign) double downloadProgress;
@end

@interface MovieDetailsViewModel : NSObject
@property (nonatomic, assign) BOOL subscribed;
@end

@interface MovieDetailsViewController : UIViewController
@property (nonatomic, assign) BOOL directFileDownload;
@end

// ─────────────────────────────────────────────
// MARK: - الحل الجذري: Hook على NSURLSessionConfiguration
// نستبدل الـ background session بـ default session
// حتى لا يعتمد التطبيق على الـ background session identifier
// ─────────────────────────────────────────────

%hook NSURLSessionConfiguration

// عندما التطبيق يطلب إنشاء background session
+ (NSURLSessionConfiguration *)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier {
    NSLog(@"[CinemanaFix] 🔄 backgroundSession requested: %@", identifier);
    
    // نستخدم default session بدلاً من background
    // هذا يحل مشكلة الـ identifier mismatch بعد إعادة التوقيع
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.allowsCellularAccess = YES;
    config.timeoutIntervalForRequest = 0; // بدون timeout للملفات الكبيرة
    config.timeoutIntervalForResource = 0;
    config.HTTPMaximumConnectionsPerHost = 4;
    
    NSLog(@"[CinemanaFix] ✅ Replaced background session with default session");
    return config;
}

%end

// ─────────────────────────────────────────────
// MARK: - Hook على NSURLSession نفسها
// نضمن أن الـ delegate يُستدعى دائماً
// ─────────────────────────────────────────────

%hook NSURLSession

+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration
                                  delegate:(id)delegate
                             delegateQueue:(NSOperationQueue *)queue {
    
    // إذا كانت background config، حوّلها لـ default
    if (configuration.identifier) {
        NSLog(@"[CinemanaFix] 🔄 Session with identifier: %@", configuration.identifier);
        NSURLSessionConfiguration *newConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        newConfig.allowsCellularAccess = YES;
        newConfig.timeoutIntervalForRequest = 0;
        newConfig.timeoutIntervalForResource = 0;
        newConfig.HTTPMaximumConnectionsPerHost = 4;
        return %orig(newConfig, delegate, queue);
    }
    
    return %orig(configuration, delegate, queue);
}

%end

// ─────────────────────────────────────────────
// MARK: - Hook NSFileManager لضمان نقل الملف
// ─────────────────────────────────────────────

%hook NSFileManager

- (BOOL)moveItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error {
    NSString *dst = dstURL.path;
    
    if ([dst containsString:@"DOWNLOADEDFILES"] || [dst containsString:@"Cinemana"]) {
        // تأكد من وجود المجلد
        NSString *dir = [dst stringByDeletingLastPathComponent];
        if (![self fileExistsAtPath:dir]) {
            [self createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
            NSLog(@"[CinemanaFix] 📁 Created dir: %@", dir);
        }
    }
    
    BOOL ok = %orig(srcURL, dstURL, error);
    
    if (!ok && [dst containsString:@"DOWNLOADEDFILES"]) {
        NSLog(@"[CinemanaFix] ⚠️ move failed, trying copy...");
        if ([self fileExistsAtPath:dst]) [self removeItemAtURL:dstURL error:nil];
        NSError *e = nil;
        if ([self copyItemAtURL:srcURL toURL:dstURL error:&e]) {
            [self removeItemAtURL:srcURL error:nil];
            if (error) *error = nil;
            NSLog(@"[CinemanaFix] ✅ copy succeeded");
            return YES;
        }
        NSLog(@"[CinemanaFix] ❌ copy also failed: %@", e);
    }
    return ok;
}

- (BOOL)moveItemAtPath:(NSString *)src toPath:(NSString *)dst error:(NSError **)error {
    if ([dst containsString:@"DOWNLOADEDFILES"]) {
        NSString *dir = [dst stringByDeletingLastPathComponent];
        if (![self fileExistsAtPath:dir]) {
            [self createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        }
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

// ─────────────────────────────────────────────
// MARK: - Hook DMRFile و MovieDetailsViewController
// ─────────────────────────────────────────────

%hook MovieDetailsViewModel
- (BOOL)subscribed { return YES; }
- (void)setSubscribed:(BOOL)v { %orig(YES); }
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

// ─────────────────────────────────────────────
// MARK: - Constructor
// ─────────────────────────────────────────────

%ctor {
    NSLog(@"[CinemanaFix] 🚀 v3 loaded - background session fix active");
    
    // تأكد من وجود DOWNLOADEDFILES directory
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *dir = [[paths firstObject] stringByAppendingPathComponent:@"DOWNLOADEDFILES"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                     withIntermediateDirectories:YES
                                                      attributes:nil
                                                           error:nil];
            NSLog(@"[CinemanaFix] 📁 DOWNLOADEDFILES created at: %@", dir);
        }
    });
}
