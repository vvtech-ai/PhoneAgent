//
//  NFCDatePickerView.h
//  ZimDemo
//
//  Created by 汪澌哲 on 2023/6/7.
//  Copyright © 2023 com.alipay. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFCDatePickerView : UIView

@property (nonatomic, copy) void (^onConfirm)(NSDate *);

@property (nonatomic, copy) NSString *maxDate;

- (void)showWithSelectedDate:(NSDate *)selectedDate onConfirm:(void (^)(NSDate *date))onConfirm;

- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
