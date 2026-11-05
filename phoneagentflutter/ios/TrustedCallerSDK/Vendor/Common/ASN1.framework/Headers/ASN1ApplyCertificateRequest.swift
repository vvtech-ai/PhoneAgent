//
//  ASN1ApplyCertificateRequest.swift
//  ASN1
//
//  Created by 颜祥 on 2021/8/2.
//

import UIKit

@objc public class ASN1ApplyCertificateRequest: NSObject {
    
    var applyCertificateRequest = ASN1Sequence()
    
    /// 0.version
    @objc public func addVersion( _ version: Data){
        
        let bytes = [UInt8](version)
        applyCertificateRequest.add(ASN1Integer(bytes))
    }
    
    /// 1.当前时间
    @objc public func addCurrentTime(time: Date){
        let asnTime = ASN1GeneralizedTime(time)
        applyCertificateRequest.add(asnTime)
    }
    
    /// 2.随机数
    @objc public func addRnd(rnd: Data){
        let bytes = [UInt8](rnd)
        let asnTime = ASN1OctetString(bytes)
        applyCertificateRequest.add(asnTime)
    }
    
    /// 3.设备编号
    @objc public func addDeviceID( _ deviceID: Data){
        let bytes = [UInt8](deviceID)
        applyCertificateRequest.add(ASN1UTF8String(bytes))
    }
    
    /// 4.设备名称
    @objc public func addDeviceName( _ deviceName: Data){
        let bytes = [UInt8](deviceName)
        applyCertificateRequest.add(ASN1UTF8String(bytes))
    }
    
    /// 用户ID
    @objc public func addUserID ( _ userId : Data){
        let bytes = [UInt8](userId)
        applyCertificateRequest.add(ASN1OctetString(bytes))
    }
    
    /// 运营管理分系统签名值
    @objc public func addOmssignvalue ( _ omssignvalue : Data){
        let bytes = [UInt8](omssignvalue)
        let omssign = ASN1OctetString(bytes)
        applyCertificateRequest.add(omssign)
    }
    
     
    ///  运营系统时间戳omsts
    @objc public func addOmsts( _ omsts: Data){
        let bytes = [UInt8](omsts)
        applyCertificateRequest.add(ASN1UTF8String(bytes))
    }
    
    /// 7.用户签名公钥U1
    @objc public func addPublicKeyInfoAlgorithm( _ algorithm: String, publicKey: Data) {
        /// 0.algorithm
//        let algorithmBytes = [UInt8](algorithm)
//        let publicKeyInfo = ASN1Sequence()
//        publicKeyInfo.add(ASN1ObjectIdentifier(algorithmBytes))
        
        //let algorithmBytes = [UInt8](algorithm)
        let publicKeyInfo = ASN1Sequence()
        let algorInfo = ASN1Sequence()
        algorInfo.add(ASN1ObjectIdentifier(algorithm))
        publicKeyInfo.add(algorInfo)
        
        /// 1.publicKey
        let publicKeyBytes = [UInt8](publicKey)
        publicKeyInfo.add(ASN1BitString(publicKeyBytes, 0x00))
        
        applyCertificateRequest.add(publicKeyInfo)
       
    }
    
    /// 8.添加签名值
    @objc public func addSignatureValue( _ signatureValue: Data) {
 
        let signatureBytes = [UInt8](signatureValue)
        applyCertificateRequest.add(ASN1BitString(signatureBytes, 0x00))
    }
    
    /// 9.添加p10
    @objc public func addP10( _ p10: Data){
        let p10Bytes = [UInt8](p10)
        applyCertificateRequest.add(ASN1BitString(p10Bytes, 0x00))
         
    }
    
    /// 身份证号码
    @objc public func addResidenterCardNumber( _ residenterCardNumber: Data){
        let bytes = [UInt8](residenterCardNumber)
        applyCertificateRequest.add(ASN1UTF8String(bytes))
    }
    
   
    /// mediatype 媒体类型
    @objc public func addMediatype( _ mediatype: Data){
        let bytes = [UInt8](mediatype)
        applyCertificateRequest.add(ASN1UTF8String(bytes))
    }
    
    
    
    /// mediaUrl 媒体类型链接
    @objc public func addMediaUrl( _ mediaUrl: Data) {
        let bytes = [UInt8](mediaUrl)
        applyCertificateRequest.add(ASN1UTF8String(bytes))

    }
    
    /// userName 用户姓名
    @objc public func addUserName( _ userName : Data) -> String {
        let bytes = [UInt8](userName)
        applyCertificateRequest.add(ASN1UTF8String(bytes))
        
        let nebytes = applyCertificateRequest.encode()
        let data:Data = Data(bytes: nebytes, count: nebytes.count);
        let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        return base64String
    }
    
}
