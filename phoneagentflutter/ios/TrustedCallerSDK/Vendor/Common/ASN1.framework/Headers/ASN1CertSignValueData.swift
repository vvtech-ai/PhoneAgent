//
//  ASN1CertSignValueData.swift
//  ASN1
//
//  Created by ioser on 2021/8/16.
//

import UIKit

@objc public class ASN1CertSignValueData: NSObject {
    var sequence = ASN1Sequence()
    
    
    /// 0.id
    @objc public func addId( _ id: Data){
        
        let bytes = [UInt8](id)
        sequence.add(ASN1UTF8String(bytes))
    }
    
    /// 1.IDi
    @objc public func addIDi( _ IDi : Data){
        
        let bytes = [UInt8](IDi)
        sequence.add(ASN1UTF8String(bytes))
    }
    
    /// 2.ki
    @objc public func addKi( _ ki : Data){
        
        let bytes = [UInt8](ki)
        sequence.add(ASN1UTF8String(bytes))
    }
    
    /// 3.operateUrl
    @objc public func addOperateUrl( _ operateUrl : Data){
        
        let bytes = [UInt8](operateUrl)
        sequence.add(ASN1UTF8String(bytes))
    }
    
    
    /// 4.operateSignCert
    @objc public func addOperateSignCert( _ operateSignCert : Data){
        
        let bytes = [UInt8](operateSignCert)
        sequence.add(ASN1UTF8String(bytes))
    }
    
    /// 5.operateEncryptionCert
    @objc public func addOperateEncryptionCert( _ operateEncryptionCert : Data){
        
        let bytes = [UInt8](operateEncryptionCert)
        sequence.add(ASN1UTF8String(bytes))
    }
    
    /// 6.serviceManagerCert
    @objc public func addServiceManagerCert( _ serviceManagerCert : Data){
        
        let bytes = [UInt8](serviceManagerCert)
        sequence.add(ASN1UTF8String(bytes))
    }
    
    /// 7.personalCert
    @objc public func addPersonalCert( _ personalCert : Data) -> Data {
        
        let bytes = [UInt8](personalCert)
        sequence.add(ASN1UTF8String(bytes))
        
        
        let tokenInts = sequence.encode()
        let tokenData:Data = Data(bytes: tokenInts, count: tokenInts.count);
        
        return tokenData
    }
    
    
    
}
