//
//  NSData+Zlib.m
//  DrClient_mac
//
//  Created by Ge on 2019/5/7.
//

#import "NSData+Zlib.h"

#define BUFLEN 16384

@implementation NSData(ZLIB)

- (NSData *)deflate {
    z_stream strm = { 0 };
    if (deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED,
                     MAX_WBITS + GZIP_ENCODING, 8, Z_DEFAULT_STRATEGY) != Z_OK) {
        return nil;
    }
    return [self closeStream:&strm];
}

- (NSData *)deflateWithStream:(z_stream *)pstrm {
    assert(pstrm != nil);
    
    NSMutableData *mdata = [NSMutableData data];
    unsigned char chunk_out[BUFLEN];
        
    pstrm->next_in = (void*)self.bytes;
    pstrm->avail_in = (uint)self.length;
    do {
        pstrm->next_out = chunk_out;
        pstrm->avail_out = BUFLEN;
        (void)deflate(pstrm, Z_NO_FLUSH);
        [mdata appendBytes:chunk_out length:BUFLEN - pstrm->avail_out];
    } while (pstrm->avail_out == 0);
    return mdata;
}

- (NSData *)closeStream:(z_stream *)pstrm {
    assert(pstrm != nil);

    NSMutableData *mdata = [NSMutableData data];
    unsigned char chunk_out[BUFLEN];
        
    pstrm->next_in = (void*)self.bytes;
    pstrm->avail_in = (uint)self.length;
    do {
        pstrm->next_out = chunk_out;
        pstrm->avail_out = BUFLEN;
        (void)deflate(pstrm, Z_FINISH);
        [mdata appendBytes:chunk_out length:BUFLEN - pstrm->avail_out];
    } while (pstrm->avail_out == 0);
    deflateEnd(pstrm);
    return mdata;
}

- (NSData *)inflate {
    NSMutableData *mdata = [NSMutableData data];
    z_stream strm = { 0 };
    char chunk_out[BUFLEN];
    int err, outLength;
    
    strm.next_in = 0;
    strm.avail_in = Z_NULL;

    if (inflateInit2(&strm, MAX_WBITS + GZIP_ENCODING) != Z_OK) return nil;

    strm.next_in = (void *)self.bytes;
    strm.avail_in = (int)self.length;
    
    do {
        strm.next_out = (void *)chunk_out;
        strm.avail_out = BUFLEN;
        err = inflate(&strm, Z_NO_FLUSH);
        if (err == Z_DATA_ERROR) {
            NSLog(@"inflate data error");
            break;
        }
        
        outLength = BUFLEN-strm.avail_out;
        if (outLength > 0) {
            [mdata appendBytes:chunk_out length:outLength];
        }
        if (err == Z_STREAM_END) {
            inflateEnd(&strm);
            break;
        }
        //兼容以前的协议
        if (strm.avail_in == 0) {
            NSLog(@"inflate: unexpected end of file");
            inflateEnd(&strm);
            break;
        }
    } while (strm.avail_out == 0);
    return mdata;
}

@end
