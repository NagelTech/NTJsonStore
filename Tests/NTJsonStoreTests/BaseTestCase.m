//
//  BaseTestCase.m
//  NTJsonStoreTests
//
//  Created by Ethan Nagel on 5/7/14.
//
//

#import "BaseTestCase.h"


@interface BaseTestCase ()
{
    NTJsonStore *_store;
}

@end


@implementation BaseTestCase


+(NSString *)storeName
{
    return [NSString stringWithFormat:@"%@.db", NSStringFromClass(self)];
}


-(void)setUp
{
    [super setUp];
    
    _store = [[NTJsonStore alloc] initWithName:[self.class storeName]];
    
    [[NSFileManager defaultManager] removeItemAtPath:_store.storeFilename error:nil];
    
    NSLog(@"Initializing store at: %@", _store.storeFilename);
}


-(void)tearDown
{
    // note: leave the store intact for debugging.
    
    [_store close];
    
    NSLog(@"Store Closed: %@", _store.storeFilename);
    _store = nil;
    
    [super tearDown];
}


@end

