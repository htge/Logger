//
//  Logger.m
//  DrClient_mac
//
//  Created by haitong on 2019/4/30.
//

#import "Logger.h"
#import "NSData+AES.h"
#import "NSData+Zlib.h"

#define MAX_FILE_SIZE       16777216

@interface Logger()

@property (assign, nonatomic) NSString *logHeader;
@property (strong, nonatomic) NSData *iv;
@property (assign, nonatomic) z_stream zStream;
@property (assign, nonatomic) BOOL useZip;
@property (assign, nonatomic) NSInteger cacheSize;
@property (assign, nonatomic) LoggerLevel level;
@property (assign, nonatomic) LoggerLevel fileLevel;
@property (strong, nonatomic) NSFileHandle *fileHandle;
@property (strong, nonatomic) NSString *fileSecretKey;
@property (assign, nonatomic) CCCryptorRef fileCryptor;
@property (strong, nonatomic) NSMutableData *fileCache;
@property (strong, nonatomic) dispatch_queue_t fileQueue;

@property (weak, nonatomic) id <LoggerDelegate>delegate;

@end

@implementation Logger

+ (Logger *)getInstance {
    static dispatch_once_t onceToken;
    static Logger *logger;
    dispatch_once(&onceToken, ^{
        logger = [[Logger alloc] init];
        logger.fileCache = [NSMutableData data];
        logger.level = LoggerLevelError;
        char *queueName = "";
#if DEBUG
        queueName = "fileQueue";
#endif
        logger.fileQueue = dispatch_queue_create(queueName, nil);
        memset(&logger->_zStream, 0, sizeof(z_stream));
    });
    return logger;
}

#pragma mark - properties
+ (void)setMaxCacheSize:(NSInteger)cacheSize {
    NSAssert(cacheSize > 0 && cacheSize < 131072, @"Cache size out of range");
    [self getInstance].cacheSize = cacheSize;
}

+ (void)setLogLevel:(LoggerLevel)level {
    [self getInstance].level = level;
}

#pragma mark -
+ (void)initFilePath:(NSString *)path config:(LoggerConfig *)config {
    NSAssert(path != nil, @"path could not be null");
    NSAssert(config.header != nil, @"header could not be null");
    NSAssert(config.cacheSize > 0 && config.cacheSize < 131072, @"Cache size out of range");
    
    int ret;
    BOOL isDirectory;

    //文件太大，就要重命名为.old。除非有人打开这个app长时间不关的，那就有可能累计特别大的日志
    if ([self fileSizeTooLarge:path]) {
        [self moveToOldFile:path];
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    } else if (isDirectory) {
        NSString *message = [NSString stringWithFormat:@"Is directory: \"%@\"", path];
        @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:message userInfo:nil];
    }
    
    NSFileHandle *handle = [NSFileHandle fileHandleForUpdatingAtPath:path];
    if (!handle) {
        NSString *message = [NSString stringWithFormat:@"Could not write to file: \"%@\"", path];
        @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:message userInfo:nil];
    }
    
    //读取之前的文件，读不出就有可能是写了一半强退了
    NSData *data = [handle readDataToEndOfFile];
    NSArray *arr = [self decryptFromData:data config:config];
    if (data.length > 0 && arr.count == 0) {
        NSLog(@"Could not read the file, recreating...");
        [handle closeFile];
        NSString *oldFile = [path stringByAppendingString:@".old"];
        NSError *error = nil;
        
        //移动文件，重新创建一个文件
        if ([[NSFileManager defaultManager] fileExistsAtPath:oldFile]) {
            [[NSFileManager defaultManager] removeItemAtPath:oldFile error:&error];
            if (error) {
                NSString *message = @"delete file error.";
                @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:message userInfo:nil];
            }
        }
        
        [[NSFileManager defaultManager] moveItemAtPath:path toPath:oldFile error:&error];
        if (error) {
            NSString *message = @"move to file error, override.";
            @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:message userInfo:nil];
        } else {
            [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        }
    
        handle = [NSFileHandle fileHandleForUpdatingAtPath:path];
        if (!handle) {
            NSString *message = [NSString stringWithFormat:@"Could not write to file: \"%@\"", path];
            @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:message userInfo:nil];
        }
    }

    //设置全局配置，当调用日志函数时会用得到
    Logger *logger = [self getInstance];
    NSAssert(logger != nil, @"logger could not be null");
    logger.fileLevel = config.logLevel;
    logger.logHeader = config.header;
    logger.fileHandle = handle;
    logger.fileSecretKey = config.password;
    logger.cacheSize = config.cacheSize;
    logger.iv = config.iv;
    
    [handle seekToEndOfFile];
    [handle writeData:[[self getInstance].logHeader dataUsingEncoding:NSUTF8StringEncoding]];

    if (config.isGzip) {
        ret = deflateInit2(&logger->_zStream, Z_DEFAULT_COMPRESSION, Z_DEFLATED,
                           MAX_WBITS + GZIP_ENCODING, 8, Z_DEFAULT_STRATEGY);
        if (ret != Z_OK) {
            NSString *message = @"Could not init zlib";
            @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:message userInfo:nil];
        }
        logger.useZip = YES;
    }
    
    if (config.password.length > 0) {
        CCCryptorRef cryptor;
        char keyPtr[kCCKeySizeAES256 + 1] = {0};
        [config.password getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
        
        //建立句柄，用来动态追加，最后调用endLogFile销毁
        if (kCCSuccess == CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding, keyPtr, kCCKeySizeAES256,
                                          config.iv.bytes, &cryptor)) {
            [self getInstance].fileCryptor = cryptor;
        }
    }
}

