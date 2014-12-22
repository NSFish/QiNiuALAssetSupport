//
//  QNUploadManager+ALAssetSupport.m
//  QiChengNew
//
//  Created by 乐星宇 on 14/11/14.
//  Copyright (c) 2014年 奇橙百优. All rights reserved.
//

#import "QNUploadManager+ALAssetSupport.h"
#import "QNAsyncRun.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "QNResponseInfo.h"
#import "QNResumeUpload.h"
#import "QNResumeUpload+ALAssetSupport.h"


@implementation QNUploadManager (ALAssetSupport)

+ (BOOL)checkAndNotifyError:(NSString *)key
                      token:(NSString *)token
                       data:(NSData *)data
                      asset:(ALAsset *)asset
                   complete:(QNUpCompletionHandler)completionHandler
{
    NSString *desc = nil;
    if (completionHandler == nil)
    {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"no completionHandler" userInfo:nil];
        return YES;
    }
    
    if (data == nil && asset == nil)
    {
        desc = @"no input data";
    }
    else if (token == nil || [token isEqualToString:@""]) {
        desc = @"no token";
    }
    
    if (desc != nil) {
        QNAsyncRun ( ^{
            completionHandler([QNResponseInfo responseInfoWithInvalidArgument:desc], key, nil);
        });
        return YES;
    }
    
    return NO;
}

- (void)putALasset:(ALAsset *)asset
               key:(NSString *)key
             token:(NSString *)token
          complete:(QNUpCompletionHandler)completionHandler
            option:(QNUploadOption *)option
{
    if ([QNUploadManager checkAndNotifyError:key token:token data:nil asset:asset complete:completionHandler])
    {
        return;
    }
    
    @autoreleasepool {
        QNUpCompletionHandler complete = ^(QNResponseInfo *info, NSString *key, NSDictionary *resp)
        {
            completionHandler(info, key, resp);
        };
        
        //无法获取最后修改时间，用创建时间先凑合一下
        NSDate *modifyTime = [asset valueForProperty:ALAssetPropertyDate];//fileAttr[NSFileModificationDate];
        NSString *recorderKey = key;
        QNRecorderKeyGenerator recorderKeyGen = [self getRecorderKeyGeneratorProperty];
        id<QNRecorderDelegate> recorder = [self getRecorderProperty];
        if (recorder != nil && recorderKeyGen != nil)
        {
            //TODO:断点续传是基于文件来做的，因此这里保存了文件的路径，这里改成asset的URL，意味着恢复时也需要做对应的调整
            recorderKey = recorderKeyGen(key, [asset.defaultRepresentation.url absoluteString]);
        }
        
        QNResumeUpload *up = [[QNResumeUpload alloc]
                              initWithData:nil
                              withSize:(UInt32)asset.defaultRepresentation.size
                              withKey:key
                              withToken:token
                              withCompletionHandler:complete
                              withOption:option
                              withModifyTime:modifyTime
                              withRecorder:recorder
                              withRecorderKey:recorderKey
                              withHttpManager:[self getHttpManagerProperty]];
        up.asset = asset;
        
        QNAsyncRun ( ^{
            [up run];
        });
    }
}

#pragma mark Private property getter
- (id<QNRecorderDelegate>)getRecorderProperty
{
    return [self valueForKey:@"recorder"];
}

- (QNRecorderKeyGenerator)getRecorderKeyGeneratorProperty
{
    return [self valueForKey:@"recorderKeyGen"];
}

- (QNHttpManager *)getHttpManagerProperty
{
    return [self valueForKey:@"httpManager"];
}


@end
