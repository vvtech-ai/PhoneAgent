//
//  DetectImageForOCRButton.h
//  DTFIdentityManager
//
//  Created by 053508 on 2020/7/7.
//  Copyright © 2020 DTF. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DetectImageForOCRButton : UIButton

+(NSString *) fileFromPath:(NSString*)fileName;

-(void)setBackgroundColorWithColor:(UIColor*)color forState:(UIControlState)state;

@end

NS_ASSUME_NONNULL_END
