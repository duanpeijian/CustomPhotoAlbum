//
//  CustomPhotoAlbum.h
//  CustomPhotoAlbum
//
//  Created by Donew on 16/6/20.
//  Copyright © 2016年 Donew. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void (*PhotoCallback)(int status, const char* filePath);

@interface CustomPhotoAlbum : NSObject<UIImagePickerControllerDelegate, UINavigationControllerDelegate>{
    PhotoCallback messageCallback;
}

@end
