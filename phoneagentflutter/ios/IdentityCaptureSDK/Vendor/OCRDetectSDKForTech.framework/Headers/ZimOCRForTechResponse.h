//
//  ZimOCRForTechResponse.h
//  DTFIdentityManager
//
//  Created by 053508 on 2020/8/26.
//  Copyright © 2020 DTF. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZimOCRForTechResponse : NSObject

@property (nonatomic,strong) NSString* zimId;
@property (nonatomic,strong) NSString* side;
@property (nonatomic,strong) NSString* ocrInfo;
@property (nonatomic,strong) NSString* retCodeSub;
@property (nonatomic,strong) NSString* retMessageSub;
@property (nonatomic,strong) NSString* externInfo;
@property (nonatomic,strong) NSString* retCode;

@end

NS_ASSUME_NONNULL_END
