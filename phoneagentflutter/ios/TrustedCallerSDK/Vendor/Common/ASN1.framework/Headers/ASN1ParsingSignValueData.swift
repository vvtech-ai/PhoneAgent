//
//  ASN1ParsingSignValueData.swift
//  ASN1
//
//  Created by ioser on 2021/8/13.
//

import UIKit


@objc public class ASN1ParsingSignValueData: NSObject {
    
    @objc public func parsingSignValueData( _ signValueData: Data) -> Data{
        let input = InputStream(signValueData)
        let mdata = NSMutableData()
        do {
            let ans1s = try ASN1.doBuild(input)as! ASN1Collection
            let ans2s = ans1s.getValue()
            let int1 = ans2s[0] as! ASN1Integer
            let int2 = ans2s[1] as! ASN1Integer
            
            let rByte = int1.asBytes
            mdata.append(rByte, length: 32)
            
            let sByte = int2.asBytes
            mdata.append(sByte, length: 32)
             
        } catch {
            
        }
        
        return mdata as Data
    }
 
}
