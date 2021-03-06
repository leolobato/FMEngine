//
//  FMEngine.m
//  LastFMAPI
//
//  Created by Nicolas Haunold on 4/26/09.
//  Copyright 2009 Tapolicious Software. All rights reserved.
//

#import "FMEngine.h"
#import "FMCallback.h"
#import "FMEngineURLConnection.h"

@interface FMEngine ()
@property (nonatomic, readonly) NSOperationQueue *queue;
@end

@implementation FMEngine

@synthesize queue = _queue;

static NSInteger sortAlpha(NSString *n1, NSString *n2, void *context) {
	return [n1 caseInsensitiveCompare:n2];
}

- (id)init {
	if (self = [super init]) {
		connections = [[NSMutableDictionary alloc] init];
	}
	return self;	
}

- (NSString *)generateAuthTokenFromUsername:(NSString *)username password:(NSString *)password {
	NSString *unencryptedToken = [NSString stringWithFormat:@"%@%@", username, [password md5sum]];
	return [unencryptedToken md5sum];
}

- (void)performMethod:(NSString *)method withTarget:(id)target withParameters:(NSDictionary *)params andAction:(SEL)callback useSignature:(BOOL)useSig httpMethod:(NSString *)httpMethod {
	NSString *dataSig;
	NSMutableURLRequest *request;
	NSMutableDictionary *tempDict = [[NSMutableDictionary alloc] initWithDictionary:params];
	
	[tempDict setObject:method forKey:@"method"];
	if(useSig == TRUE) {
		dataSig = [self generateSignatureFromDictionary:tempDict];
		
		[tempDict setObject:dataSig forKey:@"api_sig"];
	}
	
	#ifdef _USE_JSON_
	if(![httpMethod isPOST]) {
		[tempDict setObject:@"json" forKey:@"format"];
	}

	#endif
	
	params = [NSDictionary dictionaryWithDictionary:tempDict];
    
	if(![httpMethod isPOST]) {
		NSURL *dataURL = [self generateURLFromDictionary:params];
		request = [NSURLRequest requestWithURL:dataURL];
	} else {
		#ifdef _USE_JSON_
		request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:[_LASTFM_BASEURL_ stringByAppendingString:@"?format=json"]]];
		#else 
		request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:_LASTFM_BASEURL_]];
		#endif
		[request setHTTPMethod:httpMethod];
		[request setHTTPBody:[[self generatePOSTBodyFromDictionary:params] dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	FMEngineURLConnection *connection = [[FMEngineURLConnection alloc] initWithRequest:request];
	NSString *connectionId = [connection identifier];
	connection.callback = [FMCallback callbackWithTarget:target action:callback userInfo:nil object:connectionId];
	
	if(connection) {
		[connections setObject:connection forKey:connectionId];
	}
}

- (NSOperationQueue *)queue;
{
    if (!_queue) {
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = 1;
    }
    return _queue;
}

- (void)performMethod:(NSString *)method
       withParameters:(NSDictionary *)params
              options:(NSInteger)options
           httpMethod:(NSString *)httpMethod
         successBlock:(void (^)(NSHTTPURLResponse *response, NSDictionary *json))successBlock
            failBlock:(void (^)(NSHTTPURLResponse *response, NSDictionary *json, NSError *error))failBlock
{
    BOOL useSig = options & FMEngineRequestOptionsUseSignature;
    BOOL https = options & FMEngineRequestOptionsHTTPS;
    
	NSString *dataSig = nil;
	NSMutableURLRequest *request = nil;
	NSMutableDictionary *tempDict = [[NSMutableDictionary alloc] initWithDictionary:params];
    
    [tempDict setObject:self.apiKey forKey:@"api_key"];
	
	[tempDict setObject:method forKey:@"method"];
	if(useSig == TRUE) {
		dataSig = [self generateSignatureFromDictionary:tempDict];
		
		[tempDict setObject:dataSig forKey:@"api_sig"];
	}
	
#ifdef _USE_JSON_
	if(![httpMethod isPOST]) {
		[tempDict setObject:@"json" forKey:@"format"];
	}
    
#endif
	
	params = [NSDictionary dictionaryWithDictionary:tempDict];
    
	if(![httpMethod isPOST]) {
		NSURL *dataURL = [self generateURLFromDictionary:params];
		request = [NSURLRequest requestWithURL:dataURL];
	} else {
        NSString *scheme = https ? @"https://" : @"http://";
        NSString *url = [NSString stringWithFormat:@"%@%@",
                         scheme, _LASTFM_API_ENDPOINT_];
        
#ifdef _USE_JSON_
        url = [url stringByAppendingString:@"?format=json"];
#endif
		request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
		[request setHTTPMethod:httpMethod];
		[request setHTTPBody:[[self generatePOSTBodyFromDictionary:params] dataUsingEncoding:NSUTF8StringEncoding]];
	}
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:self.queue
                           completionHandler:
     ^(NSURLResponse *response, NSData *data, NSError *error) {
         
         NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
         BOOL success = YES;
         
         if (error || httpResponse.statusCode!=200) {
             success = NO;
         }
         
         error = nil;
         NSDictionary *json = nil;
         if (success) {
             json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
             
             if (error) {
                 success = NO;
             }
         }
         
         if (success) {
             NSNumber *errorCode = [json objectForKey:@"error"];
             if (errorCode) {
                 success = NO;
             }
         }
         
         if (success) {
             successBlock(httpResponse, json);
         } else {
             failBlock(httpResponse, json, error);
         }
         
     }];
    
}

