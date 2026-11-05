//
//  ModelDownloader.h
//  DTFIdentityManager
//
//  Created by mengbingchuan on 2022/9/7.
//  Copyright © 2022 DTF. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DTFBaseModelDownloader.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZimModelDownloader : DTFBaseModelDownloader

+ (ZimModelDownloader *)sharedInstance;

@end

NS_ASSUME_NONNULL_END
