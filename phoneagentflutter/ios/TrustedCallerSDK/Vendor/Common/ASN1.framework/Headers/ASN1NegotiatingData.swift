//
//  ASN1NegotiatingData.swift
//  ASN1
//
//  Created by 颜祥 on 2021/8/2.
//

import UIKit

@objc public class ASN1NegotiatingData: NSObject {
    
    var negotiatingData = ASN1Sequence()

    /// 0.tag
    @objc public func addTag( _ tag: Data){
        
        let bytes = [UInt8](tag)
        negotiatingData.add(ASN1PrintableString(bytes))
    }
    
    /// 1.提供服务的地址
    @objc public func addUri( _ uri: Data){
        let bytes = [UInt8](uri)
        negotiatingData.add(ASN1UTF8String(bytes))
    }
    
    /// 2.当前时间
    @objc public func addCurrentTime(time: Date){
        let asnTime = ASN1GeneralizedTime(time)
        negotiatingData.add(asnTime)
    }
    
    /// 3.随机数
    @objc public func addRnd(rnd: Data){
        let bytes = [UInt8](rnd)
        let asnTime = ASN1OctetString(bytes)
        negotiatingData.add(asnTime)
    }
    
    /// 4.设备编号
    @objc public func addDeviceID( _ deviceID: Data){
        let bytes = [UInt8](deviceID)
        negotiatingData.add(ASN1UTF8String(bytes))
    }
    
    /// 5.设备名称
    @objc public func addDeviceName( _ deviceName: Data){
        let bytes = [UInt8](deviceName)
        negotiatingData.add(ASN1UTF8String(bytes))
    }
    
    /// 6.会话编号
    @objc public func addSessionID ( _ sessionID : Data){
        let bytes = [UInt8](sessionID)
        let session = ASN1OctetString(bytes)
        negotiatingData.add(session)
    }
    
    /// 7.用户ID
    @objc public func addUserId ( _ userId : Data){
        let bytes = [UInt8](userId)
        let userid = ASN1OctetString(bytes)
        negotiatingData.add(userid)
    }
    
    
    /// 7.子系统编号
    @objc public func addSubsystemno ( _ subsystemno : Data){
        let bytes = [UInt8](subsystemno)
        let subsystem = ASN1OctetString(bytes)
        negotiatingData.add(subsystem)
    }
    
    /// 7.运营管理分系统签名值
    @objc public func addOmssignvalue ( _ omssignvalue : Data){
        let bytes = [UInt8](omssignvalue)
        let omssign = ASN1OctetString(bytes)
        negotiatingData.add(omssign)
    }
    
     
    ///  运营系统时间戳omsts
    @objc public func addOmsts( _ omsts: Data){
        let bytes = [UInt8](omsts)
        negotiatingData.add(ASN1UTF8String(bytes))
    }
    
    
//    /// 8.激活码
//    @objc public func addActivationCode( _ activationCode: Data){
//
//        let bytes = [UInt8](activationCode)
//        negotiatingData.add(ASN1PrintableString(bytes))
//    }
    
    /// 9.认证码
    @objc public func addVerificationCode( _ verificationCode: Data){
        
        let bytes = [UInt8](verificationCode)
        negotiatingData.add(ASN1PrintableString(bytes))
    }
    
    
    /// h1    sm3(idcard|companyname|name)
    @objc public func addH1( _ h1: Data){
        let bytes = [UInt8](h1)
        negotiatingData.add(ASN1OctetString(bytes))
    }
    
    
    
    /// 13.手机号码
    @objc public func addTelephoneNumber( _ telephoneNumber: Data){
        let bytes = [UInt8](telephoneNumber)
        negotiatingData.add(ASN1PrintableString(bytes))
    }
    
    /// 14.用户签名公钥U1
    @objc public func addPublicKeyInfoAlgorithm( _ algorithm: String, publicKey: Data) {

        let publicKeyInfo = ASN1Sequence()
        let algorInfo = ASN1Sequence()
        algorInfo.add(ASN1ObjectIdentifier(algorithm))
        publicKeyInfo.add(algorInfo)

        /// 1.publicKey
        let publicKeyBytes = [UInt8](publicKey)
        publicKeyInfo.add(ASN1BitString(publicKeyBytes, 0x00))
//        publicKeyInfo.add(ASN1BitString(publicKeyBytes, 0x00))
         
        negotiatingData.add(publicKeyInfo)

    }
    
    /// 身份证号码
    @objc public func addResidenterCardNumber( _ residenterCardNumber: Data){
        let bytes = [UInt8](residenterCardNumber)
        negotiatingData.add(ASN1UTF8String(bytes))
    }
    
   
    /// mediatype 媒体类型
    @objc public func addMediatype( _ mediatype: Data){
        let bytes = [UInt8](mediatype)
        negotiatingData.add(ASN1UTF8String(bytes))
    }
    
    
    
    /// mediaUrl 媒体类型链接
    @objc public func addMediaUrl( _ mediaUrl: Data) {
        let bytes = [UInt8](mediaUrl)
        negotiatingData.add(ASN1UTF8String(bytes))
     
    }

    
    /// userName 用户姓名
    @objc public func addUserName( _ userName : Data) -> String {
        let bytes = [UInt8](userName)
        negotiatingData.add(ASN1UTF8String(bytes))
        
        let nebytes = negotiatingData.encode()
        let data:Data = Data(bytes: nebytes, count: nebytes.count);
        let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        return base64String
    }
    
}
