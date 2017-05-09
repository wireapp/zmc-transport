//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


#import "ZMServerTrust.h"
@import WireSystem;
#import <mach-o/dyld.h>

static BOOL verifyServerTrustWithPinnedKeys(SecTrustRef const serverTrust, NSArray *pinnedKeys);

// To dump certificate data, use
//     CFIndex const certCount = SecTrustGetCertificateCount(serverTrust);
// and
//     SecCertificateRef cert0 = SecTrustGetCertificateAtIndex(serverTrust, 0);
//     SecCertificateRef cert1 = SecTrustGetCertificateAtIndex(serverTrust, 1);
// etc. and then
//     SecCertificateCopyData(cert1)
// to dump the certificate data.
//
//
// Also
//     CFBridgingRelease(SecCertificateCopyValues(cert1, @[kSecOIDX509V1SubjectName], NULL))

static SecKeyRef publicKeyFromKeyData(NSData *keyData)
{
    NSDictionary *attributes = @{
                                 (NSString *)kSecAttrKeyType: (NSString *)kSecAttrKeyTypeRSA,
                                 (NSString *)kSecAttrKeyClass: (NSString *)kSecAttrKeyClassPublic,
                                 (NSString *)kSecAttrKeySizeInBits: @(keyData.length * 8)
                                 };
    
    CFErrorRef error = nil;
    SecKeyRef key =  SecKeyCreateWithData((__bridge CFDataRef)keyData, (__bridge CFDictionaryRef)attributes, &error);
    
    return key;
}

static SecKeyRef wirePublicKey()
{
    NSString *base64Key = @"MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAreYzBWuvnVKYfgNNX3dV \
                            jUnqIVtl4XqQnCcY6m/sWM15TTK0bo9FKnMxNAPtDzB6ViRvpZsKEefX8pi15Jcs \
                            4uZiuZ81ISV1bqxtpsjJ56Yjeme99Dca5ck35pThYuK6jZ8vG6pJiY9mRY9nGadi \
                            d4qWL7uwAeoInx2mOM7HepCCh2NOXd+EjQ4sBsfgb+kWrcVQmBzvLHPUDoykm/m+ \
                            BvL2eJ1njPNiM/GoeXbmIW1WM3ifucYJoD9g+V5NfHfANrVu2w4YcLDad0C85Nb8 \
                            U1sgFNkrgOqzhd/1xHok1uOyjoeLTIHHYkryvbBEmdl6v+f2J1EM0+Fj9vseI2TY \
                            rQIDAQAB";
    
    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:base64Key options:NSDataBase64DecodingIgnoreUnknownCharacters];
    SecKeyRef key = publicKeyFromKeyData(keyData);
    
    assert(key != nil);
    
    return key;
}

static SecKeyRef cloudfrontPublicKey()
{
    NSString *base64Key = @"MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAryQICCl6NZ5gDKrnSztO \
                            3Hy8PEUcuyvg/ikC+VcIo2SFFSf18a3IMYldIugqqqZCs4/4uVW3sbdLs/6PfgdX \
                            7O9D22ZiFWHPYA2k2N744MNiCD1UE+tJyllUhSblK48bn+v1oZHCM0nYQ2NqUkvS \
                            j+hwUU3RiWl7x3D2s9wSdNt7XUtW05a/FXehsPSiJfKvHJJnGOX0BgTvkLnkAOTd \
                            OrUZ/wK69Dzu4IvrN4vs9Nes8vbwPa/ddZEzGR0cQMt0JBkhk9kU/qwqUseP1QRJ \
                            5I1jR4g8aYPL/ke9K35PxZWuDp3U0UPAZ3PjFAh+5T+fc7gzCs9dPzSHloruU+gl \
                            FQIDAQAB";
    
    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:base64Key options:NSDataBase64DecodingIgnoreUnknownCharacters];
    SecKeyRef key = publicKeyFromKeyData(keyData);
    
    assert(key != nil);
    
    return key;
}

BOOL verifyServerTrust_(SecTrustRef const serverTrust, NSString *host)
{
    NSArray *pinnedKeys;
    
    if ([host hasSuffix:@"cloudfront.net"]) {
        pinnedKeys = @[CFBridgingRelease(cloudfrontPublicKey())];
    } else {
        pinnedKeys = @[CFBridgingRelease(wirePublicKey())];
    }
    
    return verifyServerTrustWithPinnedKeys(serverTrust, pinnedKeys);
}

static NSArray * publicKeysAssociatedWithServerTrust(SecTrustRef const serverTrust)
{
    CFIndex const certCount = SecTrustGetCertificateCount(serverTrust);
    NSMutableArray *publicKeys = [NSMutableArray array];
    SecPolicyRef policy = SecPolicyCreateBasicX509();
    
    for (CFIndex i = 0; i < certCount; i++) {
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, i);
        
        SecCertificateRef certificatesCArray[] = { certificate};
        CFArrayRef certificates = CFArrayCreate(NULL, (const void **)certificatesCArray, 1, NULL);
        
        SecTrustRef trust;
        require_noerr_quiet(SecTrustCreateWithCertificates(certificates, policy, &trust), _error);
        
        SecTrustResultType result;
        require_noerr_quiet(SecTrustEvaluate(trust, &result), _error);
        
        SecKeyRef key = SecTrustCopyPublicKey(trust);
        
        if (key != nil) {
            [publicKeys addObject:CFBridgingRelease(key)];
        }
        
        _error:
        
        if (certificates) {
            CFRelease(certificates);
        }
    
        if (trust) {
            CFRelease(trust);
        }
    }
    
    CFRelease(policy);
    
    return publicKeys;
}

static BOOL verifyServerTrustWithPinnedKeys(SecTrustRef const serverTrust, NSArray *pinnedKeys)
{
    SecTrustResultType result;
    if (SecTrustEvaluate(serverTrust, &result) != noErr) {
        return NO;
    }
    
    NSArray *publicKeys =  publicKeysAssociatedWithServerTrust(serverTrust);
    NSInteger matchingKeyCount = 0;
    
    for (id publicKey in publicKeys) {
        for (id pinnedKey in pinnedKeys) {
            if ([publicKey isEqual:pinnedKey]) {
                matchingKeyCount += 1;
            }
        }
    }
    
    return matchingKeyCount > 0;
}
