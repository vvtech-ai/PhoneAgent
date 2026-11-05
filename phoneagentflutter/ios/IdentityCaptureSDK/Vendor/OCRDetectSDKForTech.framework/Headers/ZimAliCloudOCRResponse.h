//
//  ZimAliCloudOCRResponse.h
//  DTFIdentityManager
//
//  Created by 053508 on 2020/6/22.
//  Copyright © 2020 DTF. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZimOCRResponse.h"
NS_ASSUME_NONNULL_BEGIN

@interface ZimAliCloudOCRResponse : NSObject
@property(nonatomic,strong)ZimOCRResponse *ResultObject;
@property(nonatomic,strong)NSString * RequestId;
@property(nonatomic,strong)NSString * Code;

@end

NS_ASSUME_NONNULL_END
