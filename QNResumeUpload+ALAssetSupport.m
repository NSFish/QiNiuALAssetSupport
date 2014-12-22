//
//  QNResumeUpload+ALAssetSupport.m
//  QiChengNew
//
//  Created by 乐星宇 on 14/11/14.
//  Copyright (c) 2014年 奇橙百优. All rights reserved.
//

#import "QNResumeUpload+ALAssetSupport.h"
#import "QNHttpManager.h"
#import "QNCrc32.h"
#import "QNConfig.h"

#import <AssetsLibrary/AssetsLibrary.h>

#import <objc/message.h>
#import <objc/runtime.h>

static char kAssetKey;

@implementation QNResumeUpload (ALAssetSupport)
@dynamic asset;

- (void)makeBlock:(NSString *)uphost
           offset:(UInt32)offset
        blockSize:(UInt32)blockSize
        chunkSize:(UInt32)chunkSize
         progress:(QNInternalProgressBlock)progressBlock
         complete:(QNCompleteBlock)complete
{
    NSData *data = [self dataFromALAssetAtOffset:offset size:chunkSize];//[self.data subdataWithRange:NSMakeRange(offset, (unsigned int)chunkSize)];
    NSString *url = [[NSString alloc] initWithFormat:@"http://%@/mkblk/%u", uphost, (unsigned int)blockSize];
    
    UInt32 crc = [QNCrc32 data:data];
    [self setChunkCrcValue:crc];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    SEL selector = @selector(post:withData:withCompleteBlock:withProgressBlock:);
#pragma clang diagnostic pop
    void (*typed_msgSend)(id, SEL, NSString *, NSData *, QNCompleteBlock, QNInternalProgressBlock) = (void *)objc_msgSend;
    typed_msgSend(self, selector, url, data, complete, progressBlock);
}

- (void)putChunk:(NSString *)uphost
          offset:(UInt32)offset
            size:(UInt32)size
         context:(NSString *)context
        progress:(QNInternalProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete {
    NSData *data = [self dataFromALAssetAtOffset:offset size:size];//[self.data subdataWithRange:NSMakeRange(offset, (unsigned int)size)];
    UInt32 chunkOffset = offset % kQNBlockSize;
    NSString *url = [[NSString alloc] initWithFormat:@"http://%@/bput/%@/%u", uphost, context, (unsigned int)chunkOffset];
    
    UInt32 crc = [QNCrc32 data:data];
    [self setChunkCrcValue:crc];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    SEL selector = @selector(post:withData:withCompleteBlock:withProgressBlock:);
#pragma clang diagnostic pop
    void (*typed_msgSend)(id, SEL, NSString *, NSData *, QNCompleteBlock, QNInternalProgressBlock) = (void *)objc_msgSend;
    typed_msgSend(self, selector, url, data, complete, progressBlock);
}

#pragma mark 读取ALAsset中的data
- (NSData *)dataFromALAssetAtOffset:(NSInteger)offset size:(NSInteger)size
{
    ALAssetRepresentation *rep = [self.asset defaultRepresentation];
    Byte *buffer = (Byte *)malloc(size);
    NSUInteger buffered = [rep getBytes:buffer fromOffset:offset length:size error:nil];
    
    return [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
}

#pragma mark CRC
- (void)setChunkCrcValue:(UInt32)crc
{
    [self setValue:@(crc) forKey:@"chunkCrc"];
}

#pragma mark Asset setter and getter
- (void)setAsset:(ALAsset *)asset
{
    objc_setAssociatedObject(self, &kAssetKey, asset, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (ALAsset *)asset
{
    return objc_getAssociatedObject(self, &kAssetKey);
}


@end
