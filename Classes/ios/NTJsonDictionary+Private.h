//
//  NTJsonDictionary.h
//  NTJsonStoreTests
//
//  Created by Ethan Nagel on 5/13/14.
//
//

#import <Foundation/Foundation.h>


@interface NTJsonDictionary : NSDictionary

-(id)initWithCacheItem:(NTJsonObjectCacheItem *)cacheItem;

-(BOOL)NTJson_isCurrent;


@end
