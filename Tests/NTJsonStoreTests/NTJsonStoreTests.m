//
//  NTJsonStoreTests.m
//  NTJsonStoreTests
//
//  Created by Ethan Nagel on 5/4/14.
//
//

#import <XCTest/XCTest.h>

@interface NTJsonStoreTests : XCTestCase

@end


@implementation NTJsonStoreTests


- (void)setUp
{
    [super setUp];
    
}


- (void)tearDown
{
    [super tearDown];
}


-(void)testCollection
{
    @autoreleasepool
    {
        NTJsonStore *store = [[NTJsonStore alloc] initWithName:@"test1.db"];
        NTJsonCollection *collection1 = [store collectionWithName:@"col1"];
        
        [collection1 removeAll];
        [collection1 addUniqueIndexWithKeys:@"[uid]"];
        
        NSDictionary *data1 = @{@"uid": @(1), @"name": @"One"};
        NSDictionary *data2 = @{@"uid": @(2), @"name": @"Two"};
        NSDictionary *data3 = @{@"uid": @(3), @"name": @"Three"};
        NSDictionary *data4 = @{@"uid": @(4), @"name": @"Four"};
        NSDictionary *data5 = @{@"uid": @(5), @"name": @"Five"};
        
        for(NSDictionary *data in @[data1, data2, data3, data4, data5])
        {
            NSError *error = [NSError errorWithDomain:@"Test" code:1 userInfo:nil];
            
            BOOL success = [collection1 insert:data error:&error];
            
            XCTAssert(success, @"insert failed - %@", error);
            
            if ( success )
                XCTAssert(error == nil, @"error is not nil"); // srror should be nil on all successful calls
        }
    }
    
    NSLog(@"All done");
    
}


@end
