//
//  ASN1ParsingCertData.swift
//  kexinDemo
//
//  Created by user on 2021/6/23.
//  Copyright © 2021 nat. All rights reserved.
//

import UIKit

@objc public class ASN1ParsingCertData: NSObject {
       // 解析
       @objc public func parsingCredential( _ credential: Data) -> String{
   
           let input = InputStream(credential)
           let dic = NSMutableDictionary ()
           do {
               let ans1s = try ASN1.doBuild(input) as! ASN1Collection
               let ans2s = ans1s.getValue()
               let ass =  ans2s[1] as! ASN1Sequence
               
               var num = 0
               let asns = ass.getValue()
            
               for obj in asns {
                  let str = obj as! ASN1UTF8String
                  let data =   String(bytes: str.value, encoding: .utf8)
                    
                  if(asns.count == 5){
                     
                    if(num == 0){
                        dic.setValue(data, forKey: "certContent")
                    }else if(num == 1){
                        dic.setValue(data, forKey: "certId")
                    }else if(num == 2){
                        dic.setValue(data, forKey: "ki")
                    }else if(num == 3){
                        dic.setValue(data, forKey: "id")
                    }else if(num == 4){
                        dic.setValue(data, forKey: "Idi")
                    }
                  }else if(asns.count == 4){
                    // 证书链修改ki传输规则
                    if(num == 0){
                        dic.setValue(data, forKey: "certContent")
                    }else if(num == 1){
                        dic.setValue(data, forKey: "certId")
                    }else if(num == 2){
                        dic.setValue(data, forKey: "kiEncode")
                    }else if(num == 3){
                        dic.setValue(data, forKey: "id")
                    }
                  }
                   
                   num =  num + 1
               }
           } catch {
                   
           }
          
           let data = try? JSONSerialization.data(withJSONObject: dic, options: JSONSerialization.WritingOptions.init(rawValue: 0))
           let jsonStr = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
           return jsonStr! as String
        
       }
    
    
    
    
    // 扫码数据解析
    @objc public func scanCredential( _ credential: Data) -> NSMutableDictionary{

        let input = InputStream(credential)
        let dic = NSMutableDictionary()
        do {
            let ans1s = try ASN1.doBuild(input) as! ASN1Collection
            let ans2s = ans1s.getValue()
            
            var num = 0
         
            for obj in ans2s {
        
                 if(num == 0){
                    let str = obj as! ASN1OctetString
                    
                     let nebytes =  str.value
                     let data:Data = Data(bytes: nebytes, count: nebytes.count);
                     let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
                     dic.setValue(base64String, forKey: "qrrandnum")
                 }else if(num == 1){
                    let str = obj as! ASN1OctetString
                    let nebytes =  str.value
                    let data:Data = Data(bytes: nebytes, count: nebytes.count);
                    let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
                    dic.setValue(base64String, forKey: "qrsignvalue")
                 }else if(num == 2){
                    let str = obj as! ASN1OctetString
                    let data =   String(bytes: str.value, encoding: .utf8)
                     dic.setValue(data, forKey: "sessionID")
                 }
                num =  num + 1
            }
        } catch {
                
        }
       
        return dic
        
//        let data = try? JSONSerialization.data(withJSONObject: dic, options: JSONSerialization.WritingOptions.init(rawValue: 0))
//        let jsonStr = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
//        return jsonStr! as String
     
    }
    
    
    // 扫码后添加返回数据解析
    @objc public func scanCredentialReturn( _ credential: Data) -> Bool{

        let input = InputStream(credential)
        do {
            let ans1s = try ASN1.doBuild(input)as! ASN1Collection
            let ans2s = ans1s.getValue()
            let str = ans2s[0] as! ASN1Boolean
            
            if(str.value){
                
                return true;
            }else{
                return false;
              
            }
             
        } catch {
            return false;
        }
     
    }

    
    
//    // 签名后数据处理
    @objc public func processSignature( _ r: Data , s: Data) -> String{

        let r1 = [UInt8](r)
        print("签名后r1\(r1)")
//        let r2 = asn1IntegerByte(r1)
//        let r2 = asn1IntegerByte1(r1)
        let r2 = asnIntegerByte(r1)
        
        let r3 = BInt.init(signed: r2)
//        print("签名后r2\(r2)")
        let r4 = ASN1Integer(r3)
        print("签名后r4\(r4)")
        let s1 = [UInt8](s)
        print("签名后s1\(s1)")
//        let s2 = asn1IntegerByte(s1)
//        let s2 = asn1IntegerByte1(s1)
        let s2 = asnIntegerByte(s1)
        let s3 = BInt.init(signed: s2)
//        print("签名后s2\(s2)")
        let s4 = ASN1Integer(s3)
        print("签名后s4\(s4)")

        let en = ASN1Sequence()
        en.add(r4)
        en.add(s4)

        let nebytes = en.encode()
        let data:Data = Data(bytes: nebytes, count: nebytes.count);
        let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        return base64String

    }
    
