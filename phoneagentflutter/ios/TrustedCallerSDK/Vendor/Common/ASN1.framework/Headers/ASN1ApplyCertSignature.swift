//
//  ASN1ApplyCertSignature.swift
//  KXSSDK
//
//  Created by 颜祥 on 2021/6/15.
//  Copyright © 2021 nat. All rights reserved.
//

import Foundation

public class ASN1ApplyCertSignature: NSObject {
    var certSignature = ASN1Sequence()
    
    /// 0.添加tag
    @objc public func addTag( _ tag: Data){
        certSignature = ASN1Sequence()
        
        let bytes = [UInt8](tag)
        certSignature.add(ASN1PrintableString(bytes))
    }
    
    /// 1.添加提供服务的地址
    @objc public func addUri( _ uri: Data){
        let bytes = [UInt8](uri)
        certSignature.add(ASN1UTF8String(bytes))
    }
    
    /// 2.添加当前时间
    @objc public func addCurrentTime(time: Date){
        let asnTime = ASN1GeneralizedTime(time)
        certSignature.add(asnTime)
    }
    
    /// 3.随机数
    @objc public func addRnd(rnd: Data){
        let bytes = [UInt8](rnd)
        let asnTime = ASN1OctetString(bytes)
        certSignature.add(asnTime)
    }
    
    /// 4.设备编号
    @objc public func addDeviceID( _ deviceID: Data){
        let bytes = [UInt8](deviceID)
        certSignature.add(ASN1UTF8String(bytes))
    }
    
    /// 5.设备名称
    @objc public func addDeviceName( _ deviceName: Data){
        let bytes = [UInt8](deviceName)
        certSignature.add(ASN1UTF8String(bytes))
    }
    
    /// 6.会话编号
    @objc public func addSessionID ( _ sessionID : Data){
        let bytes = [UInt8](sessionID)
        let session = ASN1OctetString(bytes)
        certSignature.add(session)
    }
    
    /// 5.验证码
    @objc public func addVerificationCode( _ verificationCode: Data){
        let bytes = [UInt8](verificationCode)
        certSignature.add(ASN1PrintableString(bytes))
    }
    
    /// 6.姓名
    @objc public func addName( _ name: Data){
        let bytes = [UInt8](name)
        certSignature.add(ASN1UTF8String(bytes))
    }
    
    /// 7.身份证号码
    @objc public func addResidenterCardNumber( _ residenterCardNumber: Data){
        let bytes = [UInt8](residenterCardNumber)
        certSignature.add(ASN1PrintableString(bytes))
    }
    
    /// 8.单位
    @objc public func addOrganization( _ organization: Data){
        let bytes = [UInt8](organization)
        certSignature.add(ASN1UTF8String(bytes))
    }
    
    /// 9.手机号码
    @objc public func addTelephoneNumber( _ telephoneNumber: Data){
        let bytes = [UInt8](telephoneNumber)
        certSignature.add(ASN1PrintableString(bytes))
    }
    
    /// 10.添加PublicKeyInfoAlgorithm
    @objc public func addPublicKeyInfoAlgorithm( _ algorithm: Data, publicKey: Data){
        /// 0.algorithm
        let algorithmBytes = [UInt8](algorithm)
        let token = ASN1Sequence()
        token.add(ASN1ObjectIdentifier(algorithmBytes))
        
        /// 1.publicKey
        let publicKeyBytes = [UInt8](publicKey)
        token.add(ASN1BitString(publicKeyBytes, 0x00))
        
        certSignature.add(token)
    }
    
    /// 11.p10
    @objc public func addP10( _ p10: Data)-> String{
        let bytes = [UInt8](p10)
        certSignature.add(ASN1BitString(bytes, 0x00))
        
        let tokenInts = certSignature.encode()
        let tokenData:Data = Data(bytes: tokenInts, count: tokenInts.count);
        let base64String = tokenData.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        return base64String
    }
    
}
