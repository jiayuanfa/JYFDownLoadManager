//
//  JYFDownload.m
//  下载管理器
//
//  Created by mac on 2017/2/22.
//  Copyright © 2017年 mac. All rights reserved.
//
/**
 目的 --> 下载
 1.先实现一个简单的下载功能！！
 2.对外提供接口
 */
#import "JYFDownload.h"

#define kTimeOut 20

@interface JYFDownload()<NSURLConnectionDataDelegate>

/**
 文件输出流
 */
@property (nonatomic,strong) NSOutputStream *fileStream;

/**
 网络文件总大小
 */
@property (nonatomic, assign) long long expectedLength;

/**
 文件路径
 */
@property (nonatomic, copy) NSString *filePath;

/**
 本地文件总大小
 */
@property (nonatomic, assign) long long currentFileLength;

/**
 当前Url
 */
@property (nonatomic, strong) NSURL *currentUrl;

/**
 下载的Runloop
 */
@property (nonatomic, assign) CFRunLoopRef downloadRunloop;

/**
 当前的下载任务
 */
@property (nonatomic, strong) NSURLConnection *downloadConnection;

// ------------Block属性-------------
@property (nonatomic, copy) void(^progressBlock)(float);
@property (nonatomic, copy) void(^completionBlock)(NSString *);
@property (nonatomic, copy) void(^failBlock)(NSString *);

@end

/**
 NSURLSession下载
 1.跟踪进度
 2.断点续传，问题：这个resumeData丢失，再次下载的时候，无法续传！！
      考虑方案：
         - 将我们的文件保存在固定的位置
         - 再次下载文件前先检查固定的位置是否存在文件
         - 如果有，直接续传！！！如果没有，就下载
             1.首先看服务器上的文件准确大小！！
             2.看本地是否有文件
                 如果大小小于服务器的大小，从本地文件的长度开始下载（续传）
                 如果大小等于服务器的大小，我们认为文件已经下载完毕
                 如果大于服务器的大小，直接干掉（数据肯定出问题了），直接下载
          - 如果没有文件 直接下载
 */

@implementation JYFDownload

/*
 很多三方框架有一个共同的特点
 进度的回调 是在异步线程
        -- 因为进度回调会调用多次 如果在主线程 会影响UI
 完成之后的回调 在主线程 -- 通常不关心线程之间的通讯 一旦完成直接更新UI更方便
 */

#pragma mark -- 这个方法给外界提供的，内部不要写“碎代码”
- (void)downloadWithUrl:(NSURL *)url progress:(void (^)(float))progerss completion:(void (^)(NSString *))complete error:(void (^)(NSString *))error{
    
    // 初始化下载相关的一系列属性
    self.currentUrl = url;
    self.progressBlock = progerss;
    self.completionBlock = complete;
    self.failBlock = error;
    
    // 1.检查服务器上的文件大小！通过url来检查
    [self serverFileInfoWithUrl:url];
    
    // 2.检查本地文件的大小
    if (![self checkLocalFileInfo]) {
        NSLog(@"文件已经下载完毕了");
        return;
    }
    // 3.如果需要从服务器开始下载
    NSLog(@"下载文件");
    [self downloadFile];
    
}

#pragma mark -- 下载文件
// 从 self.currentLength 开始下载文件
- (void)downloadFile{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // 首先发起一个请求
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.currentUrl cachePolicy:1 timeoutInterval:kTimeOut];
        // 设置下载的字节范围 从self.currentLength下载之后的所有字节
        /*
         HTTP Range属性
         Bytes = 0-499 从0-499的 500字节
         Bytes = 500-999 从500到999的二个500字节
         Bytes = 500- 从500开始到以后的所有字节
         Bytes = -500 最后500个字节
         Bytes = 500-999 1000-1999同时指定多个范围
         */
        NSString *rangeStr = [NSString stringWithFormat:@"bytes=%lld-",self.currentFileLength];
        // 设置请求头字段
        [request setValue:rangeStr forHTTPHeaderField:@"Range"];
        // 开始网络链接
        //    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        //        NSLog(@"OK");
        //    }];
        
        // 默认回调和下载的线程是一样的，也就是下载在异步 回调也在异步
        self.downloadConnection = [NSURLConnection connectionWithRequest:request delegate:self];
        [self.downloadConnection start];
        
        // 利用运行循环实现多线程不被回收
        self.downloadRunloop = CFRunLoopGetCurrent();
        CFRunLoopRun();
    });
}

