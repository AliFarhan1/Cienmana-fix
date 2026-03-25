#import <Foundation/Foundation.h>

@interface DMRFile : NSObject
@property (nonatomic, assign) NSInteger downloadStatus;
@property (nonatomic, assign) double downloadProgress;
@end

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
}
