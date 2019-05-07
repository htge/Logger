//
//  NSData+AES.m
//  DrClient_mac
//
//  Created by Ge on 2019/5/7.
//

#import "NSData+AES.h"

@implementation NSData (AES)

- (NSData *)decrypt256:(NSString *)password iv:(NSData *)iv {
    char keyPtr[kCCKeySizeAES256 + 1] = {0};
    
    [password getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    NSUInteger dataLength = [self length];
    
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void* buffer = malloc(bufferSize);
    
    size_t numBytesDecrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256, iv.bytes,
                                          [self bytes], dataLength, buffer, bufferSize, &numBytesDecrypted);
    
    if (cryptStatus == kCCSuccess) {
        return [NSMutableData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    
    free(buffer);
    return nil;
}

- (NSData *)updateEncrypt256:(CCCryptorRef)cryptor password:(NSString *)password iv:(NSData *)iv {
    NSUInteger dataLength = self.length;
    char keyPtr[kCCKeySizeAES256 + 1] = {0};
    [password getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    //堆缓存建立，足够的长度即可
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    size_t numBytesEncrypted = 0;
    if (kCCSuccess == CCCryptorUpdate(cryptor, [self bytes], dataLength,
                                      buffer, bufferSize, &numBytesEncrypted)) {
        return [NSMutableData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    
    free(buffer);
    return nil;
}

@end
