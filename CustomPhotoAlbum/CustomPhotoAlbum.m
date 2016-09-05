//
//  CustomPhotoAlbum.m
//  CustomPhotoAlbum
//
//  Created by Donew on 16/6/20.
//  Copyright © 2016年 Donew. All rights reserved.
//

#import "CustomPhotoAlbum.h"
#import "ALAssetsLibrary+CustomPhotoAlbum.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface CustomPhotoAlbum () {
    @private
    ALAssetsLibrary * assetsLibrary_;
}

@property (nonatomic, strong) ALAssetsLibrary * assetsLibrary;

@end

@implementation CustomPhotoAlbum

- (void) AddPhoto: (NSString *) path ToAlbum: (NSString *)album
{
//    NSURL* url = [[NSURL alloc] initFileURLWithPath:path];
//    
//    [self.assetsLibrary addAssetURL:url toAlbum:album completion:^(NSURL* url, NSError* error){
//        NSLog(@"photo url: %@", url);
//    }failure:^(NSError* error){
//        NSLog(@"AddPhoto Error: %@", error);
//    }];
    
    UIImage* image = [[UIImage alloc] initWithContentsOfFile:path];
    [self.assetsLibrary saveImage:image toAlbum:album completion:^(NSURL* url, NSError* error){
        NSLog(@"asset url: %@", url);
    } failure:^(NSError* error){
        NSLog(@"AddPhoto: %@", error);
    }];
}

- (ALAssetsLibrary *)assetsLibrary
{
    if (assetsLibrary_) {
        return assetsLibrary_;
    }
    assetsLibrary_ = [[ALAssetsLibrary alloc] init];
    return assetsLibrary_;
}

- (void)takePhoto: (Boolean) chop {
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypeCamera;
    if([UIImagePickerController isSourceTypeAvailable:sourceType]){
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.allowsEditing = chop;
        picker.sourceType = sourceType;
        
        UIViewController* root = [[[UIApplication sharedApplication] keyWindow] rootViewController];
        [root presentViewController:picker animated:YES completion:nil];
    }
    else {
        NSLog(@"Camera Device unavaible..");
        
        if(messageCallback){
            messageCallback(1, NULL);
        }
    }
}

- (void)localPhoto: (Boolean) chop {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    picker.allowsEditing = chop;
    
    UIViewController* root = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    [root presentViewController:picker animated:YES completion:nil];
}

- (void) setCallback:(PhotoCallback)callback {
    messageCallback = callback;
}

#pragma mark - UIImagePickerController Delegate
-(void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [picker dismissViewControllerAnimated:YES completion:nil];
    picker.delegate = nil;
    
    if(messageCallback){
        messageCallback(1, nil);
    }
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    [picker dismissViewControllerAnimated:YES completion:nil];
    picker.delegate = nil;
    
    // Manage the media (photo)
    NSString * mediaType = info[UIImagePickerControllerMediaType];
    // Handle a still image capture
    CFStringRef mediaTypeRef = (__bridge CFStringRef)mediaType;
    if (CFStringCompare(mediaTypeRef,
                        kUTTypeImage,
                        kCFCompareCaseInsensitive) != kCFCompareEqualTo)
    {
        CFRelease(mediaTypeRef);
        return;
    }
    CFRelease(mediaTypeRef);
    
    // Manage tasks in background thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage * editedImage = (UIImage *)info[UIImagePickerControllerEditedImage];
        UIImage * imageToSave = (editedImage ?: (UIImage *)info[UIImagePickerControllerOriginalImage]);
        
        UIImage * finalImageToSave = nil;
        /* Modify image's size before save it to photos album
         *
         *  CGSize sizeToSave = CGSizeMake(imageToSave.size.width, imageToSave.size.height);
         *  UIGraphicsBeginImageContextWithOptions(sizeToSave, NO, 0.f);
         *  [imageToSave drawInRect:CGRectMake(0.f, 0.f, sizeToSave.width, sizeToSave.height)];
         *  finalImageToSave = UIGraphicsGetImageFromCurrentImageContext();
         *  UIGraphicsEndImageContext();
         */
        finalImageToSave = imageToSave;
        
        NSData * data;
        if(UIImagePNGRepresentation(finalImageToSave)){
            data = UIImagePNGRepresentation(finalImageToSave);
        }
        else {
            data = UIImageJPEGRepresentation(finalImageToSave, 1.0f);
        }
        
        NSArray * path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* documentPath = [path objectAtIndex:0];
        
        NSFileManager* manager = [NSFileManager defaultManager];
        
        NSString* imageDocPath = [documentPath stringByAppendingPathComponent:@"ImageStaging"];
        [manager createDirectoryAtPath:imageDocPath withIntermediateDirectories:YES attributes:nil error:nil];
        NSString* imagePath = [imageDocPath stringByAppendingPathComponent:@"tmp"];
        
//        NSString* strToSave = @"file to save!!";
//        data = [strToSave dataUsingEncoding: NSUTF8StringEncoding];
        
        if(![manager fileExistsAtPath:imagePath]){
            if(![manager createFileAtPath:imagePath contents:data attributes:nil]){
                NSLog(@"create file error");
            }
        }
        else{
            NSError* error;
            [data writeToFile:imagePath options:NSDataWritingAtomic error:&error];
            if(error){
                NSLog(@"writeToFile %@", error);
            }
            
//            NSFileHandle* hanlder = [NSFileHandle fileHandleForWritingAtPath:imagePath];
//            [hanlder writeData:data];
//            [hanlder closeFile];
        }
        
        if(messageCallback){
            messageCallback(0, [imagePath UTF8String]);
        }
    });
}

@end

CustomPhotoAlbum* photo_instance = NULL;

CustomPhotoAlbum* Photo_getInstance(){
    if(NULL == photo_instance){
        photo_instance = [[CustomPhotoAlbum alloc] init];
    }
    
    return photo_instance;
}

void setPhotoCallback(PhotoCallback callback){
    [Photo_getInstance() setCallback:callback];
}

void addPhotoToAlbum(char* path, char* album){
    NSString* path2 = [[NSString alloc] initWithUTF8String:path];
    NSString* album2 = [[NSString alloc] initWithUTF8String:album];
    [Photo_getInstance() AddPhoto:path2 ToAlbum:album2];
}

void fetchPhoto(int type, bool chop){
    if(type == 1){
        [Photo_getInstance() takePhoto:chop];
    }
    else if(type == 2){
        [Photo_getInstance() localPhoto:chop];
    }
}
