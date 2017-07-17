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


-(void)testAliases
{
    NSDictionary *tests =
    @{
        @"test replace one not ones 123.45 not [one] not 'a one in here'": @"test replace [one] not ones 123.45 not [one] not 'a one in here'",
        @"test multiple one two three": @"test multiple [one] [two] [three]",
        @"'quote edge cases'": @"'quote edge cases'",
        @"one 42": @"[one] 42",
        @"42 one": @"42 [one]",
      };
    
    NSDictionary *aliases = @{@"one": @"[one]", @"two": @"[two]", @"three": @"[three]"};
    
    NTJsonCollection *collection1 = [self.store collectionWithName:@"collection1"];

    collection1.aliases = aliases;
    
    for (NSString *string in tests.allKeys)
    {
        NSString *parsed = [collection1 replaceAliasesIn:string];
        NSString *expected = tests[string];
        
        XCTAssert([parsed isEqualToString:expected], @"Alias parsing failed. input \"%@\", expected \"%@\", actual \"%@\"", string, expected, parsed);
    }
}


-(void)tryLiveQueryWithCollection:(NTJsonCollection *)collection Action:(void (^)())action validation:(void (^)(NTJsonChangeSet *))validation
{
    NTJsonLiveQuery *liveQuery = [collection liveQueryWhere:@"LENGTH([name]) == 3" args:nil orderBy:@"[uid]" limit:-1];
    
    action();
    
    [liveQuery addSubscriber:^(NTJsonChangeSet *changeSet) {
        validation(changeSet);
    }];
    
    BOOL changed = [collection pushChanges];
    XCTAssert(changed, @"changes not detected");
    
    [liveQuery close];
}


+(NSArray *)filterArray:(NSArray *)array withIndexSet:(NSIndexSet *)indexSet
{
    NSMutableArray *result = [NSMutableArray array];
    
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        [result addObject:array[idx]];
    }];
    
    return [result copy];
}


-(void)testLiveQueries
{
    NSDictionary *data1 = @{@"uid": @(1), @"name": @"One", @"is_odd": @(YES)};
    NSDictionary *data2 = @{@"uid": @(2), @"name": @"Two", @"is_odd": @(NO)};
    NSDictionary *data3 = @{@"uid": @(3), @"name": @"Three", @"is_odd": @(YES)};
    NSDictionary *data4 = @{@"uid": @(4), @"name": @"Four"};
    NSDictionary *data5 = @{@"uid": @(5), @"name": @"Five", @"is_odd": @(YES)};
    NSDictionary *data6 = @{@"uid": @(6), @"name": @"Six"};
    
    NTJsonCollection *collection1 = [self.store collectionWithName:@"collection1"];
    
    [collection1 insert:data1];
    [collection1 insert:data6];
    
    // test insert
    
    [self tryLiveQueryWithCollection:collection1 Action:^{
        [collection1 insert:data2];
        [collection1 insert:data3];
        [collection1 insert:data4];
        [collection1 insert:data5];
    } validation:^(NTJsonChangeSet *changeSet) {
        NSArray *initialItems = @[data1, data6];
        NSArray *newItems = @[data1, data2, data6];
        NSArray *expectedChanges = @[[NTJsonChangeSetChange insertWithNewIndex:1 item:data2]];
        
        [self compareExpectedItems:initialItems actualItems:changeSet.oldItems operation:@"changeSet oldItems invalid"];
        [self compareExpectedItems:newItems actualItems:changeSet.items operation:@"changeSet items invalid"];
        XCTAssert([changeSet.changes isEqualToArray:expectedChanges], @"changes invalid for insert");
    }];
    
    // test delete...
    
    [self tryLiveQueryWithCollection:collection1 Action:^{
        NSDictionary *itemToDelete = [collection1 findOneWhere:@"[uid] = 1" args:nil];
        XCTAssert(itemToDelete, @"unable to find itemToDelete");
        
        XCTAssert([collection1 remove:itemToDelete] == 1, @"unable to delete item");
    } validation:^(NTJsonChangeSet *changeSet) {
        NSArray *initialItems = @[data1, data2, data6];
        NSArray *newItems = @[data2, data6];
        NSArray *expectedChanges = @[[NTJsonChangeSetChange deleteWithOldIndex:0 item:data1]];
        
        [self compareExpectedItems:initialItems actualItems:changeSet.oldItems operation:@"changeSet oldItems invalid"];
        [self compareExpectedItems:newItems actualItems:changeSet.items operation:@"changeSet items invalid"];
        XCTAssert([changeSet.changes isEqualToArray:expectedChanges], @"changes invalid for delete");
    }];
    
    // test update...
    
    NSMutableDictionary *itemToUpdate = [[collection1 findOneWhere:@"[uid] = 2" args:nil] mutableCopy];
    XCTAssert(itemToUpdate, @"couldn't find item to update");
    itemToUpdate[@"name"] = @"TWO";
    
    [self tryLiveQueryWithCollection:collection1 Action:^{
        XCTAssert([collection1 update:itemToUpdate], @"couldn't update item");
    } validation:^(NTJsonChangeSet *changeSet) {
        NSArray *initialItems = @[data2, data6];
        NSArray *newItems = @[itemToUpdate, data6];
        NSArray *expectedChanges = @[[NTJsonChangeSetChange updateWithOldIndex:0 newIndex:0 item:itemToUpdate]];
        
        [self compareExpectedItems:initialItems actualItems:changeSet.oldItems operation:@"changeSet oldItems invalid"];
        [self compareExpectedItems:newItems actualItems:changeSet.items operation:@"changeSet items invalid"];
        
        XCTAssert([changeSet.changes isEqualToArray:expectedChanges], @"changes invalid for update");
    }];
    
    // test move...
    
    NSMutableDictionary *itemToUpdate2 = [itemToUpdate mutableCopy];
    itemToUpdate2[@"uid"] = @(100);
    
    [self tryLiveQueryWithCollection:collection1 Action:^{
        XCTAssert([collection1 update:itemToUpdate2], @"couldn't update item");
    } validation:^(NTJsonChangeSet *changeSet) {
        NSArray *initialItems = @[itemToUpdate, data6];
        NSArray *newItems = @[data6, itemToUpdate2];
        NSArray *expectedChanges = @[[NTJsonChangeSetChange moveWithOldIndex:1 newIndex:0 item:data6],
                                     [NTJsonChangeSetChange updateWithOldIndex:0 newIndex:1 item:itemToUpdate2]];
        
        [self compareExpectedItems:initialItems actualItems:changeSet.oldItems operation:@"changeSet oldItems invalid"];
        [self compareExpectedItems:newItems actualItems:changeSet.items operation:@"changeSet items invalid"];
        
        XCTAssert([changeSet.changes isEqualToArray:expectedChanges], @"changes invalid for move");
    }];
}


@end
