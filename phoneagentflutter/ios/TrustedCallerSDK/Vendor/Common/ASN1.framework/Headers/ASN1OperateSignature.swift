//
//  ASN1OperateSignature.swift
//  ASN1
//
//  Created by ioser on 2021/8/16.
//

import UIKit

@objc public class ASN1OperateSignature: NSObject {
    var sequence = ASN1Sequence()
    
    /// 0.serviceSessionKey
    @objc public func addServiceSessionKey( _ serviceSessionKey: Data){
        
        let bytes = [UInt8](serviceSessionKey)
        sequence.add(ASN1UTF8String(bytes))
    }
    
    /// 1.operateUrl
    @objc public func addOperateUrl( _ operateUrl: Data){
        
        let bytes = [UInt8](operateUrl)
        sequence.add(ASN1UTF8String(bytes))
    }
    
    /// 1.sessionId
    @objc public func addSessionId( _ sessionId: Data) -> Data {
        
        let bytes = [UInt8](sessionId)
        sequence.add(ASN1UTF8String(bytes))
        
        let tokenInts = sequence.encode()
        let tokenData:Data = Data(bytes: tokenInts, count: tokenInts.count);
        
        return tokenData
    }
}
