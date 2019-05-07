//
//  Logger.m
//  DrClient_mac
//
//  Created by haitong on 2019/4/30.
//

#import "Logger.h"
#import "NSData+AES.h"
#import "NSData+Zlib.h"

//64kb
#define MAX_CACHE_SIZE  65536

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
        logger.fileLevel = LoggerLevelDebug;
        logger.level = LoggerLevelError;
        logger.logHeader = @"LOG_HEADER";
        logger.cacheSize = MAX_CACHE_SIZE;
    });
    return logger;
}

#pragma mark - properties
+ (void)setLogHeader:(NSString *)logHeader {
    NSAssert(logHeader != nil, @"logHeader could not be null");
    [self getInstance].logHeader = logHeader;
}

+ (void)setMaxCacheSize:(NSInteger)cacheSize {
    NSAssert(cacheSize > 0 && cacheSize < 131072, @"Cache size out of range");
    [self getInstance].cacheSize = cacheSize;
}

+ (void)setLogLevel:(LoggerLevel)level {
    [self getInstance].level = level;
}

+ (void)setFileLogLevel:(LoggerLevel)level {
    [self getInstance].fileLevel = level;
}

#pragma mark -
+ (void)initFilePath:(NSString *)path secretKey:(NSString *)secretKey iv:(NSData *)iv useZip:(BOOL)useZip {
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
    logger.fileHandle = handle;
    logger.fileSecretKey = secretKey;
    logger.iv = iv;
    
    if (useZip) {
        int windowBits = 15;
        int GZIP_ENCODING = 16;
        if (deflateInit2(&logger->_zStream, Z_BEST_SPEED, Z_DEFLATED, windowBits | GZIP_ENCODING,
                         8, Z_DEFAULT_STRATEGY) < 0) {
            NSString *message = @"Could not init zlib";
            @throw [NSException exceptionWithName:NSStringFromClass(self.class) reason:message userInfo:nil];
        }
        logger.useZip = YES;
    }
    
    if (secretKey.length > 0) {
        CCCryptorRef cryptor;
        char keyPtr[kCCKeySizeAES256 + 1] = {0};
        [secretKey getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
        
        //建立句柄，用来动态追加，最后调用endLogFile销毁
        if (kCCSuccess == CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding, keyPtr, kCCKeySizeAES256,
                                          iv.bytes, &cryptor)) {
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
    
    //先压缩后加密
    if (logger.useZip) {
        data = [data deflateWithStream:&logger->_zStream chunk:8192];
    }
    if (logger.fileSecretKey.length > 0) {
        data = [data updateEncrypt256:logger.fileCryptor password:logger.fileSecretKey iv:logger.iv];
    }
    
    //用队列写
    [[self getInstance].fileLock lock];
    NSMutableData *fileCache = [self getInstance].fileCache;
    [fileCache appendData:data];
    if (fileCache.length > MAX_CACHE_SIZE) {
        [[self getInstance].fileHandle writeData:fileCache];
        
        //每写一次以后就清缓存
        [self getInstance].fileCache = [NSMutableData data];
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
    if (logger.useZip) {
        deflateEnd(&logger->_zStream);
        logger.useZip = NO;
    }
    CCCryptorRef cryptor = [self getInstance].fileCryptor;
    if (cryptor) {
        NSFileHandle *handle = [self getInstance].fileHandle;
        if (handle) {
            char buffer[kCCBlockSizeAES128] = {0};
            size_t dataOutMoved = 0;
            if (kCCSuccess == CCCryptorFinal(cryptor, buffer, sizeof(buffer), &dataOutMoved)) {
                __block NSData *data = [NSData dataWithBytes:buffer length:dataOutMoved];
                
                [[self getInstance].fileLock lock];
                NSMutableData *fileCache = [self getInstance].fileCache;
                [fileCache appendData:data];
                [handle writeData:fileCache];
                [handle closeFile];
                [self getInstance].fileHandle = nil;
                
                //最后写肯定得清缓存
                [self getInstance].fileCache = [NSMutableData data];
                [[self getInstance].fileLock unlock];
            }
        }
        CCCryptorRelease(cryptor);
    }
}

#pragma mark -
+ (NSString *)decryptData:(NSData *)data password:(NSString *)password iv:(NSData *)iv useZip:(BOOL)useZip {
    NSString *str = @"";
    if (data.length > 0) {
        NSData *decData = [data decrypt256:password iv:iv];
        if (decData) {
            if (useZip) {
                decData = [decData inflate];
            }
            str = [[NSString alloc] initWithData:decData encoding:NSUTF8StringEncoding];
            if (str == nil) {
                NSLog(@"decryptData无法处理错误的字符串，退出");
                return @"";
            }
        }
    }
    return str;
}

+ (NSArray <NSString *>*)decryptFromData:(NSData *)allData password:(NSString *)password
                                      iv:(NSData *)iv useZip:(BOOL)useZip {
    NSMutableArray <NSString *>*results = [NSMutableArray array];
    NSInteger dataBegin = -1;
    NSData *headData = [[self getInstance].logHeader dataUsingEncoding:NSUTF8StringEncoding];
    while (true) {
        NSInteger searchBegin = dataBegin+1;
        NSRange searchRange = NSMakeRange(searchBegin, allData.length-searchBegin);
        NSRange headerRange = [allData rangeOfData:headData options:0 range:searchRange];
        if (headerRange.length != headData.length) {
            NSData *data = [allData subdataWithRange:NSMakeRange(dataBegin+1, allData.length-dataBegin-1)];
            NSString *result = [self decryptData:data password:password iv:iv useZip:useZip];
            if (result && result.length > 0) {
                [results addObject:result];
            }
            break;
        }
        if (dataBegin != -1) {
            NSInteger dataEnd = (NSInteger)headerRange.location;
            NSData *data = [allData subdataWithRange:NSMakeRange(dataBegin+1, dataEnd-dataBegin-1)];
            NSString *result = [self decryptData:data password:password iv:iv useZip:useZip];
            if (result && result.length > 0) {
                [results addObject:result];
            }
        }
        dataBegin = (NSInteger)(headerRange.location+headerRange.length-1);
    }
    return results;
}

@end
