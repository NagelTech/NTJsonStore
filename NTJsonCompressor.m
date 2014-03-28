//
//  NTJsonCompressor.m
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/27/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//


#import "NTJsonStore+Private.h"


typedef enum
{
    DATA_TYPE_INT8          = 0x0,              // 1 byte
    DATA_TYPE_INT16         = 0x1,              // 2 bytes
    DATA_TYPE_INT32         = 0x2,              // 4 bytes
    DATA_TYPE_INT64         = 0x3,              // 8 bytes
    DATA_TYPE_DOUBLE        = 0x4,              // 8 bytes
    DATA_TYPE_DATE          = 0x5,              // 4 bytes (?)
    
    DATA_TYPE_STRING        = 0x8,              // variable (high bit = variable types)
    DATA_TYPE_DICTIONARY    = 0x9,              // variable
    DATA_TYPE_ARRAY         = 0xA,              // variable
} DATA_TYPE;


@interface NSMutableData (NSJsonCompressor)

-(void)appendInt8:(int8_t)value;
-(void)appendInt16:(int16_t)value;
-(void)appendInt32:(int32_t)value;
-(void)appendInt64:(int64_t)value;
-(void)appendDouble:(double)value;

-(void)replaceInt16:(int16_t)value atOffset:(int)offset;

@end


@interface NTJsonCompressor ()
{
    NSArray *_keys;
    NSMutableDictionary *_keyLookup;
    NTJsonStore *_store;
    NSString *_collectionName;
}

@property (nonatomic,readonly) NSMutableArray *keys;
@property (nonatomic,readonly) NSMutableDictionary *keyLookup;

@end


struct key_index
{
    int32_t         key;        // bits 0-8 = key0, 9-16 = key1, etc
    uint16_t        offset;     // 64k max offset into data area
    unsigned int    type:4;     // up to 15 typs
    unsigned int    size:12;    // 4k max size
};

// Thought - store in a very readable way if possible:
// key index:
//   key path (32 bits with - up to 4 1-byte key indexes)
//   offset to data (16 bits)
//   type + size (4 bits = type / 12 bits = size)
// All data would be stored after key index.
// Limitations:
//   255 or fewer total keys in collection (case sensitive)
//   keys may only be 4-levels deep.
//   all values must be less than 4k
//   total data must be less than 64k
// If the data doesn't fit into the limitations a slightly slower recursive format is used.


@implementation NTJsonCompressor


static const int32_t header = 0x20130529;


-(int)getKeyIndex:(NSString *)key
{
    NSNumber *existingIndex = self.keyLookup[key];
    
    if ( existingIndex )
        return [existingIndex intValue];
    
    int index = self.keys.count;
    
    [self.keys addObject:key];
    self.keyLookup[key] = @(index);
    
    return index;
    
}


-(NSString *)getKeyName:(int)index
{
    
}


-(id)initWithStore:(NTJsonStore *)store collectionName:(NSString *)collectionName
{
    self = [super init];
    
    if ( self )
    {
        _keys = nil;
        _store = store;
        _collectionName = collectionName;
    }
    
    return self;
}


-(void)compressNumber:(NSNumber *)number toData:(NSMutableData *)data
{
}


-(void)compressDate:(NSDate *)date toData:(NSMutableData *)data
{
}

-(void)compressString:(NSString *)string toData:(NSMutableData *)data
{
}


-(void)compressArray:(NSDictionary *)dictionary toData:(NSMutableData *)data
{
}


-(void)compressDictionary:(NSDictionary *)dictionary toData:(NSMutableData *)data
{
    int startPos = (int)data.length;
    
    [data appendInt32:DATA_TYPE_DICTIONARY<<24];
    
    for(NSString *key in dictionary.allKeys)
    {
        // todo: lookup key
    }
    
    
}


-(void)compressValue:(id)value toData:(NSMutableData *)data
{
    if ( [value isKindOfClass:[NSDictionary class]] )
        [self compressDictionary:value toData:data];
    
    else if ( [value isKindOfClass:[NSArray class]] )
        [self compressArray:value toData:data];
    
    else if ( [value isKindOfClass:[NSString class]] )
        [self compressString:value toData:data];
    
    else if ( [value isKindOfClass:[NSDate class]] )
        [self compressDate:value toData:data];
    
    else if ( [value isKindOfClass:[NSNumber class]] )
        [self compressNumber:value toData:data];
    
    else
        @throw [NSException exceptionWithName:@"UnexpectedType" reason:@"Unexpected type in JSON stream" userInfo:nil];
}


-(NSData *)compressJson:(NSDictionary *)json
{
    NSMutableData *data = [NSMutableData data];
    
    // write header
    
    [data appendBytes:&header length:sizeof(header)];
    
    // now append our data...
    
    [self compressValue:json toData:data];
    
    return [data copy];
}



@end

