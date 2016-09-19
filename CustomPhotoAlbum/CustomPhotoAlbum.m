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
            messageCallback(1, NULL, 0, 0);
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
        messageCallback(1, nil, 0, 0);
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
    
    NSURL* imgURL = info[UIImagePickerControllerReferenceURL];
    NSLog(@"image url: %@", imgURL);
    
    CGFloat size_limit = 256;
    
    if(imgURL != NULL){
        [self.assetsLibrary assetForURL:imgURL resultBlock:^(ALAsset *asset){
            ALAssetRepresentation *rep = [asset defaultRepresentation];
            CGSize dimension = [rep dimensions];
            
            Byte *buffer = (Byte*)malloc(rep.size);
            NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:nil];
            NSData* data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
            
            CGFloat wf = dimension.width / size_limit;
            CGFloat hf = dimension.height / size_limit;
            
            CGFloat factor = 1.0f;
            if(wf > hf){
                factor = wf;
            }
            else{
                factor = hf;
            }
            
            if(factor <= 1){
                factor = 1.0f;
            }
            
            UIImage* image = [[UIImage alloc] initWithData:data scale:factor];
            data = UIImagePNGRepresentation(image);
            
            NSArray * path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString* documentPath = [path objectAtIndex:0];
            
            NSFileManager* manager = [NSFileManager defaultManager];
            
            NSString* imageDocPath = [documentPath stringByAppendingPathComponent:@"ImageStaging"];
            [manager createDirectoryAtPath:imageDocPath withIntermediateDirectories:YES attributes:nil error:nil];
            NSString* imagePath = [imageDocPath stringByAppendingPathComponent:@"tmp"];
            
            //        NSString* strToSave = @"file to save!!";
            //        data = [strToSave dataUsingEncoding: NSUTF8StringEncoding];
            
            NSLog(@"data length: %d", data.length);
            
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
                CGFloat width = image.size.width;
                CGFloat height = image.size.height;
                NSLog(@"width: %f, height: %f", width, height);
                messageCallback(0, [imagePath UTF8String], 0, 0);
            }
            
            
        } failureBlock:^(NSError *err) {
            NSLog(@"Error: %@", [err localizedDescription]);
        }];
    }
    else {
        // Manage tasks in background thread
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImage * editedImage = (UIImage *)info[UIImagePickerControllerEditedImage];
            UIImage * imageToSave = (editedImage ?: (UIImage *)info[UIImagePickerControllerOriginalImage]);
            
            UIImage * finalImageToSave = nil;
            
            /* Modify image's size before save it to photos album
             */
            
            finalImageToSave = [self ResizeImage:imageToSave Width:size_limit Height:size_limit];
            
            //finalImageToSave = imageToSave;
            
            CGFloat width = finalImageToSave.size.width;
            CGFloat height = finalImageToSave.size.height;
            NSLog(@"width: %f height: %f", width, height);
            
            NSData * data;
            if(UIImagePNGRepresentation(finalImageToSave)){
                data = UIImagePNGRepresentation(finalImageToSave);
            }
            else {
                data = UIImageJPEGRepresentation(finalImageToSave, 1.0f);
            }
            
            //data = UIImageJPEGRepresentation(finalImageToSave, 0.0f);
            
            NSArray * path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString* documentPath = [path objectAtIndex:0];
            
            NSFileManager* manager = [NSFileManager defaultManager];
            
            NSString* imageDocPath = [documentPath stringByAppendingPathComponent:@"ImageStaging"];
            [manager createDirectoryAtPath:imageDocPath withIntermediateDirectories:YES attributes:nil error:nil];
            NSString* imagePath = [imageDocPath stringByAppendingPathComponent:@"tmp"];
            
            //        NSString* strToSave = @"file to save!!";
            //        data = [strToSave dataUsingEncoding: NSUTF8StringEncoding];
            
            NSLog(@"data length: %d", data.length);
            
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
                messageCallback(0, [imagePath UTF8String], 0, 0);
            }
        });
    }
}

-(UIImage *)ResizeImage:(UIImage *)imageToSave Width:(CGFloat)width Height:(CGFloat)height {
    CGFloat wf = imageToSave.size.width / width;
    CGFloat hf = imageToSave.size.height / height;
    
    CGFloat factor = 1.0f;
    if(wf > hf){
        factor = wf;
    }
    else{
        factor = hf;
    }
    
    if(factor <= 1){
        factor = 1.0f;
    }
    
    CGSize sizeToSave = CGSizeMake(imageToSave.size.width / factor, imageToSave.size.height / factor);
    UIGraphicsBeginImageContextWithOptions(sizeToSave, NO, 0.f);
    [imageToSave drawInRect:CGRectMake(0.f, 0.f, sizeToSave.width, sizeToSave.height)];
    UIImage* finalImageToSave = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return finalImageToSave;
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
