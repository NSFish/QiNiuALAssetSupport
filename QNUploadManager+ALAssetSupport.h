//
//  QNUploadManager+ALAssetSupport.h
//  QiChengNew
//
//  Created by 乐星宇 on 14/11/14.
//  Copyright (c) 2014年 奇橙百优. All rights reserved.
//

#import "QNUploadManager.h"

@class ALAsset;

@interface QNUploadManager (ALAssetSupport)

- (void)putALasset:(ALAsset *)asset
               key:(NSString *)key
             token:(NSString *)token
          complete:(QNUpCompletionHandler)completionHandler
            option:(QNUploadOption *)option;


@end
