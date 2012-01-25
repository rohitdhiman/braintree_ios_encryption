#import "BraintreeDecrypt.h"
#import "NSData+Base64.h"
#import "SecKeyWrapper.h"
#import <CommonCrypto/CommonCryptor.h>

@implementation BraintreeDecrypt

+ (NSData*)decryptAES:(NSData*) data withKey:(NSString*)key {
  NSData * decodedKey = [NSData dataWithBase64EncodedString: key];

  NSUInteger ivSize = 4*sizeof(uint32_t);
  NSData * iv = [NSData dataWithBytes:[data bytes] length:ivSize];

  NSData * encryptedData = [data subdataWithRange: NSMakeRange(ivSize, [data length] - ivSize)];
  NSUInteger dataLength = [encryptedData length];

  size_t outputBufferSize = dataLength;
  void * outputBuffer = malloc(outputBufferSize);
  bzero(outputBuffer, outputBufferSize);

  size_t numBytesDecrypted = 0;

  CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                        [decodedKey bytes], kCCKeySizeAES256,
                                        [iv bytes],
                                        [encryptedData bytes], dataLength,
                                        outputBuffer, outputBufferSize,
                                        &numBytesDecrypted);

  if( cryptStatus == kCCSuccess ){
    return [NSData dataWithBytesNoCopy:outputBuffer length:numBytesDecrypted];
  }

  NSLog(@"AES Decrypt: FAIL %d", cryptStatus);

  free( outputBuffer );
  return nil;
}

+ (SecKeyRef) getPrivateKeyRef:(NSString*) privateKey {
  NSMutableDictionary * peerKeyAttr = [[NSMutableDictionary alloc] init];
  NSString * tag = @"com.braintree.private_key_for_testing";
  NSData * peerTag = [tag dataUsingEncoding: NSUTF8StringEncoding ];
  SecKeyRef privateKeyRef = NULL;
  SecKeyWrapper * wrapper = [[SecKeyWrapper alloc] init];
  [wrapper removePeerPublicKey:tag];

  NSData * privateKeyData = [NSData dataWithBase64EncodedString: privateKey];

  [peerKeyAttr setObject:(id)kSecClassKey             forKey:(id)kSecClass];
  [peerKeyAttr setObject:peerTag                      forKey:(id)kSecAttrApplicationTag];
  [peerKeyAttr setObject:(id)kSecAttrKeyTypeRSA       forKey:(id)kSecAttrKeyType];
	[peerKeyAttr setObject:privateKeyData               forKey:(id)kSecValueData];
  [peerKeyAttr setObject:(id)kSecAttrKeyClassPrivate  forKey:(id)kSecAttrKeyClass];
  [peerKeyAttr setObject:(id)kCFBooleanTrue           forKey:(id)kSecReturnRef];

  OSStatus result = SecItemAdd((CFDictionaryRef)peerKeyAttr, (CFTypeRef*)&privateKeyRef);
  NSAssert(result == errSecSuccess, @"keychain item add failure: %ld", result);

  [peerKeyAttr removeObjectForKey:(id)kSecValueData];

  result = SecItemCopyMatching((CFDictionaryRef) peerKeyAttr, (CFTypeRef *)&privateKeyRef);

  NSAssert(privateKeyRef != NULL && result == errSecSuccess, @"keychain data lookup failure: %ld", result);

  [peerKeyAttr release];
  [wrapper release];

  return privateKeyRef;
}

+(NSString *) decryptWithKey:(SecKeyRef)privateKey Data:(NSData*)encryptedData {
  size_t plainTextLen = [encryptedData length];
  uint8_t * plainText = malloc(sizeof(uint8_t)*plainTextLen);
  memset(plainText, 0, plainTextLen);

  SecKeyDecrypt(privateKey,
                kCCOptionPKCS7Padding,
                (const uint8_t*)[encryptedData bytes],
                [encryptedData length],
                plainText,
                &plainTextLen
                );
  NSString * plainStr = [[NSString alloc] initWithBytes:plainText length:plainTextLen encoding:NSUTF8StringEncoding];
  free(plainText);
  return plainStr;
}

@end
