//
//  JYFDownloadManager.h
//  下载管理器
//
//  Created by JiaYuanFa on 2017/2/27.
//  Copyright © 2017年 mac. All rights reserved.
//

// 负责管理所有下载任务

#import <Foundation/Foundation.h>

@interface JYFDownloadManager : NSObject

+ (instancetype)shareInstance;

- (void)downloadWithURL:(NSURL *)url Progress:(void (^)(float progress))progress completion:(void (^)(NSString * filePath))completion failed:(void (^)(NSString * errorMsg))failed;

- (void)pauseDownloadWithUrl:(NSURL *)url;

@end
