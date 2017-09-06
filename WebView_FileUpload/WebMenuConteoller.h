//
//  WebMenuConteoller.h
//  WebView_FileUpload
//
//  Created by YLCHUN on 2017/9/5.
//  Copyright © 2017年 ylchun. All rights reserved.
//
//  注意 自定义菜单实现采用了几个私有属性，上线风险未知！请谨慎使用
//  采用WebMenu_enabled来控制使用自定义菜单还是系统菜单
//

#import <UIKit/UIKit.h>
#define WebMenu_enabled 0 //开关标志

@interface WebMenuConteoller : UIViewController


@property (nonatomic, strong) UIDocumentMenuViewController *menuViewController;
@end
