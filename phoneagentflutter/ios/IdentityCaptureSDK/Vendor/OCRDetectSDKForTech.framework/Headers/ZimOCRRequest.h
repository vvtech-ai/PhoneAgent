//
//  ZimOCRRequest.h
//  DTFIdentityManager
//
//  Created by 053508 on 2020/8/26.
//  Copyright © 2020 DTF. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZimOCRRequest : NSObject

@property (nonatomic,strong)NSString *zimId;
@property (nonatomic,strong)NSString *dataType; //数据类型：OSS_ADDR/BASE64_JPG
@property (nonatomic,strong)NSString *dataContext;
@property (nonatomic,strong)NSString *side;/*face: 身份证正面 back: 身份证反面 缺省值是：face*/
@property (nonatomic,strong)NSString *externParam; //扩展信息，预留字段,Map的json格式

@end

NS_ASSUME_NONNULL_END