    //    // 下载身份签名后数据处理
        @objc public func downSignature( _ r: Data , s: Data) -> String{

            let r1 = [UInt8](r)
            print("签名后r1\(r1)")
            let r2 = asn1IntegerByte1(r1)
            
            
            let r3 = BInt.init(signed: r2)
    //        print("签名后r2\(r2)")
            let r4 = ASN1Integer(r3)
            print("签名后r4\(r4)")
            let s1 = [UInt8](s)
            print("签名后s1\(s1)")
            let s2 = asn1IntegerByte1(s1)
        
            let s3 = BInt.init(signed: s2)
    //        print("签名后s2\(s2)")
            let s4 = ASN1Integer(s3)
            print("签名后s4\(s4)")

            let en = ASN1Sequence()
            en.add(r4)
            en.add(s4)

            let nebytes = en.encode()
            let data:Data = Data(bytes: nebytes, count: nebytes.count);
            let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
            return base64String

        }
    
    
    // 解析证书公钥
        @objc public func certPublicKeyString( _ publicKey: Data) -> String{

            let input = InputStream(publicKey)
            
            do {
                let ans1s = try ASN1.doBuild(input) as! ASN1Collection
                let ans2s = ans1s.getValue()
                let ass =  ans2s[1] as! ASN1BitString
                var nebytes = ass.bits
                nebytes.remove(at: 0)
                let data:Data = Data(bytes: nebytes, count: nebytes.count);
                
                let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
                return base64String
            } catch {
                    
            }
            return ""
         
        }
     
    
    // 删除第一个0和补位到32
    @objc public func asn1IntegerByte( _ data: Bytes) -> Bytes{
        var bytes = data
        if(data[0] == 0 && data.count > 32){
            bytes.remove(at: 0)
        }else if(data.count < 32){
            var byteArray:[Byte] = [Byte]()
            let num = 32 - data.count
            for i in 0..<num {
                let temp:Byte = 0
                byteArray.append(temp)
            }
            bytes = byteArray + data
        }
        return bytes
    }
    
    
    
    // SM2结果转换
    @objc public func sm2ResultsParsing( _ data: Data) -> String{
        
        let input = InputStream(data)
        
        do {
            let ans1s = try ASN1.doBuild(input) as! ASN1Collection
            let ans2s = ans1s.getValue()
            let ass =  ans2s[0] as! ASN1Integer
            var assbytes = ass.asBytes
            assbytes = asn1IntegerByte(assbytes)
 
            let ass1 =  ans2s[1] as! ASN1Integer
            var ass1bytes = ass1.asBytes
//            ass1bytes.remove(at: 0)
            ass1bytes = asn1IntegerByte(ass1bytes)
            let ass2 =  ans2s[2] as! ASN1OctetString
            let ass2bytes = ass2.value
            let ass3 =  ans2s[3] as! ASN1OctetString
            let ass3bytes = ass3.value
            let nebytes = [0x04] + assbytes + ass1bytes + ass2bytes + ass3bytes
            
            let data:Data = Data(bytes: nebytes, count: nebytes.count);
            
            let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
            return base64String
        } catch {
                
        }
        return ""
        
    }
    
    // 从P10中获取公钥
    @objc public func p10GetKey( _ data: Data) -> String{
        

        do {
            let input = InputStream(data)
            let ans1s = try ASN1.doBuild(input) as! ASN1Collection
            let ans2s = ans1s.getValue()
            if(ans2s.count > 0){
                let asst =  ans2s[0] as! ASN1Sequence
                let assts = asst.getValue()
                if(assts.count > 2){
                    let ass1 =  assts[2] as! ASN1Sequence
                    
                    let ass1s = ass1.getValue()
                    if(ass1s.count > 1){
                        let ass =  ass1s[1] as! ASN1BitString
                        let nebytes1 = ass.bits
                        let bData:Data = Data(bytes: nebytes1, count: nebytes1.count);
                        let base64String = bData.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
                        
                        return base64String
                    }
                }
            }
        } catch {
            print("从P10中获取公钥失败")
        }
        return ""
        
    }
    
 
    