+ (BOOL)fileSizeTooLarge:(NSString *)path {
    NSError *attributesError;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&attributesError];
    NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
    return [fileSizeNumber longLongValue] > MAX_FILE_SIZE;
}

+ (void)moveToOldFile:(NSString *)path {
    NSError *error;
    NSString *toPath = [path stringByAppendingString:@".old"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:toPath]) {
        if (![[NSFileManager defaultManager] removeItemAtPath:toPath error:&error]) {
            NSString *message = [NSString stringWithFormat:@"Could not delete the file: \"%@\"", toPath];
            @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:message userInfo:nil];
        }
    }
    
    if (![[NSFileManager defaultManager] moveItemAtPath:path toPath:toPath error:&error]) {
        [Logger error:@"move item error: %@->%@", path, toPath];
    }
}

+ (void)initWithDelegate:(id<LoggerDelegate>)delegate {
    //设置全局配置，当调用日志函数时会用得到
    Logger *logger = [self getInstance];
    NSAssert(logger != nil, @"logger could not be null");
    logger.delegate = delegate;
}

+ (void)outputToFile:(NSMutableString *)string {
    //最后要加换行符
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS "];
    NSString *dateStr = [formatter stringFromDate:[NSDate date]];
    [string insertString:dateStr atIndex:0];
    [string appendString:@"\n"];
    NSData *data = nil;
    Logger *logger = [self getInstance];
    data = [string dataUsingEncoding:NSUTF8StringEncoding];
    
    //用队列写
    void (^fileHandler)(void) = ^{
        NSMutableData *fileCache = [self getInstance].fileCache;
        if (data != nil) {
            [fileCache appendData:data];
            if (fileCache.length > logger.cacheSize) {
                //先压缩后加密
                NSData *writeData = fileCache;
                if (logger.useZip) {
                    writeData = [writeData deflateWithStream:&logger->_zStream];
                }
                if (logger.fileSecretKey.length > 0) {
                    writeData = [writeData updateEncrypt256:logger.fileCryptor password:logger.fileSecretKey iv:logger.iv];
                }
                [[self getInstance].fileHandle writeData:writeData];
                
                //每写一次以后就清缓存
                [self getInstance].fileCache = [NSMutableData data];
            }
        }
    };
    
    dispatch_async([self getInstance].fileQueue, fileHandler);
}

#pragma mark -
+ (void)info:(NSString *)format, ... {
    NSAssert(format != nil, @"format could not be null");
    
    BOOL isOutputToConsole = [self getInstance].level >= LoggerLevelInfo;
    BOOL isOutputToFile = [self getInstance].fileLevel >= LoggerLevelInfo && [self getInstance].fileHandle != nil;
    
    id<LoggerDelegate> delegate = [self getInstance].delegate;
    if (isOutputToConsole || isOutputToFile || delegate) {
        va_list args;
        va_start(args, format);
        NSString *noPrefixStr = [[NSString alloc] initWithFormat:format arguments:args];
        NSMutableString *string = [NSMutableString stringWithString:@"INFO: "];
        [string appendString:noPrefixStr];
        va_end(args);
        
        if (isOutputToConsole) {
            NSLog(@"%@", string);
        }
        if (isOutputToFile) {
            [self outputToFile:string];
        }
        if ([delegate respondsToSelector:@selector(logXPCInfo:)]) {
            LoggerXPCInfo *xpcInfo = [[LoggerXPCInfo alloc] init];
            xpcInfo.destLog = noPrefixStr;
            xpcInfo.level = LoggerLevelInfo;
            [delegate logXPCInfo:xpcInfo];
        }
    }
}

