//
//  ASRemoteDevice.m
//  GPSUplink
//
//  Created by Erik Aderstedt on 2012-06-02.
//  Copyright (c) 2012 Aderstedt Software AB. All rights reserved.
//

#import "ASRemoteDevice.h"
#import "crc_check.h"
#import "ASGPSLocation.h"

enum GT03BProtocolNumber {
    kGT03BLogin = 0x01,
    kGT03BGPS = 0x10,
    kGT03BLBS = 0x11,
    kGT03BGPSLBSMerged = 0x12,
    kGT03BStatus = 0x13,
    kGT03BSatelliteSNR = 0x14,
    kGT03BStrings = 0x15,
    kGT03BGPSLBSStatusMerged = 0x16,
    kGT03BLBSLocationViaPhoneNumber = 0x17,
    kGT03BLBSExtend = 0x18,
    kGT03BLBSStatusMerged = 0x19,
    kGT03BGPSLocationViaPhoneNumber = 0x1A,
    kGT03BServerCommandSet = 0x80,
    kGT03BServerCommandCheck = 0x81
};

static NSDictionary *MCC = nil;

#define PACKET_START_BYTE1  0
#define PACKET_START_BYTE2  1
#define PACKET_LENGTH       2
#define PACKET_PROTOCOL     3
#define PACKET_CONTENT_START 4

uint32_t get32Bits(const unsigned char *b) {
    uint32_t x;
    x = (b[0] << 24) + (b[1] << 16) + (b[2] << 8) + (b[3]);
    return x;
}

void set32Bits(unsigned char *b, uint32_t value) {
    b[0] = ((value & 0xff000000) >> 24);
    b[1] = ((value & 0x00ff0000) >> 16);
    b[2] = ((value & 0x0000ff00) >> 8);
    b[3] = ((value & 0x000000ff) >> 0);
}

uint16_t get16Bits(const unsigned char *b) {
    uint16_t x;
    x = (b[0] << 8) + (b[1]);
    return x;
}

void set16Bits(unsigned char *b, uint16_t value) {
    b[0] = ((value & 0x0000ff00) >> 8);
    b[1] = ((value & 0x000000ff) >> 0);
}

double secondsToDegrees(uint32_t fiveHundredthsOfASeconds) {
    double j = fiveHundredthsOfASeconds;
    j /= 500.0;
    
    j /= 3600.0;
    
    return j;
}

@implementation ASRemoteDevice

@synthesize imei, loggedIn;
@synthesize gpsLocations;
@synthesize deviceType;
@synthesize gsmSignalStrength;
@synthesize lastActivation;
@synthesize accumulatedReadTimeout;
@synthesize packetCounter;

