//
//  NSData+Zlib.h
//  DrClient_mac
//
//  Created by Ge on 2019/5/7.
//

#import <Foundation/Foundation.h>
#import <zlib.h>

NS_ASSUME_NONNULL_BEGIN

#define GZIP_ENCODING 16

@interface NSData (ZLIB)

- (NSData *)deflate;
- (NSData *)deflateWithStream:(z_stream *)pstrm chunk:(int)chunk;
- (NSData *)inflate;

@end

NS_ASSUME_NONNULL_END