- (NSData *)dataForMethod:(NSString *)method withParameters:(NSDictionary *)params useSignature:(BOOL)useSig httpMethod:(NSString *)httpMethod error:(NSError *)err {
	NSString *dataSig;
	NSMutableURLRequest *request;
	NSMutableDictionary *tempDict = [[NSMutableDictionary alloc] initWithDictionary:params];
	
	[tempDict setObject:method forKey:@"method"];
	if(useSig == TRUE) {
		dataSig = [self generateSignatureFromDictionary:tempDict];
		
		[tempDict setObject:dataSig forKey:@"api_sig"];
	}
	
	#ifdef _USE_JSON_
	if(![httpMethod isPOST]) {
		[tempDict setObject:@"json" forKey:@"format"];
	}
	#endif
	
	[tempDict setObject:method forKey:@"method"];
	params = [NSDictionary dictionaryWithDictionary:tempDict];
	
	if(![httpMethod isPOST]) {
		NSURL *dataURL = [self generateURLFromDictionary:params];
		request = [NSURLRequest requestWithURL:dataURL];
	} else {
		#ifdef _USE_JSON_
		request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:[_LASTFM_BASEURL_ stringByAppendingString:@"?format=json"]]];
		#else 
		request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:_LASTFM_BASEURL_]];
		#endif
		
		[request setHTTPMethod:httpMethod];
		[request setHTTPBody:[[self generatePOSTBodyFromDictionary:params] dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	NSData *returnData = [FMEngineURLConnection sendSynchronousRequest:request returningResponse:nil error:&err];
	return returnData;
}

- (NSString *)generatePOSTBodyFromDictionary:(NSDictionary *)dict {
	NSMutableString *rawBody = [[NSMutableString alloc] init];
	NSMutableArray *aMutableArray = [[NSMutableArray alloc] initWithArray:[dict allKeys]];
	[aMutableArray sortUsingFunction:sortAlpha context:(__bridge void *)(self)];
	
	for(NSString *key in aMutableArray) {
		[rawBody appendString:[NSString stringWithFormat:@"&%@=%@", key, [dict objectForKey:key]]];
	}	
	
	
	NSString *body = [NSString stringWithString:rawBody];
	
	return body;
}

- (NSURL *)generateURLFromDictionary:(NSDictionary *)dict {
	NSMutableArray *aMutableArray = [[NSMutableArray alloc] initWithArray:[dict allKeys]];
	NSMutableString *rawURL = [[NSMutableString alloc] init];
	[aMutableArray sortUsingFunction:sortAlpha context:(__bridge void *)(self)];
	[rawURL appendString:_LASTFM_BASEURL_];
	
	int i;
	
	for(i = 0; i < [aMutableArray count]; i++) {
		NSString *key = [aMutableArray objectAtIndex:i];
		if(i == 0) {
			[rawURL appendString:[NSString stringWithFormat:@"?%@=%@", key, [dict objectForKey:key]]];
		} else {
			[rawURL appendString:[NSString stringWithFormat:@"&%@=%@", key, [dict objectForKey:key]]];
		}
	}
	
	NSString *encodedURL = [(NSString *)rawURL stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
	NSURL *url = [NSURL URLWithString:encodedURL];
	
	return url;
}

- (NSString *)generateSignatureFromDictionary:(NSDictionary *)dict {
	NSMutableArray *aMutableArray = [[NSMutableArray alloc] initWithArray:[dict allKeys]];
	NSMutableString *rawSignature = [[NSMutableString alloc] init];
	[aMutableArray sortUsingFunction:sortAlpha context:(__bridge void *)(self)];
	
	for(NSString *key in aMutableArray) {
		[rawSignature appendString:[NSString stringWithFormat:@"%@%@", key, [dict objectForKey:key]]];
	}
	
	[rawSignature appendString:self.apiSecret];
	
	NSString *signature = [rawSignature md5sum];
	
	return signature;
}

- (void)dealloc {

	[[connections allValues] makeObjectsPerformSelector:@selector(cancel)];
}

@end