- (id)init
{
    self = [super init];
    if (self) {
        self.gpsLocations = [[NSMutableArray alloc] init];
        self.packetCounter = 1;
        
        if (MCC == nil) {
            MCC = @{@"412":	@"Afghanistan",
            @"276":	@"Albania",
            @"603":	@"Algeria",
            @"544":	@"American Samoa (US)",
            @"213":	@"Andorra",
            @"631":	@"Angola",
            @"365":	@"Anguilla",
            @"344":	@"Antigua and Barbuda",
            @"722":	@"Argentine Republic",
            @"283":	@"Armenia",
            @"363":	@"Aruba (Netherlands)",
            @"505":	@"Australia",
            @"232":	@"Austria",
            @"400":	@"Azerbaijani Republic",
            @"364":	@"Bahamas",
            @"426":	@"Bahrain",
            @"470":	@"Bangladesh",
            @"342":	@"Barbados",
            @"257":	@"Belarus",
            @"206":	@"Belgium",
            @"702":	@"Belize",
            @"616":	@"Benin",
            @"350":	@"Bermuda (UK)",
            @"402":	@"Bhutan",
            @"736":	@"Bolivia",
            @"218":	@"Bosnia and Herzegovina",
            @"652":	@"Botswana",
            @"724":	@"Brazil",
            @"348":	@"British Virgin Islands (UK)",
            @"528":	@"Brunei Darussalam",
            @"284":	@"Bulgaria",
            @"613":	@"Burkina Faso",
            @"642":	@"Burundi",
            @"456":	@"Cambodia",
            @"624":	@"Cameroon",
            @"302":	@"Canada",
            @"625":	@"Cape Verde",
            @"346":	@"Cayman Islands (UK)",
            @"623":	@"Central African Republic",
            @"622":	@"Chad",
            @"730":	@"Chile",
            @"460":	@"China",
            @"461":	@"China",
            @"732":	@"Colombia",
            @"654":	@"Comoros",
            @"629":	@"Republic of the Congo",
            @"548":	@"Cook Islands (NZ)",
            @"712":	@"Costa Rica",
            @"612":	@"Côte d'Ivoire",
            @"219":	@"Croatia",
            @"368":	@"Cuba",
            @"362":	@"Curaçao (Netherlands)",
            @"280":	@"Cyprus",
            @"230":	@"Czech Republic",
            @"630":	@"Democratic Republic of the Congo",
            @"238":	@"Denmark",
            @"638":	@"Djibouti",
            @"366":	@"Dominica",
            @"370":	@"Dominican Republic",
            @"514":	@"East Timor",
            @"740":	@"Ecuador",
            @"602":	@"Egypt",
            @"706":	@"El Salvador",
            @"627":	@"Equatorial Guinea",
            @"657":	@"Eritrea",
            @"248":	@"Estonia",
            @"636":	@"Ethiopia",
            @"750":	@"Falkland Islands (UK)",
            @"288":	@"Faroe Islands (Denmark)",
            @"542":	@"Fiji",
            @"244":	@"Finland",
            @"208":	@"France",
            @"742":	@"French Guiana (France)",
            @"547":	@"French Polynesia (France)",
            @"628":	@"Gabonese Republic",
            @"607":	@"Gambia",
            @"282":	@"Georgia",
            @"262":	@"Germany",
            @"620":	@"Ghana",
            @"266":	@"Gibraltar (UK)",
            @"202":	@"Greece",
            @"290":	@"Greenland (Denmark)",
            @"352":	@"Grenada",
            @"340":	@"Guadeloupe (France)",
            @"535":	@"Guam (US)",
            @"704":	@"Guatemala",
            @"611":	@"Guinea",
            @"632":	@"Guinea-Bissau",
            @"738":	@"Guyana",
            @"372":	@"Haiti",
            @"708":	@"Honduras",
            @"454":	@"Hong Kong (PRC)",
            @"216":	@"Hungary",
            @"274":	@"Iceland",
            @"404":	@"India",
            @"405":	@"India",
            @"406":	@"India",
            @"510":	@"Indonesia",
            @"432":	@"Iran",
            @"418":	@"Iraq",
            @"272":	@"Ireland",
            @"972":	@"Israel",
            @"222":	@"Italy",
            @"338":	@"Jamaica",
            @"441":	@"Japan",
            @"440":	@"Japan",
            @"416":	@"Jordan",
            @"401":	@"Kazakhstan",
            @"639":	@"Kenya",
            @"545":	@"Kiribati",
            @"467":	@"Korea, North",
            @"450":	@"Korea, South",
            @"419":	@"Kuwait",
            @"437":	@"Kyrgyz Republic",
            @"457":	@"Laos",
            @"247":	@"Latvia",
            @"415":	@"Lebanon",
            @"651":	@"Lesotho",
            @"618":	@"Liberia",
            @"606":	@"Libya",
            @"295":	@"Liechtenstein",
            @"246":	@"Lithuania",
            @"270":	@"Luxembourg",
            @"455":	@"Macau (PRC)",
            @"294":	@"Republic of Macedonia",
            @"646":	@"Madagascar",
            @"650":	@"Malawi",
            @"502":	@"Malaysia",
            @"472":	@"Maldives",
            @"610":	@"Mali",
            @"278":	@"Malta",
            @"551":	@"Marshall Islands",
            @"340":	@"Martinique (France)",
            @"609":	@"Mauritania",
            @"617":	@"Mauritius",
            @"334":	@"Mexico",
            @"550":	@"Federated States of Micronesia",
            @"259":	@"Moldova",
            @"212":	@"Monaco",
            @"428":	@"Mongolia",
            @"297":	@"Montenegro (Republic of)",
            @"354":	@"Montserrat (UK)",
            @"604":	@"Morocco",
            @"643":	@"Mozambique",
            @"414":	@"Myanmar",
            @"649":	@"Namibia",
            @"536":	@"Nauru",
            @"429":	@"Nepal",
            @"204":	@"Netherlands",
            @"546":	@"New Caledonia (France)",
            @"530":	@"New Zealand",
            @"710":	@"Nicaragua",
            @"614":	@"Niger",
            @"621":	@"Nigeria",
            @"555":	@"Niue",
            @"534":	@"Northern Mariana Islands (US)",
            @"242":	@"Norway",
            @"422":	@"Oman",
            @"410":	@"Pakistan",
            @"552":	@"Palau",
            @"425":	@"Palestine",
            @"714":	@"Panama",
            @"537":	@"Papua New Guinea",
            @"744":	@"Paraguay",
            @"716":	@"Perú",
            @"515":	@"Philippines",
            @"260":	@"Poland",
            @"268":	@"Portugal",
            @"330":	@"Puerto Rico (US)",
            @"427":	@"Qatar",
            @"647":	@"Réunion (France)",
            @"226":	@"Romania",
            @"250":	@"Russian Federation",
            @"635":	@"Rwandese Republic",
            @"356":	@"Saint Kitts and Nevis",
            @"358":	@"Saint Lucia",
            @"308":	@"Saint Pierre and Miquelon (France)",
            @"360":	@"Saint Vincent and the Grenadines",
            @"549":	@"Samoa",
            @"292":	@"San Marino",
            @"626":	@"São Tomé and Príncipe",
            @"420":	@"Saudi Arabia",
            @"608":	@"Senegal",
            @"220":	@"Serbia (Republic of)",
            @"633":	@"Seychelles",
            @"619":	@"Sierra Leone",
            @"525":	@"Singapore",
            @"231":	@"Slovakia",
            @"293":	@"Slovenia",
            @"540":	@"Solomon Islands",
            @"637":	@"Somalia",
            @"655":	@"South Africa",
            @"214":	@"Spain",
            @"413":	@"Sri Lanka",
            @"634":	@"Sudan",
            @"746":	@"Suriname",
            @"653":	@"Swaziland",
            @"240":	@"Sweden",
            @"228":	@"Switzerland",
            @"417":	@"Syria",
            @"466":	@"Taiwan",
            @"436":	@"Tajikistan",
            @"640":	@"Tanzania",
            @"520":	@"Thailand",
            @"615":	@"Togolese Republic",
            @"539":	@"Tonga",
            @"374":	@"Trinidad and Tobago",
            @"605":	@"Tunisia",
            @"286":	@"Turkey",
            @"438":	@"Turkmenistan",
            @"376":	@"Turks and Caicos Islands (UK)",
            @"641":	@"Uganda",
            @"255":	@"Ukraine",
            @"424":	@"United Arab Emirates",
            @"430":	@"United Arab Emirates",
            @"431":	@"United Arab Emirates",
            @"235":	@"United Kingdom",
            @"234":	@"United Kingdom",
            @"310":	@"United States of America",
            @"311":	@"United States of America",
            @"312":	@"United States of America",
            @"313":	@"United States of America",
            @"314":	@"United States of America",
            @"315":	@"United States of America",
            @"316":	@"United States of America",
            @"332":	@"United States Virgin Islands (US)",
            @"748":	@"Uruguay",
            @"434":	@"Uzbekistan",
            @"541":	@"Vanuatu",
            @"225":	@"Vatican City State",
            @"734":	@"Venezuela",
            @"452":	@"Viet Nam",
            @"543":	@"Wallis and Futuna (France)",
            @"421":	@"Yemen",
            @"645":	@"Zambia",
            @"648":	@"Zimbabwe"};
        }
    }
    return self;
}