- (void)pause{
    [self.downloadConnection cancel];
}

#pragma mark - 检查本地文件的信息
/**
 检查本地文件信息 判断是否需要下载

 @return YES 需要下载 NO 不需要下载
 */
- (BOOL)checkLocalFileInfo{
    
    // 初始化一个局部变量 接收下载的长度
    long long fileSize = 0;
    
    // 1.检查文件是否存在
    if([[NSFileManager defaultManager] fileExistsAtPath:self.filePath]){
        // 2.获取文件大小
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.filePath error:NULL];
        NSLog(@"文件相关属性%@",attributes);
//        fileSize = [attributes[NSFileSize] longLongValue];
        // 利用分类方法获取文件大小
        fileSize = [attributes fileSize];
    }
    
    // 检查我们的文件信息
    /*
     如果大小小于服务器的大小，从本地文件的长度开始下载（续传）
     如果大小等于服务器的大小，我们认为文件已经下载完毕
     如果大于服务器的大小，直接干掉（数据肯定出问题了），直接下载
     */
    // 大于网络文件总大小 为什么会大于？断点续传出了问题
    if (fileSize > self.expectedLength) {
        // 删除当前文件
        [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:NULL];
        fileSize = 0;
    }
    
    // 处理完大于的情况之后 我们将本地文件的大小赋值给self.currentFileLength
    self.currentFileLength = fileSize;
    
    // 最后判断判断文件是否和服务器的大小一样 如果一样 说明文件已经下载完毕 不用再次下载了
    if (fileSize == self.expectedLength) {
        
        if (self.completionBlock) {
            self.completionBlock(self.filePath);
        }
        // 文件已经下载完毕
        return NO;
    }
    
    return YES;
}

#pragma mark - 获取文件信息
- (void)serverFileInfoWithUrl:(NSURL *)url{
    // 1.请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:1 timeoutInterval:kTimeOut];
    // 使用这个方法 只拿到数据的头信息 并不会返回真实的Data信息
    request.HTTPMethod = @"HEAD";
    // 2.建立网络连接
    NSURLResponse *response = nil;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:NULL];
    // 拿到数据的长度 建议名称 有了名称 我们能创建文件的路径
    // 3.记录服务器的文件信息
       // 3.1 文件长度
    self.expectedLength = response.expectedContentLength;
    // 3.2 建议下载的文件名 将下载的文件保存在tmp 系统会自动回收
    self.filePath = [NSTemporaryDirectory() stringByAppendingString:response.suggestedFilename];
    NSLog(@"文件长度%lld 文件路径%@",self.expectedLength,self.filePath);
}

#pragma mark - NSURLDataDelegate
// 接收到服务器的响应
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    // 打开输出流
    self.fileStream = [[NSOutputStream alloc] initToFileAtPath:self.filePath append:YES];
    [self.fileStream open];
}

// 接收到的数据 用输出流拼接 计算下载进度
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    
    // 追加数据
    [self.fileStream write:data.bytes maxLength:data.length];
    
    // 本地记录一下我们文件的长度
    self.currentFileLength += data.length;
    
    float progress = (float)self.currentFileLength / self.expectedLength;
    
    NSLog(@"%f %@",progress, [NSThread currentThread]);
    
    if (self.progressBlock) {
        self.progressBlock(progress);
    }
}

#pragma mark -- 下载完成
- (void)connectionDidFinishLoading:(NSURLConnection *)connection{
    
    // 下载完成 关闭输出流
    [self.fileStream close];

    // 停止我们的运行循环
    CFRunLoopStop(self.downloadRunloop);
    
    if (self.completionBlock) {
        // 主线程回调
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completionBlock(self.filePath);
        });
    }
}

#pragma mark -- 下载出错
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    
    // 关闭输出流
    [self.fileStream close];
    
    // 停止我们的运行循环
    CFRunLoopStop(self.downloadRunloop);
    if (self.failBlock) {
        self.failBlock(error.localizedDescription);
    }
}

@end
