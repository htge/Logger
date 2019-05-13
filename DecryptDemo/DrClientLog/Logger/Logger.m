//
//  Logger.m
//  DrClient_mac
//
//  Created by haitong on 2019/4/30.
//

#import "Logger.h"
#import "NSData+AES.h"
#import "NSData+Zlib.h"

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
@property (strong, nonatomic) NSLock *fileLock;

@end

@implementation Logger

+ (Logger *)getInstance {
    static dispatch_once_t onceToken;
    static Logger *logger;
    dispatch_once(&onceToken, ^{
        logger = [[Logger alloc] init];
        logger.fileCache = [NSMutableData data];
        logger.fileLock = [[NSLock alloc] init];
        logger.level = LoggerLevelError;
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
    
    BOOL isDirectory;
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
    [handle seekToEndOfFile];
    [handle writeData:[[self getInstance].logHeader dataUsingEncoding:NSUTF8StringEncoding]];
    
    //设置全局配置，当调用日志函数时会用得到
    Logger *logger = [self getInstance];
    NSAssert(logger != nil, @"logger could not be null");
    logger.fileLevel = config.logLevel;
    logger.logHeader = config.header;
    logger.fileHandle = handle;
    logger.fileSecretKey = config.password;
    logger.cacheSize = config.cacheSize;
    logger.iv = config.iv;
    
    if (config.isGzip) {
        if (deflateInit2(&logger->_zStream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, MAX_WBITS | GZIP_ENCODING,
                         8, Z_DEFAULT_STRATEGY) < 0) {
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
    [[self getInstance].fileLock lock];
    NSMutableData *fileCache = [self getInstance].fileCache;
    if (data != nil) {
        [fileCache appendData:data];
        if (fileCache.length > logger.cacheSize) {
            //先压缩后加密
            NSData *writeData = fileCache;
            if (logger.useZip) {
                writeData = [writeData deflateWithStream:&logger->_zStream chunk:(int)logger.cacheSize];
            }
            if (logger.fileSecretKey.length > 0) {
                writeData = [writeData updateEncrypt256:logger.fileCryptor password:logger.fileSecretKey iv:logger.iv];
            }
            [[self getInstance].fileHandle writeData:writeData];
            
            //每写一次以后就清缓存
            [self getInstance].fileCache = [NSMutableData data];
        }
    }
    [[self getInstance].fileLock unlock];
}

#pragma mark -
+ (void)info:(NSString *)format, ... {
    NSAssert(format != nil, @"format could not be null");
    
    BOOL isOutputToConsole = [self getInstance].level >= LoggerLevelInfo;
    BOOL isOutputToFile = [self getInstance].fileLevel >= LoggerLevelInfo && [self getInstance].fileHandle != nil;
    
    if (isOutputToConsole || isOutputToFile) {
        va_list args;
        va_start(args, format);
        NSMutableString *string = [NSMutableString stringWithString:@"INFO: "];
        [string appendString:[[NSString alloc] initWithFormat:format arguments:args]];
        va_end(args);
        
        if (isOutputToConsole) {
            NSLog(@"%@", string);
        }
        if (isOutputToFile) {
            [self outputToFile:string];
        }
    }
}

+ (void)debug:(NSString *)format, ... {
    NSAssert(format != nil, @"format could not be null");
    
    BOOL isOutputToConsole = [self getInstance].level >= LoggerLevelDebug;
    BOOL isOutputToFile = [self getInstance].fileLevel >= LoggerLevelDebug && [self getInstance].fileHandle != nil;
    if (isOutputToConsole || isOutputToFile) {
        va_list args;
        va_start(args, format);
        NSMutableString *string = [NSMutableString stringWithString:@"DEBUG: "];
        [string appendString:[[NSString alloc] initWithFormat:format arguments:args]];
        va_end(args);
        
        if (isOutputToConsole) {
            NSLog(@"%@", string);
        }
        if (isOutputToFile) {
            [self outputToFile:string];
        }
    }
}

+ (void)warn:(NSString *)format, ... {
    NSAssert(format != nil, @"format could not be null");
    
    BOOL isOutputToConsole = [self getInstance].level >= LoggerLevelWarn;
    BOOL isOutputToFile = [self getInstance].fileLevel >= LoggerLevelWarn && [self getInstance].fileHandle != nil;
    
    if (isOutputToConsole || isOutputToFile) {
        va_list args;
        va_start(args, format);
        NSMutableString *string = [NSMutableString stringWithString:@"WARN: "];
        [string appendString:[[NSString alloc] initWithFormat:format arguments:args]];
        va_end(args);
        
        if (isOutputToConsole) {
            NSLog(@"%@", string);
        }
        if (isOutputToFile) {
            [self outputToFile:string];
        }
    }
}

+ (void)error:(NSString *)format, ... {
    NSAssert(format != nil, @"format could not be null");
    
    BOOL isOutputToConsole = [self getInstance].level >= LoggerLevelError;
    BOOL isOutputToFile = [self getInstance].fileLevel >= LoggerLevelError && [self getInstance].fileHandle != nil;
    
    if (isOutputToConsole || isOutputToFile) {
        va_list args;
        va_start(args, format);
        NSMutableString *string = [NSMutableString stringWithString:@"ERROR: "];
        [string appendString:[[NSString alloc] initWithFormat:format arguments:args]];
        va_end(args);
        
        if (isOutputToConsole) {
            NSLog(@"%@", string);
        }
        if (isOutputToFile) {
            [self outputToFile:string];
        }
    }
}

#pragma mark -
+ (void)endLogFile {
    Logger *logger = [self getInstance];
    NSFileHandle *handle = [self getInstance].fileHandle;
    if (handle) {
        [[self getInstance].fileLock lock];
        NSMutableData *fileCache = [self getInstance].fileCache;
        
        //先压缩后加密
        NSData *writeData = fileCache;
        if (logger.useZip) {
            writeData = [writeData deflateWithStream:&logger->_zStream chunk:(int)logger.cacheSize];
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
        [[self getInstance].fileLock unlock];
    }
    if (logger.useZip) {
        deflateEnd(&logger->_zStream);
        logger.useZip = NO;
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
                NSLog(@"decryptData无法处理错误的字符串，退出");
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
