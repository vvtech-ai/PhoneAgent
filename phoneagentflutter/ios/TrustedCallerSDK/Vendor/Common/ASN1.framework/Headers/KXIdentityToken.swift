//
//  KXIdentityToken.swift
//  ASN1
//
//  Created by user on 2021/4/26.
//

import Foundation
@objc public class KXIdentityToken  : NSObject
{
    var identityToken = ASN1Sequence()
    // 添加当前时间
    @objc public func addtime(time: Date){
        identityToken = ASN1Sequence()
        //ASN1GeneralizedTime
    
        let asnTime = ASN1GeneralizedTime(time)
        identityToken.add(asnTime)
    }
    
    // 添加tokenIndex
    @objc public func addTokenIndex( _ tokenIndex: Data) -> String{
        let bytes = [UInt8](tokenIndex)
 
        let asnTime = ASN1OctetString(bytes)
        identityToken.add(asnTime)
        
        // 返回生成的通讯令牌
        let tokenInts = identityToken.encode()
        let tokenData:Data = Data(bytes: tokenInts, count: tokenInts.count);
        let base64String = tokenData.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        return base64String
    }
    
    
    // 添加message
    @objc public func addMessage( _ message: Data){
        let bytes = [UInt8](message)
        identityToken.add(ASN1UTF8String(bytes))
    }
    
    // 添加calledExtensionNumber
    @objc public func addCalledExtensionNumber( _ num: Data){
        let bytes = [UInt8](num)
        identityToken.add(ASN1PrintableString(bytes))
    }
    
    // 添加signatureAlgorithm
    @objc public func addSignatureAlgorithm( _ identifier: String){
        
        let token = ASN1Sequence()
        token.add(ASN1ObjectIdentifier(identifier))
        
        identityToken.add(token)
    }
    
    // 添加signatureValue
    @objc public func addSignatureValue( _ signatureValue: Data){
        let bytes = [UInt8](signatureValue)
        identityToken.add(ASN1BitString(bytes, 0x00))
    }
    
    // 添加credential
    @objc public func addCredential( _ credential: Data) -> String{
        
        let bytes = [UInt8](credential)
        identityToken.add(ASN1OctetString(bytes))
        
        // 返回生成的通讯令牌
        let tokenInts = identityToken.encode()
        let tokenData:Data = Data(bytes: tokenInts, count: tokenInts.count);
        let base64String = tokenData.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        return base64String
    }
    
    
    // 凭证的序列号
    @objc public func addSerialNumber( _ serialNumber: Data ) -> String{
        
        let bytes = [UInt8](serialNumber)
        identityToken.add(ASN1Integer(bytes))
        let tokenInts = identityToken.encode()
        let tokenData:Data = Data(bytes: tokenInts, count: tokenInts.count);
        let base64String = tokenData.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
  
        print("添加addSerialNumber=="+base64String)
        return base64String
    }
    
    
    //TBSIdentityToken
    @objc public func addTBSToken( time: Date ,becalled: Data,called: Data,message: Data)  -> String{
      
        let becalledBytes = [UInt8](becalled)
        let calledBytes = [UInt8](called)
        let messageBytes = [UInt8](message)
        
        // 签名时时间
        let timee = ASN1GeneralizedTime(time)
        // 被叫号码
        let becalleds = ASN1PrintableString(becalledBytes)
        // 主叫号码
        let calleds = ASN1PrintableString(calledBytes)
        // 呼叫的目的
        let messages = ASN1UTF8String(messageBytes)
        
        let token = ASN1Sequence()
        token.add(timee)
        token.add(becalleds)
        token.add(calleds)
        token.add(messages)
         
        print(token.description)
        let tokenInts = token.encode()
        let tokenData:Data = Data(bytes: tokenInts, count: tokenInts.count);
        let base64String = tokenData.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        print(base64String)
        return base64String
    }
    
 
}