+ (BOOL)validatePackage:(NSData *)data {
    NSUInteger length = [data length];
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    BOOL malformed = NO;
    
    // Confirm start bytes    
    if (length < 2 || bytes[PACKET_START_BYTE1] != 0x78 || bytes[PACKET_START_BYTE2] != 0x78) {
        malformed = YES;
    }
    // Confirm packet length
    if (length < 3 || bytes[PACKET_LENGTH] != length - 5) {
        malformed = YES;
    }
    
    if (!malformed && GetCrc16(bytes + 2, length - 6)) {
        unsigned short checksum = GetCrc16(bytes + 2, length - 6);
        // Big-endian
        unsigned short error_check = get16Bits(bytes + length - 4);
        
        if (error_check != checksum) malformed = YES;
    }
    
    return !malformed;
}

+ (BOOL)isLoginPackage:(NSData *)data {
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    return ((enum GT03BProtocolNumber)bytes[PACKET_PROTOCOL] == kGT03BLogin);
}

- (NSData *)handlePackage:(NSData *)data {
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    enum GT03BProtocolNumber pNumber = (enum GT03BProtocolNumber)bytes[PACKET_PROTOCOL];
    unsigned short i, j;
    ASGPSLocation *location;
    
    if (pNumber != kGT03BLogin && !self.loggedIn) {
        NSLog(@"Received data from a device that wasn't logged in.");
        self.lastResponse = @"Bad device.";
        return nil;
    }
    NSMutableString *imeiString = [NSMutableString stringWithCapacity:16];
    bytes += PACKET_CONTENT_START;
    char *serverResponse[257];
    switch (pNumber) {
        case kGT03BLogin:            
            // IMEI
            for (i = 0; i < 8; i++) {
                j = bytes[i];
                [imeiString appendString:[NSString stringWithFormat:@"%c%c",'0'+(j >> 4), '0'+(j & 0xf)]];
            }
            self.imei = imeiString;
            NSLog(@"Login from IMEI %@", self.imei);
            self.lastResponse = @"Logged in";
            // Device type
            i = bytes[8];
            i = (i << 8) + bytes[9];
            self.deviceType = i;
            self.loggedIn = YES;
            
            break;
        case kGT03BStatus:
            self.gsmSignalStrength = [NSNumber numberWithChar:bytes[2]];
            NSLog(@"IMEI %@ reports signal strength %@", self.imei, self.gsmSignalStrength);
            self.lastResponse = [NSString stringWithFormat:@"Signal strength %@", self.gsmSignalStrength];
            break;
        case kGT03BGPS:
            location = [[ASGPSLocation alloc] init];
            location.timestamp = [NSDate dateWithString:[NSString stringWithFormat:@"2%03d-%02d-%02d %02d:%02d:%02d +0000", bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]]];
            location.latitude = secondsToDegrees(get32Bits(bytes+7));
            location.longitude = secondsToDegrees(get32Bits(bytes+11));;
            if (!(bytes[16] & 4)) location.latitude *= -1.0;
            if (bytes[16] & 8) location.longitude *= -1.0;
            
            NSLog(@"Received location %@ from IMEI %@", [location stringRepresentation], self.imei);
            [self.gpsLocations addObject:location];
            self.lastResponse = @"Location updated";
            break;
        case kGT03BLBS:
            
            // Not interesting for us.
            break;
        case kGT03BServerCommandSet:
        case kGT03BServerCommandCheck:
            strncpy(serverResponse, bytes+5, bytes[0]);
            serverResponse[bytes[0]] = 0;
            self.lastResponse = [NSString stringWithCString:(const char *)serverResponse encoding:NSASCIIStringEncoding];
            NSLog(@"Server response: %@", self.lastResponse);
            break;
        case kGT03BLBSExtend:
            self.lastResponse = @"LBS extended";
            NSLog(@"LBS. Country: %@", [MCC objectForKey:[NSString stringWithFormat:@"%d", get16Bits(bytes+6)]]);
            break;
        default:
            NSLog(@"Unexpected protocol %d from device %@.", pNumber, self.imei);
            break;
    }

    return [ASRemoteDevice standardServerResponseToPackage:data];
}

