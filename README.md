>Update: 七牛的SDK已经添加了对 ALAsset 的支持，不再需要使用此库。换了公司后暂时没有用到七牛，我也懒得更新了。。

## 问题描述
七牛 iOS SDK 的上传 API 只有两个
```objc
@interface QNUploadManager : NSObject

- (void)putData:(NSData *)data
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompletionHandler)completionHandler
         option:(QNUploadOption *)option;

- (void)putFile:(NSString *)filePath
            key:(NSString *)key
          token:(NSString *)token
       complete:(QNUpCompletionHandler)completionHandler
         option:(QNUploadOption *)option;

@end
```
其中 putFileXXX 是针对文件上传的，这个方法内部是依赖 NSFileManager 来获取文件信息的
```objc
NSError *error = nil;
NSDictionary *fileAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error];

NSNumber *fileSizeNumber = fileAttr[NSFileSize];
UInt32 fileSize = [fileSizeNumber intValue];
NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:&error];
```
那么问题来了，对于 ALAsset，即系统相册中的图片或视频，获取到的 assetURL 是类似于如下形式的：
```sh
assets-library://asset/asset.MOV?id=A16D4A3B-664E-4A75-90E8-37EA3F04FF2E&ext=MOV
```
NSFileManager 无法处理，因而无法正确获取文件大小等信息，更不用说上传了。

## 解决方案
为便于说明，假定有 ALAsset 实例 asset。
首先，通过 asset.defaultRepresentation.size 能够获取到对应文件的大小。为 QNUploadManager 创建一个 category，如下
```objc
@interface QNUploadManager (ALAssetSupport)

- (void)putALasset:(ALAsset *)asset
               key:(NSString *)key
             token:(NSString *)token
          complete:(QNUpCompletionHandler)completionHandler
            option:(QNUploadOption *)option;


@end
```
具体实现如下
```objc
- (void)putALasset:(ALAsset *)asset
               key:(NSString *)key
             token:(NSString *)token
          complete:(QNUpCompletionHandler)completionHandler
            option:(QNUploadOption *)option
{
    //other code...
  
        
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
    }
}
```

从上面的代码可以看到，QNUploadManager 实际上只是获取文件信息，做一些预处理，而真正的上传过程是由 QNResumeUpload 完成的。QNResumeUpload 的初始化入参很多，需要注意的是 data 和 size，一个简化版的 initXXX 如下
```objc
- (instancetype)initWithData:(NSData *)data
                    withSize:(UInt32)size
                     withOtherParameters:(XXX *)XXX;
```
其中data是文件句柄打开后的二进制数据，size是 数据长度。
你一定已经发现我在 putALassetXXX 里很弱智地在 data 这个入参上传入了 nil，这是有原因的。
打开 QNResumeUpload.m，搜索data后发现，data 本身只在 2 个获取分块数据的方法里涉及到
```objc
- (void)makeBlock:(NSString *)uphost
           offset:(UInt32)offset
        blockSize:(UInt32)blockSize
        chunkSize:(UInt32)chunkSize
         progress:(QNInternalProgressBlock)progressBlock
         complete:(QNCompleteBlock)complete;

- (void)putChunk:(NSString *)uphost
          offset:(UInt32)offset
            size:(UInt32)size
         context:(NSString *)context
        progress:(QNInternalProgressBlock)progressBlock
        complete:(QNCompleteBlock)complete; 
}
```
只要 override 它们，让它们支持 ALAsset 即可。
首先为 QNResumeUpload 添加 property
```objc
@class ALAsset;

@interface QNResumeUpload (ALAssetSupport)
@property (nonatomic, strong) ALAsset *asset;

@end
```
在 putALasset 方法里会为此属性赋值。
接着写一个获取指定 offset 和 length 的 data 的方法
```objc
- (NSData *)dataFromALAssetAtOffset:(NSInteger)offset size:(NSInteger)size
{
    ALAssetRepresentation *rep = [self.asset defaultRepresentation];
    Byte *buffer = (Byte *)malloc(size);
    NSUInteger buffered = [rep getBytes:buffer fromOffset:offset length:size error:nil];
    
    return [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
}
```
最后在 makeBlock 和 putChunk 里调用此方法即可，以 makeBlock 为例
```objc
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
```
