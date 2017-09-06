//
//  WebMenuConteoller.m
//  WebView_FileUpload
//
//  Created by YLCHUN on 2017/9/5.
//  Copyright © 2017年 ylchun. All rights reserved.
//
//  简书介绍：http://www.jianshu.com/p/916208d19d61

#import "WebMenuConteoller.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import <objc/runtime.h>

@interface WebMenuConteoller ()
{
    BOOL _usingCamera;
    id _allowMultipleFiles;
}
@property (nonatomic, strong) id fileUploadPanel;

@property(nonatomic,copy) void(^cameraHandler)();
@property(nonatomic, strong) WebMenuConteoller*SELF;//访问相册时候强引用自身，选择完成或取消移除
@end

@implementation WebMenuConteoller

-(instancetype)init {
    self = [super init];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cancelAction)];
    [self.view addGestureRecognizer:tap];
}

NSArray* cameraTitles() {
    static NSArray *kTitles;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kTitles = @[@"拍照或录像", @"Take Photo or Video",
                    @"拍照", @"Take Photo",
                    @"录像", @"Take Video"];//国际化
    });
    return kTitles;
}

-(void)setMenuViewController:(UIDocumentMenuViewController *)menuViewController {
    _menuViewController = menuViewController;
    self.fileUploadPanel = menuViewController.delegate;
#if WebMenu_enabled
    NSArray *arr = [menuViewController valueForKeyPath:@"_auxiliaryOptions"];
    for (id obj in arr) {
        NSString * title = [obj valueForKeyPath:@"_title"];
        if ([cameraTitles() containsObject:title]) {
            self.cameraHandler = [obj valueForKeyPath:@"_handler"];
        }
    }
#endif
}

-(void)setFileUploadPanel:(id)fileUploadPanel {
    _fileUploadPanel = fileUploadPanel;
    #if WebMenu_enabled
    if (fileUploadPanel) {
        if ([fileUploadPanel isKindOfClass:NSClassFromString(@"WKFileUploadPanel")]) {
            _allowMultipleFiles = [fileUploadPanel valueForKeyPath:@"allowMultipleFiles"];
        }else{
            _allowMultipleFiles = @(NO);
        }
    }
#endif
}

-(UIImagePickerController *)imagePickerWithSourceType:(UIImagePickerControllerSourceType)sourceType {
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = (id <UINavigationControllerDelegate, UIImagePickerControllerDelegate>) self;
    imagePicker.modalPresentationStyle = UIModalPresentationFullScreen;
    imagePicker.allowsEditing = NO;
    imagePicker.sourceType = sourceType;
    imagePicker.mediaTypes = [self mediaTypesForPickerSourceType:sourceType];
#if WebMenu_enabled
    [imagePicker setValue:_allowMultipleFiles forKey:@"allowsMultipleSelection"];
#endif
    return imagePicker;
}


- (NSArray *)mediaTypesForPickerSourceType:(UIImagePickerControllerSourceType)sourceType {
    // The HTML5 spec mentions the literal "image/*" and "video/*" strings.
    // We support these and go a step further, if the MIME type starts with
    // "image/" or "video/" we adjust the picker's image or video filters.
    // So, "image/jpeg" would make the picker display all images types.
#if WebMenu_enabled
    id value = [self.fileUploadPanel valueForKeyPath:@"mimeTypes"];
    NSArray* mimeTypes ;
    if ([value isKindOfClass:[NSArray class]]) {
        mimeTypes = value;
    }else{
        [value getValue:&mimeTypes];
    }
    NSMutableSet *mediaTypes = [NSMutableSet set];
    for (NSString *mimeType in mimeTypes) {
        if ([mimeType hasPrefix:@"image/"]) {
            [mediaTypes addObject:(NSString *)kUTTypeImage];
        }else if ([mimeType hasPrefix:@"video/"]) {
            [mediaTypes addObject:(NSString *)kUTTypeMovie];
        }
    }
    
    if ([mediaTypes count])
        return [mediaTypes allObjects];
#endif
    // Fallback to every supported media type if there is no filter.
    return [UIImagePickerController availableMediaTypesForSourceType:sourceType];
}

