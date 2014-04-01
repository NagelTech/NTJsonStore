//
//  AppDelegate.m
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/25/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import "AppDelegate.h"

#import "NTJsonStore.h"


static id mutableDeepCopy(id value)
{
    if ( [value isKindOfClass:[NSArray class]] )
    {
        NSArray *array = value;
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:array.count];
        
        for(id item in array)
            [result addObject:mutableDeepCopy(item)];
        
        return result;
    }
    
    else if ( [value isKindOfClass:[NSDictionary class]] )
    {
        NSDictionary *dictionary = value;
        NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];
        
        for(id key in dictionary.allKeys)
        {
            id item = dictionary[key];
            
            result[key] = mutableDeepCopy(item);
        }
        
        return result;
    }
    
    else
        return value;
}


@implementation AppDelegate


-(void)load:(NSArray *)items intoCollection:(NTJsonCollection *)collection
{
    for(NSDictionary *item in items)
        [collection insert:item];
}

-(void)loadDataWithStore:(NTJsonStore *)store
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"ReceiverData" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

    [self load:json[@"categories"] intoCollection:[store collectionWithName:@"categories"]];
    [self load:json[@"sources"] intoCollection:[store collectionWithName:@"sources"]];
    [self load:json[@"messages"] intoCollection:[store collectionWithName:@"messages"]];
}


-(void)dumpMessagesInStore:(NTJsonStore *)store
{
    NTJsonCollection *messagesCollection = [store collectionWithName:@"messages"];
    NTJsonCollection *sourcesCollection = [store collectionWithName:@"sources"];
    NTJsonCollection *categoriesCollection = [store collectionWithName:@"categories"];

    NSArray *messages = [messagesCollection findWhere:nil args:nil orderBy:@"[categoryId], [sourceId]"];
    
    for(NSDictionary *message in messages)
    {
        NSDictionary *source = [sourcesCollection findOneWhere:@"[id] = ?" args:@[message[@"sourceId"]]];
        NSDictionary *category = [categoriesCollection findOneWhere:@"[id] = ?" args:@[message[@"categoryId"]]];
        
        NSLog(@"message id %@: source name = %@, category name = %@", message[@"id"], source[@"name"], category[@"name"]);
    }
}


-(void)doTest
{
    NTJsonStore *store = [[NTJsonStore alloc] initWithName:@"sample.db"];

    if ( !store.collections.count )
        [self loadDataWithStore:store];
    
    NSLog(@"Collections: %@", [store.collections componentsJoinedByString:@", "]);
    
    // Ok, now we can use our data...
    
    NTJsonCollection *messagesCollection = [store collectionWithName:@"messages"];
    NTJsonCollection *sourcesCollection = [store collectionWithName:@"sources"];
    NTJsonCollection *categoriesCollection = [store collectionWithName:@"categories"];
    
    [messagesCollection addUniqueIndexWithKeys:@"[id]"];
    [messagesCollection addIndexWithKeys:@"[categoryId]"];
    [messagesCollection addIndexWithKeys:@"[sourceId]"];
    
    [sourcesCollection addUniqueIndexWithKeys:@"[id]"];
    [sourcesCollection addIndexWithKeys:@"[name]"];
    
    [categoriesCollection addUniqueIndexWithKeys:@"[id]"];
    [categoriesCollection addIndexWithKeys:@"[name]"];
    
    NSLog(@"Initial Data");
    
    [self dumpMessagesInStore:store];
    
    // Convert Category ID's to numeric...
    
    for(NSMutableDictionary *category in mutableDeepCopy([categoriesCollection findWhere:@"[id] <> [__rowid__]" args:nil orderBy:@"[id] desc"]))
    {
        NSArray *messages = mutableDeepCopy([messagesCollection findWhere:@"[categoryId]=?" args:@[category[@"id"]] orderBy:nil]);
        
        category[@"id"] = category[@"__rowid__"];
        
        [categoriesCollection update:category];
        
        for(NSMutableDictionary *message in messages)
        {
            message[@"categoryId"] = category[@"id"];
            [messagesCollection update:message];
        }
    }
    
    for(NSMutableDictionary *source in mutableDeepCopy([sourcesCollection findWhere:@"[id] <> [__rowid__]" args:nil orderBy:@"[id] desc"]))
    {
        NSArray *messages = mutableDeepCopy([messagesCollection findWhere:@"[sourceId]=?" args:@[source[@"id"]] orderBy:nil]);
        
        source[@"id"] = source[@"__rowid__"];
        
        [sourcesCollection update:source];
        
        for(NSMutableDictionary *message in messages)
        {
            message[@"sourceId"] = source[@"id"];
            [messagesCollection update:message];
        }
    }
    
    NSLog(@"After category update");
    
    [self dumpMessagesInStore:store];
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    [self doTest];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