+ (void)debug:(NSString *)format, ... {
    NSAssert(format != nil, @"format could not be null");
    
    BOOL isOutputToConsole = [self getInstance].level >= LoggerLevelDebug;
    BOOL isOutputToFile = [self getInstance].fileLevel >= LoggerLevelDebug && [self getInstance].fileHandle != nil;
    
    id<LoggerDelegate> delegate = [self getInstance].delegate;
    if (isOutputToConsole || isOutputToFile || delegate) {
        va_list args;
        va_start(args, format);
        NSString *noPrefixStr = [[NSString alloc] initWithFormat:format arguments:args];
        NSMutableString *string = [NSMutableString stringWithString:@"DEBUG: "];
        [string appendString:noPrefixStr];
        va_end(args);
        
        if (isOutputToConsole) {
            NSLog(@"%@", string);
        }
        if (isOutputToFile) {
            [self outputToFile:string];
        }
        if ([delegate respondsToSelector:@selector(logXPCInfo:)]) {
            LoggerXPCInfo *xpcInfo = [[LoggerXPCInfo alloc] init];
            xpcInfo.destLog = noPrefixStr;
            xpcInfo.level = LoggerLevelDebug;
            [delegate logXPCInfo:xpcInfo];
        }
    }
}

+ (void)warn:(NSString *)format, ... {
    NSAssert(format != nil, @"format could not be null");
    
    BOOL isOutputToConsole = [self getInstance].level >= LoggerLevelWarn;
    BOOL isOutputToFile = [self getInstance].fileLevel >= LoggerLevelWarn && [self getInstance].fileHandle != nil;
    
    id<LoggerDelegate> delegate = [self getInstance].delegate;
    if (isOutputToConsole || isOutputToFile || delegate) {
        va_list args;
        va_start(args, format);
        NSString *noPrefixStr = [[NSString alloc] initWithFormat:format arguments:args];
        NSMutableString *string = [NSMutableString stringWithString:@"WARN: "];
        [string appendString:noPrefixStr];
        va_end(args);
        
        if (isOutputToConsole) {
            NSLog(@"%@", string);
        }
        if (isOutputToFile) {
            [self outputToFile:string];
        }
        if ([delegate respondsToSelector:@selector(logXPCInfo:)]) {
            LoggerXPCInfo *xpcInfo = [[LoggerXPCInfo alloc] init];
            xpcInfo.destLog = noPrefixStr;
            xpcInfo.level = LoggerLevelWarn;
            [delegate logXPCInfo:xpcInfo];
        }
    }
}

+ (void)error:(NSString *)format, ... {
    NSAssert(format != nil, @"format could not be null");
    
    BOOL isOutputToConsole = [self getInstance].level >= LoggerLevelError;
    BOOL isOutputToFile = [self getInstance].fileLevel >= LoggerLevelError && [self getInstance].fileHandle != nil;
    
    id<LoggerDelegate> delegate = [self getInstance].delegate;
    if (isOutputToConsole || isOutputToFile || delegate) {
        va_list args;
        va_start(args, format);
        NSString *noPrefixStr = [[NSString alloc] initWithFormat:format arguments:args];
        NSMutableString *string = [NSMutableString stringWithString:@"ERROR: "];
        [string appendString:noPrefixStr];
        va_end(args);
        
        if (isOutputToConsole) {
            NSLog(@"%@", string);
        }
        if (isOutputToFile) {
            [self outputToFile:string];
        }
        if ([delegate respondsToSelector:@selector(logXPCInfo:)]) {
            LoggerXPCInfo *xpcInfo = [[LoggerXPCInfo alloc] init];
            xpcInfo.destLog = noPrefixStr;
            xpcInfo.level = LoggerLevelError;
            [delegate logXPCInfo:xpcInfo];
        }
    }
}

