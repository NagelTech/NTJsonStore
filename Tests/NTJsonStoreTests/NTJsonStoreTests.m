//
//  NTJsonStoreTests.m
//  NTJsonStoreTests
//
//  Created by Ethan Nagel on 5/4/14.
//
//

#import <XCTest/XCTest.h>

@interface NTJsonStoreTests : BaseTestCase

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


-(void)compareExpectedItems:(NSArray *)expectedItems actualItems:(NSArray *)actualItems operation:(NSString *)operation
{
    XCTAssert(actualItems, @"%@ failed", operation);
    XCTAssert(expectedItems.count == actualItems.count, @"Wrong number of items from %@", operation);
    
    for(int index=0; index<MIN(expectedItems.count, actualItems.count); index++)
    {
        NSDictionary *expected = expectedItems[index];
        NSDictionary *actual = actualItems[index];
        
        for(NSString *key in expected.allKeys)
        {
            id expectedValue = expected[key];
            id actualValue = actual[key];
            
            XCTAssert(expectedValue == actualValue || [expectedValue isEqual:actualValue], @"%@ returned unexpected data at index %d, key %@: expected=%@, actual=%@", operation, index, key, expectedValue ?: @"(nil)", actualValue ?: @"(nil)");
        }
    }
}


-(void)testCollection
{
    NTJsonCollection *collection1 = [self.store collectionWithName:@"collection1"];
    
    // Test data
    
    NSDictionary *data1 = @{@"uid": @(1), @"name": @"One", @"is_odd": @(YES)};
    NSDictionary *data2 = @{@"uid": @(2), @"name": @"Two", @"is_odd": @(NO)};
    NSDictionary *data3 = @{@"uid": @(3), @"name": @"Three", @"is_odd": @(YES)};
    NSDictionary *data4 = @{@"uid": @(4), @"name": @"Four"};
    NSDictionary *data5 = @{@"uid": @(5), @"name": @"Five", @"is_odd": @(YES)};
    
    NSDictionary *data6 = @{@"uid": @(6), @"name": @"Six"};

    // Test insert...
    
    {
        [collection1 addUniqueIndexWithKeys:@"[uid]"];
        
        for(NSDictionary *data in @[data1, data2, data3, data4, data5])
        {
            NSError *error = [NSError errorWithDomain:@"Test" code:1 userInfo:nil];
            
            BOOL success = [collection1 insert:data error:&error];
            
            XCTAssert(success, @"insert failed - %@", error);
            
            if ( success )
                XCTAssert(error == nil, @"error is not nil"); // error should be nil on all successful calls
        }
    }
    
    // Test insert duplicate key...
    
    {
        NSError *error;
        NTJsonRowId rowid = [collection1 insert:data2 error:&error];
        XCTAssert(rowid==0, @"Insert of duplicate key was allowed.");
    }
    
    // Test async insert, making sure it completes async...
    
    {
        __block BOOL asyncTaskCompleted = NO;

        [collection1 beginInsert:data6 completionQueue:NTJsonStoreSerialQueue completionHandler:^(NTJsonRowId rowid, NSError *error)
        {
            XCTAssert(rowid!=0, @"Insert of async item failed.");
            asyncTaskCompleted = YES;
        }];
        
        XCTAssert(asyncTaskCompleted==NO, @"Async task completed synchronously");
        
        [collection1 sync];
        
        XCTAssert(asyncTaskCompleted==YES, @"Async task did not complete during sync");
    }
    
    // Make sure we have the right data in the collection...
    
    {
        NSArray *expectedItems = @[data1, data2, data3, data4, data5, data6];
        NSArray *actualItems = [collection1 findWhere:nil args:nil orderBy:@"[uid]"];
        
        [self compareExpectedItems:expectedItems actualItems:actualItems operation:@"find ordered by uid"];
    }
    
    // Test materializing a new column and sorting on it...
    
    {
        NSArray *expectedItems = [@[data1, data2, data3, data4, data5, data6] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
        NSArray *actualItems = [collection1 findWhere:nil args:nil orderBy:@"[name]"];
        
        [self compareExpectedItems:expectedItems actualItems:actualItems operation:@"find ordered by name"];
    }
    
    // Test defaultJson...
    
    {
        collection1.defaultJson = @{@"is_odd": @(NO)};
        
        NSArray *expectedItems = @[data2, data4, data6];
        NSArray *actualItems = [collection1 findWhere:@"[is_odd]=?" args:@[@(NO)] orderBy:@"[uid]"];
        
        [self compareExpectedItems:expectedItems actualItems:actualItems operation:@"find with default json"];
    }
    
    // Test Cache of result data...
    
    {
        NSArray *items = [collection1 findWhere:nil args:nil orderBy:@"[uid]"];
        XCTAssertNotNil(items, @"find all failed");
        
        NSDictionary *firstItem = [collection1 findOneWhere:@"[uid] = 1" args:nil];
        XCTAssertNotNil(firstItem, @"find one failed");
        
        XCTAssert(items[0] == firstItem, @"Cache test");
    }
    
    // Test cache invalidation on update...
    
    {
        NSError *error;
        
        NSDictionary *item = [collection1 findOneWhere:@"[uid] = 3" args:nil];
        XCTAssertNotNil(item, @"findOne failed");
        
        XCTAssert([NTJsonStore isJsonCurrent:item], @"isJsonCurrent failed");
        
        NSMutableDictionary *updatedItem = [item mutableCopy];
        updatedItem[@"name"] = [updatedItem[@"name"] uppercaseString];
        
        [collection1 update:updatedItem error:&error];
        XCTAssertNil(error, @"update failed");
        
        XCTAssert(![NTJsonStore isJsonCurrent:item], @"isJsonCurrent returned YES after update");
    }
}


@end
