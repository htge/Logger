//
//  NSData+Zlib.m
//  DrClient_mac
//
//  Created by Ge on 2019/5/7.
//

#import "NSData+Zlib.h"

@implementation NSData(ZLIB)

- (NSData *)deflate {
    NSMutableData *mdata = [NSMutableData data];
    z_stream strm = { 0 };
    //区块越大，压缩率越高。16K以上则差距小得多
    int chunk = 65536, start = 0, len = 0;
    char *chunk_in = NULL, *chunk_out = NULL;
    if (deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, MAX_WBITS | GZIP_ENCODING,
                     8, Z_DEFAULT_STRATEGY) < 0) {
        return nil;
    }
    
    chunk_in = malloc(chunk);
    if (!chunk_in) {
        return nil;
    }
    chunk_out = malloc(chunk);
    if (!chunk_out) {
        free(chunk_in);
        return nil;
    }
    start = 0;
    len = (int)(self.length > chunk ? chunk : self.length);
    while (len > 0) {
        int have = 0, remain = 0;
        @try {
            [self getBytes:chunk_in range:NSMakeRange(start, len)];
        } @catch (NSException *e) {
            NSLog(@"deflateWithStream cause exception: %@", e);
            break;
        }
        
        strm.next_in = (Bytef *)chunk_in;
        strm.avail_in = len;
        strm.avail_out = chunk;
        strm.next_out = (Bytef *)chunk_out;
        if (deflate(&strm, Z_BLOCK) < 0) {
            break;
        }
        
        have = chunk - strm.avail_out;
        [mdata appendBytes:chunk_out length:have];
        
        start += len;
        remain = (int)(self.length - start);
        len = remain > chunk ? chunk : remain;
    }
    free(chunk_in);
    free(chunk_out);
    deflateEnd(&strm);
    return mdata;
}

- (NSData *)deflateWithStream:(z_stream *)pstrm chunk:(int)chunk {
    assert(chunk >= 128 && chunk < 262144);
    
    NSMutableData *mdata = [NSMutableData data];
    int start = 0;
    int len = (int)(self.length > chunk ? chunk : self.length);
    char *chunk_in = malloc(chunk), *chunk_out = NULL;
    if (!chunk_in) {
        return nil;
    }
    chunk_out = malloc(chunk);
    if (!chunk_out) {
        free(chunk_in);
        return nil;
    }
    while (len > 0) {
        int have = 0, remain = 0;
        @try {
            [self getBytes:chunk_in range:NSMakeRange(start, len)];
        } @catch (NSException *e) {
            NSLog(@"deflateWithStream cause exception: %@", e);
            break;
        }
        
        pstrm->next_in = (Bytef *)chunk_in;
        pstrm->avail_in = len;
        pstrm->avail_out = chunk;
        pstrm->next_out = (Bytef *)chunk_out;
        if (deflate(pstrm, Z_BLOCK) < 0) {
            break;
        }
        
        have = chunk - pstrm->avail_out;
        [mdata appendBytes:chunk_out length:have];
        
        start += len;
        remain = (int)(self.length - start);
        len = remain > chunk ? chunk : remain;
    }
    return mdata;
}

- (NSData *)inflate {
    NSMutableData *mdata = [NSMutableData data];
    z_stream strm = { 0 };
    int chunk = 65536, start = 0, len = 0;
    char *chunk_in = NULL, *chunk_out = NULL;
    
    if (inflateInit2(&strm, MAX_WBITS | GZIP_ENCODING) < 0) return nil;
    chunk_in = malloc(chunk);
    if (!chunk_in) return nil;
    chunk_out = malloc(chunk);
    if (!chunk_out) {
        free(chunk_in);
        return nil;
    }
    len = (int)(self.length > chunk ? chunk : self.length);
    while (len > 0) {
        int have = 0, remain = 0;
        
        @try {
            [self getBytes:chunk_in range:NSMakeRange(start, len)];
        } @catch (NSException *e) {
            NSLog(@"inflate cause exception: %@", e);
            break;
        }

        strm.next_in = (Bytef *)chunk_in;
        strm.avail_in = len;
        strm.avail_out = chunk;
        strm.next_out = (Bytef *)chunk_out;
        if (inflate(&strm, Z_NO_FLUSH) < 0) {
            NSLog(@"inflate_err: %i", errno);
            break;
        }
        
        have = chunk - strm.avail_out;
        [mdata appendBytes:chunk_out length:have];
        
        start += (len-strm.avail_in);
        remain = (int)(self.length - start);
        len = remain > chunk ? chunk : remain;
    }
    free(chunk_in);
    free(chunk_out);
    inflateEnd(&strm);
    return mdata;
}

@end