    // ECC签名后数据转换
    @objc public func signToBitString( _ data: Data) -> String{
        
        let input = InputStream(data)
        
        do {
            let ans1s = try ASN1.doBuild(input) as! ASN1Collection
            let ans2s = ans1s.getValue()
            let ass =  ans2s[0] as! ASN1Integer
            var assbytes = ass.asBytes
            assbytes = asn1IntegerByte1(assbytes)
            let r2 = BInt.init(signed: assbytes)
            
            let ass1 =  ans2s[1] as! ASN1Integer
            var ass1bytes = ass1.asBytes
            ass1bytes = asn1IntegerByte1(ass1bytes)
            let s2 = BInt.init(signed: ass1bytes)
            
            let r3 = ASN1Integer(r2)
            let s3 = ASN1Integer(s2)
            let en = ASN1Sequence()
            en.add(r3)
            en.add(s3)
            
            let nebytes = en.encode()
            let data:Data = Data(bytes: nebytes, count: nebytes.count);
            
            let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
            return base64String
        } catch {
                
        }
        return ""
        
    }
    
   
    
    // 导入证书ECC签名后数据转换
    @objc public func careSignToBitString( _ data: Data) -> String{
        
        let input = InputStream(data)
        
        do {
            let ans1s = try ASN1.doBuild(input) as! ASN1Collection
            let ans2s = ans1s.getValue()
            let ass =  ans2s[0] as! ASN1Integer
            var assbytes = ass.asBytes
             assbytes = asn1IntegerByte(assbytes)
            
            let ass1 =  ans2s[1] as! ASN1Integer
            var ass1bytes = ass1.asBytes
             ass1bytes = asn1IntegerByte(ass1bytes)
          
            let nebytes = assbytes + ass1bytes;
      
            let data:Data = Data(bytes: nebytes, count: nebytes.count);
            
            let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
            return base64String
        } catch {
                
        }
        return ""
        
    }
    
    // 解析推送消息的签名值数据转换
    @objc public func parsePushNotiSignToData( _ data: Data) -> String{
        
        let input = InputStream(data)
        
        do {
            let ans1s = try ASN1.doBuild(input) as! ASN1Collection
            let ans2s = ans1s.getValue()
            let ass =  ans2s[0] as! ASN1Integer
            var assbytes = ass.asBytes
             assbytes = asn1IntegerByte(assbytes)
            
            let ass1 =  ans2s[1] as! ASN1Integer
            var ass1bytes = ass1.asBytes
             ass1bytes = asn1IntegerByte(ass1bytes)
          
            let nebytes = assbytes + ass1bytes;
      
            let data:Data = Data(bytes: nebytes, count: nebytes.count);
            
            let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
            return base64String
        } catch {
                
        }
        return ""
        
    }
    
    @objc public func parseSignToData( _ r: Data , s: Data) -> String{
        
        do {

            let r1 = [UInt8](r)
            let r2 = asn1IntegerByte(r1)
            let r3 = BInt.init(signed: r2)
            let r4 = ASN1Integer(r3)

            let s1 = [UInt8](s)
            let s2 = asn1IntegerByte(s1)
            let s3 = BInt.init(signed: s2)
            let s4 = ASN1Integer(s3)


            let en = ASN1Sequence()
            en.add(r4)
            en.add(s4)

            let nebytes = en.encode()
            let data:Data = Data(bytes: nebytes, count: nebytes.count);
            let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
            return base64String
            
        } catch {
            return ""
        }
        return ""
        
    }
    // 前面加一位0
    @objc public func asnIntegerByte( _ data: Bytes) -> Bytes{
        var bytes = data
        
        var byteArray:[Byte] = [Byte]()
        if(data.count < 32){
            let num = 32 - data.count
            for _ in 0..<num {
                let temp:Byte = 0
                byteArray.insert(temp, at: 0)
            }
            bytes = byteArray + bytes
        }else{
            return bytes
        }
            
         
        return bytes
    }
    
    
    
    // 处理前导零 前面加一位0
    @objc public func asn1IntegerByte1( _ data: Bytes) -> Bytes{
//        var dataBytes = [UInt8](data)
//          if dataBytes.first ?? 0 >= 0x80 {
//              dataBytes.insert(0x00, at: 0)
//              
//          }
//        return dataBytes
//            
        
        var bytes = data
            var byteArray:[Byte] = [Byte]()
            let num = 33 - data.count
//            for i in 0..<num {
                let temp:Byte = 0
                byteArray.append(temp)
//            }
            bytes = byteArray + bytes
         
        return bytes
         
    }
    
    
    
    
    /// 字符串 转为ASN1ObjectIdentifier
    @objc public func stringToObjectIdentifier( _ string: String)  -> String{

        let obj = ASN1ObjectIdentifier(string)
     
        let nebytes = obj.encode()
        let data:Data = Data(bytes: nebytes, count: nebytes.count);
        let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        return base64String

    }
    
