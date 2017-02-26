//
//  JYFDownload.h
//  下载管理器
//
//  Created by mac on 2017/2/22.
//  Copyright © 2017年 mac. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JYFDownload : NSObject

/**
 下载指定url的文件
 需要扩展：通知调用者下载相关信息
 1.进度 百分比
 2.成功的结果 通知下载的路径
 3.失败的结果 出错 通知错误信息
 
 通过代理、Block
 @param url 要下载的url
 */

/**
 下载方法

 @param url url
 @param progerss 进度
 @param complete 完成
 @param error 错误
 */
- (void)downloadWithUrl:(NSURL *)url progress:(void(^)(float progress))progerss completion:(void(^)(NSString *path))complete error:(void(^)(NSString *errorMessage))error;

/**
 暂停当前的下载操作
 */
- (void)pause;

@end