#pragma mark -
+ (void)endLogFile {
    Logger *logger = [self getInstance];
    NSFileHandle *handle = [self getInstance].fileHandle;
    if (handle) {
        void (^fileHandler)(void) = ^{
            NSMutableData *fileCache = [self getInstance].fileCache;
            
            //先压缩后加密
            NSData *writeData = fileCache;
            if (logger.useZip) {
                writeData = [writeData closeStream:&logger->_zStream];
                logger.useZip = NO;
            }
            CCCryptorRef cryptor = [self getInstance].fileCryptor;
            if (cryptor) {
                NSMutableData *mData = [[writeData updateEncrypt256:logger.fileCryptor password:logger.fileSecretKey iv:logger.iv] mutableCopy];
                char buffer[kCCBlockSizeAES128] = {0};
                size_t dataOutMoved = 0;
                
                if (mData && kCCSuccess == CCCryptorFinal(cryptor, buffer, sizeof(buffer),
                                                          &dataOutMoved)) {
                    NSData *data = [NSData dataWithBytes:buffer length:dataOutMoved];
                    [mData appendData:data];
                    writeData = mData;
                }
                CCCryptorRelease(cryptor);
                [self getInstance].fileCryptor = nil;
            }
            
            [handle writeData:writeData];
            [handle closeFile];
            [self getInstance].fileHandle = nil;
            
            //最后写肯定得清缓存
            [self getInstance].fileCache = [NSMutableData data];
        };
        dispatch_sync([self getInstance].fileQueue, fileHandler);
    }
}

#pragma mark -
+ (NSString *)decryptData:(NSData *)data password:(NSString *)password iv:(NSData *)iv useZip:(BOOL)useZip {
    NSString *str = @"";
    if (data.length > 0) {
        NSData *decData = data;
        if (password.length > 0) {
            decData = [decData decrypt256:password iv:iv];
            if (decData == nil) {
                @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:@"decryptData: decrypt failed" userInfo:nil];
            }
        }
        if (useZip) {
            decData = [decData inflate];
            if (decData == nil) {
                @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:@"decryptData: inflate failed" userInfo:nil];
            }
        }
        if (decData) {
            str = [[NSString alloc] initWithData:decData encoding:NSUTF8StringEncoding];
            if (str == nil) {
                NSLog(@"decryptData无法处理错误的字符串");
                return @"";
            }
        }
    }
    return str;
}

+ (NSArray <NSString *>*)decryptFromData:(NSData *)allData config:(LoggerConfig *)config {
    NSAssert(allData != nil, @"allData could not be null");
    NSAssert(config.header != nil, @"header could not be null");
    
    NSMutableArray <NSString *>*results = [NSMutableArray array];
    NSInteger dataBegin = -1;
    NSData *headData = [config.header dataUsingEncoding:NSUTF8StringEncoding];
    while (true) {
        NSInteger searchBegin = dataBegin+1;
        NSRange searchRange = NSMakeRange(searchBegin, allData.length-searchBegin);
        NSRange headerRange = [allData rangeOfData:headData options:0 range:searchRange];
        if (headerRange.length != headData.length) {
            NSData *data = [allData subdataWithRange:NSMakeRange(dataBegin+1, allData.length-dataBegin-1)];
            NSString *result = [self decryptData:data password:config.password iv:config.iv useZip:config.isGzip];
            if (result && result.length > 0) {
                [results addObject:result];
            }
            break;
        }
        if (dataBegin != -1) {
            NSInteger dataEnd = (NSInteger)headerRange.location;
            NSData *data = [allData subdataWithRange:NSMakeRange(dataBegin+1, dataEnd-dataBegin-1)];
            NSString *result = [self decryptData:data password:config.password iv:config.iv useZip:config.isGzip];
            if (result && result.length > 0) {
                [results addObject:result];
            }
        }
        dataBegin = (NSInteger)(headerRange.location+headerRange.length-1);
    }
    return results;
}

+ (NSData *)encryptData:(NSArray <NSString *>*)allLog config:(LoggerConfig *)config {
    NSAssert(allLog != nil, @"allData could not be null");
    NSAssert(config.header != nil, @"header could not be null");
    
    NSData *headData = [config.header dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *mData = [NSMutableData data];
    for (NSString *log in allLog) {
        [mData appendData:headData];
        NSData *encData = [log dataUsingEncoding:NSUTF8StringEncoding];
        if (config.isGzip) {
            encData = [encData deflate];
            if (encData == nil) {
                @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:@"encryptData: deflate failed" userInfo:nil];
            }
        }
        if (config.password.length > 0) {
            encData = [encData crypt256:config.password iv:config.iv];
            if (encData == nil) {
                @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:@"encryptData: crypt256 failed" userInfo:nil];
            }
        }
        [mData appendData:encData];
    }
    return mData;
}

@end