    ///  手机号码保存
    @objc public func phoneToOctetString( _ string: String)  -> String{
        
        let bytes = [UInt8](string.utf8)
        
        let num = ASN1OctetString(bytes)
        
        let nebytes = num.encode()
        
        let num1 = ASN1OctetString(nebytes)
        let nebytes1 = num1.encode()
        let data:Data = Data(bytes: nebytes, count: nebytes.count);
        let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        return base64String
        
    }
    
    
    ///  媒体数据
    @objc public func mediaDataToString( _ url: String , data :Data ,type:String ,purl: String , pdata :Data ,ptype:String)  -> String{
        
        let en1 = ASN1Sequence()
        
        if(url.count > 1){
            
            /// 公司头像
            let bytes = [UInt8](url.utf8)
            let url1 = ASN1UTF8String(bytes)
            
            let bytes1 = [UInt8](data)
            let data1 = ASN1OctetString(bytes1)
            
            let en = ASN1Sequence()
            en.add(url1)
            en.add(data1)
            
            let ctx = ASN1Ctx(0x00, [en])
            
            let typeString = ASN1ObjectIdentifier(type)
            
            let ctx1 = ASN1Ctx(0x00, [typeString,ctx])
            
            en1.add(ctx1)
            
        }
        
         
        /// 个人头像
        if(purl.count > 1){
            let pbytes = [UInt8](purl.utf8)
            let url2 = ASN1UTF8String(pbytes)
            
            let bytes2 = [UInt8](pdata)
            let data2 = ASN1OctetString(bytes2)
            
            let en2 = ASN1Sequence()
            en2.add(url2)
            en2.add(data2)
            
            let ctx2 = ASN1Ctx(0x00, [en2])
            
            let typeString1 = ASN1ObjectIdentifier(ptype)
            
            let ctx3 = ASN1Ctx(0x00, [typeString1,ctx2])
            en1.add(ctx3)
        }
        
        
        
        let nebytes1 = en1.encode()
        let data:Data = Data(bytes: nebytes1, count: nebytes1.count);
        let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        return base64String
        
    }
    
    // 测试数据转换
    @objc public func textToBitString( _ data: Data) -> String{
        
        let input = InputStream(data)
        
        do {
            let ans1s = try ASN1.doBuild(input) as! ASN1Collection
            let ans2s = ans1s.getValue()
            let ass =  ans2s[0] as! ASN1Ctx
            let assbytes = ass.value
            let a0 = assbytes?[0] as! ASN1ObjectIdentifier
            let a1 = assbytes?[1] as! ASN1Ctx
            let a2 = a1.value
            let a3 =  a2?[0] as! ASN1Sequence
            var a4 = a3.getValue()
            let a5 =  a4[0] as! ASN1UTF8String
            let a6 =  a4[1] as! ASN1OctetString
            
      
            
            let nebytes = a3.encode()
            let data:Data = Data(bytes: nebytes, count: nebytes.count);
            
            let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
            return base64String
        } catch {
                
        }
        return ""
        
    }
  
    // 服务器SM2加密KI结果转换
    @objc public func kiResultToString( _ data: Data) -> String{
    
        var bytes = [UInt8](data)
        bytes.remove(at: 0)
        let b1 = Array(bytes[0...31])
        let b2 = Array(bytes[32...63])
        let b3 = Array(bytes[64...95])
        let b4 = Array(bytes[96...bytes.count-1])
        
        
        let ii1 = asn1IntegerByte1(b1)
        let i1 = BInt.init(signed: ii1)
    
        let r = ASN1Integer(i1)
        
        let ii2 = asn1IntegerByte1(b2)
        let i2 = BInt.init(signed: ii2)
        let s = ASN1Integer(i2)
        
    
        let o1 = ASN1OctetString(b3)
        let o2 = ASN1OctetString(b4)
        
        var sequence = ASN1Sequence()
        sequence.add(r)
        sequence.add(s)
        sequence.add(o1)
        sequence.add(o2)
         
        do {
            let nebytes = sequence.encode()
            let data:Data = Data(bytes: nebytes, count: nebytes.count);
            
            let base64String = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
            return base64String
        } catch {
            return ""
        }
        return ""
        
    }
    
}
