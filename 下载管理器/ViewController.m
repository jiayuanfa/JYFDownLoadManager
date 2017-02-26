//
//  ViewController.m
//  下载管理器
//
//  Created by mac on 2017/2/22.
//  Copyright © 2017年 mac. All rights reserved.
//

#import "ViewController.h"
#import "JYFDownload.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    JYFDownload * download = [[JYFDownload alloc] init];
    [download downloadWithUrl:[NSURL URLWithString:@"http://7xk0r4.dl1.z0.glb.clouddn.com/MW_SDK_IOS_CURRENT_20160723.zip"] progress:^(float progress) {
        NSLog(@"下载进度%f %@",progress,[NSThread currentThread]);
    } completion:^(NSString *path) {
        NSLog(@"下载完成了%@",path);
    } error:^(NSString *errorMessage) {
        NSLog(@"下载失败了%@",errorMessage);
    }];
    
    }

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