- (IBAction)cameraAction {
    void(^cameraHandler)() = self.cameraHandler;
    if (cameraHandler) {//调用来的相机函数，自己调用会出现野指针异常，相册不会
        [self dismissViewControllerAnimated:YES completion:^{
            cameraHandler();
        }];
    }else{
        [self albumAction];
    }
}

- (IBAction)albumAction {
    UIImagePickerController *imagePicker = [self imagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    UIViewController *vc = self.presentingViewController;
    self.SELF = self;
    [self dismissViewControllerAnimated:YES completion:^{
        [vc presentViewController:imagePicker animated:YES completion:^{
            
        }];
    }];
}

- (IBAction)cancelAction {
    [self imagePickerControllerDidCancel:nil];
}

- (void)imagePickerController:(UIImagePickerController *)imagePicker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    if ([_allowMultipleFiles boolValue]) {
        return;
    }
    [self imagePickerController:imagePicker didFinishPickingMultipleMediaWithInfo:@[info]];
}

- (void)imagePickerController:(UIImagePickerController *)imagePicker didFinishPickingMultipleMediaWithInfo:(NSArray *)infos {
    if (self.SELF) {
        self.SELF = nil;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.fileUploadPanel performSelector:_cmd withObject:imagePicker withObject:infos];
#pragma clang diagnostic pop
}

-(void)imagePickerControllerDidCancel:(UIImagePickerController *)imagePicker {
    if (self.SELF) {
        self.SELF = nil;
    }
    [self.fileUploadPanel performSelector:@selector(imagePickerControllerDidCancel:) withObject:nil];
}

@end


@interface UIViewController ()
@property (nonatomic) BOOL FileUploadPanelFlag;
@end
@implementation UIViewController (Dismis_FileUploadPanel)

-(BOOL)FileUploadPanelFlag {
    return [objc_getAssociatedObject(self, @selector(FileUploadPanelFlag)) boolValue];
}
-(void)setFileUploadPanelFlag:(BOOL)FileUploadPanelFlag {
    objc_setAssociatedObject(self, @selector(FileUploadPanelFlag), @(FileUploadPanelFlag), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        SEL originalSelector = @selector(dismissViewControllerAnimated:completion:);
        SEL swizzledSelector = @selector(dfup_dismissViewControllerAnimated:completion:);
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        BOOL success = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        if (success) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
        
        originalSelector = @selector(presentViewController:animated:completion:);
        swizzledSelector = @selector(dfup_presentViewController:animated:completion:);
        originalMethod = class_getInstanceMethod(class, originalSelector);
        swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        success = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        if (success) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}


-(void)dfup_dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    static BOOL dismisFromFileUploadPanel = NO;
    if (!dismisFromFileUploadPanel) {
        [self dfup_dismissViewControllerAnimated:flag completion:^{
            if (completion) {
                if (self.FileUploadPanelFlag) {
                    dismisFromFileUploadPanel = YES;
                    completion();
                    dismisFromFileUploadPanel = NO;
                }else{
                    completion();
                }
            }
        }];
    }
}

-(void)dfup_presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if ([viewControllerToPresent isKindOfClass:[UIDocumentMenuViewController class]]) {
        UIDocumentMenuViewController *dvc = (UIDocumentMenuViewController*)viewControllerToPresent;
        if ([dvc.delegate isKindOfClass:NSClassFromString(@"WKFileUploadPanel")] || [dvc.delegate isKindOfClass:NSClassFromString(@"UIWebFileUploadPanel")]) {
            self.FileUploadPanelFlag = YES;
            dvc.FileUploadPanelFlag = YES;
#if WebMenu_enabled
            WebMenuConteoller *mvc = [[WebMenuConteoller alloc] init];
            mvc.menuViewController = dvc;
            mvc.FileUploadPanelFlag = YES;
            [self dfup_presentViewController:mvc animated:flag completion:completion];
            return;
#endif
        }
    }
    [self dfup_presentViewController:viewControllerToPresent animated:flag completion:completion];
}

@end
