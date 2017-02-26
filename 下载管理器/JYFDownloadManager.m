//
//  JYFDownloadManager.m
//  下载管理器
//
//  Created by JiaYuanFa on 2017/2/27.
//  Copyright © 2017年 mac. All rights reserved.
//

#import "JYFDownloadManager.h"
#import "JYFDownload.h"

@interface JYFDownloadManager()

/**
 下载缓冲池
 */
@property (nonatomic, strong) NSMutableDictionary *downloaderCache;

@property (nonatomic, copy) void(^failBlock)(NSString *);

@end

@implementation JYFDownloadManager

+ (instancetype)shareInstance{
    static id shareInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareInstance = [[self alloc] init];
    });
    return shareInstance;
}

- (NSMutableDictionary *)downloaderCache{
    if (!_downloaderCache) {
        _downloaderCache = [NSMutableDictionary dictionary];
    }
    return _downloaderCache;
}

-(void)downloadWithURL:(NSURL *)url Progress:(void (^)(float progress))progress completion:(void (^)(NSString * filePath))completion failed:(void (^)(NSString * errorMsg))failed{
    if (failed) {
        self.failBlock = failed;
    }
    
    // 判断当前缓冲池中是否有任务
    JYFDownload *download = self.downloaderCache[url.path];
    if (download != nil) {
        NSLog(@"下载操作已经存在");
        return;
    }
    
    // 创建新的下载任务
    download = [[JYFDownload alloc] init];
    
    // 将下载任务保存到缓冲池
    [self.downloaderCache setValue:download forKey:url.path];
    
    // 开始下载
    [download downloadWithUrl:url progress:^(float progress) {
       
    } completion:^(NSString *path) {
        // 删除下载缓冲池中的下载操作
        [self.downloaderCache removeObjectForKey:url.path];
        
        if (completion) {
            completion(path);
        }
        
    } error:^(NSString *errorMessage) {
        
        [self.downloaderCache removeObjectForKey:url.path];
        
        if (failed) {
            failed(errorMessage);
        }
    }];
}

- (void)pauseDownloadWithUrl:(NSURL *)url{
    JYFDownload *download = self.downloaderCache[url.path];
    if (download == nil) {
        NSLog(@"下载不存在");
        if (self.failBlock) {
            self.failBlock(@"操作不存在");
        }
        return;
    }
    
    [download pause];
    
    // 从缓冲池删除任务 下载下载会再次创建一个Dwonload任务
    [self.downloaderCache removeObjectForKey:url.path];
    
}

@end