+ (NSData *)standardServerResponseToPackage:(NSData *)data {
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    // Assumes a previous check against malformed data.
    unsigned char rbytes[10];
    rbytes[PACKET_START_BYTE1] = 0x78;
    rbytes[PACKET_START_BYTE2] = 0x78;
    rbytes[PACKET_LENGTH] = 5;
    rbytes[PACKET_PROTOCOL] = bytes[PACKET_PROTOCOL];
    rbytes[4] = bytes[[data length] - 6];
    rbytes[5] = bytes[[data length] - 5];
    
    unsigned short crc = GetCrc16(rbytes + 2, 4);
    rbytes[6] = (crc & 0xff00) >> 8;
    rbytes[7] = crc & 0xff;
    rbytes[8] = 0x0d;
    rbytes[9] = 0x0a;
    
    return [[NSData alloc] initWithBytes:rbytes length:10];
}

- (ASGPSLocation *)lastLocation {
    if ([self.gpsLocations count])
        return [self.gpsLocations lastObject];
    
    return nil;
}

- (BOOL)shouldReactivate {
    if (self.lastActivation == nil || 
        [[self.lastActivation dateByAddingTimeInterval:15.0*60] compare:[NSDate date]] == NSOrderedAscending) {
        return YES;
    }
    return NO;
}

- (NSData *)reactivationPackage {
    return [self packageForCommand:@"GPSON#"];
}

- (NSData *)packageForCommand:(NSString *)command {
    // Server command GPSOFF#, GPSON#. Behövs båda?
    
    unsigned char *rbytes;
    int cLength = (int)[command length];
    int tLength = 15 + cLength;
    rbytes = calloc(tLength, sizeof(unsigned char));
    
    rbytes[PACKET_START_BYTE1] = 0x78;
    rbytes[PACKET_START_BYTE2] = 0x78;
    rbytes[PACKET_LENGTH] = 10 + cLength;
    rbytes[PACKET_PROTOCOL] = kGT03BServerCommandSet;
    rbytes[PACKET_CONTENT_START] = 4 + cLength; // Length of command + server serial
    set32Bits(rbytes+PACKET_CONTENT_START+1, (uint32_t)(self.packetCounter ++));
    strncpy((char *)rbytes+PACKET_CONTENT_START+5, [command cStringUsingEncoding:NSASCIIStringEncoding], cLength);
    set16Bits(rbytes + tLength - 6, self.packetCounter - 1);
    set16Bits(rbytes + tLength - 4, GetCrc16(rbytes + 2, 15));
    rbytes[tLength - 2] = 0x0d;
    rbytes[tLength - 1] = 0x0a;
    
    return [[NSData alloc] initWithBytes:rbytes length:tLength];
}

@end
