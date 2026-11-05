//
//  ASN1ApplyCertParam.swift
//  KXSSDK
//
//  Created by 颜祥 on 2021/6/15.
//  Copyright © 2021 nat. All rights reserved.
//

import Foundation

public class ASN1ApplyCertParam: NSObject {
    var certParam = ASN1Sequence()
    
    /// 0.version
    @objc public func addVersion( _ version: Data){
        certParam = ASN1Sequence()
        
        let bytes = [UInt8](version)
        certParam.add(ASN1UTF8String(bytes))
    }
    
    /// 1.添加当前时间
    @objc public func addCurrentTime(time: Date){
        let asnTime = ASN1GeneralizedTime(time)
        certParam.add(asnTime)
    }
    
    /// 2.随机数
    @objc public func addRnd(rnd: Data){
        let bytes = [UInt8](rnd)
        let asnTime = ASN1OctetString(bytes)
        certParam.add(asnTime)
    }
    
    /// 3.设备编号
    @objc public func addDeviceID( _ deviceID: Data){
        let bytes = [UInt8](deviceID)
        certParam.add(ASN1UTF8String(bytes))
    }
    
    /// 4.设备名称
    @objc public func addDeviceName( _ deviceName: Data){
        let bytes = [UInt8](deviceName)
        certParam.add(ASN1UTF8String(bytes))
    }
    
    /// 5.会话编号
    @objc public func addSessionID ( _ sessionID : Data){
        let bytes = [UInt8](sessionID)
        let session = ASN1OctetString(bytes)
        certParam.add(session)
    }
    
    /// 5.添加PublicKeyInfoAlgorithm
    @objc public func addPublicKeyInfoAlgorithm( _ algorithm: Data, publicKey: Data){
        /// 0.algorithm
        let algorithmBytes = [UInt8](algorithm)
        let token = ASN1Sequence()
        token.add(ASN1ObjectIdentifier(algorithmBytes))
        
        /// 1.publicKey
        let publicKeyBytes = [UInt8](publicKey)
        token.add(ASN1BitString(publicKeyBytes, 0x00))
        
        certParam.add(token)
    }
    
    /// 6.添加签名值
    @objc public func addSignatureValue( _ signatureValue: Data){
 
        let algorithmBytes = [UInt8](signatureValue)
  
        certParam.add(ASN1BitString(algorithmBytes, 0x00))
         
    }
    
    /// 7.p10
    @objc public func addP10( _ p10: Data)-> String{
        let bytes = [UInt8](p10)
        certParam.add(ASN1BitString(bytes, 0x00))
        
        let tokenInts = certParam.encode()
        let tokenData:Data = Data(bytes: tokenInts, count: tokenInts.count);
        let base64String = tokenData.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        return base64String
    }
}
