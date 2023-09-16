import 'package:shared_preferences/shared_preferences.dart';

import 'SecurityModel.dart';
import 'WifiModel.dart';
import 'package:wifi_qr_survey_app/MainApp.dart';

class FixedData {
  static List<WifiEntry> wifiList = [
    // WifiEntry(
    //     wifiSSID: "Garden101",
    //     security: SecurityEntry(
    //         securityType: SecurityType.PSK2, pskPassword: "7C8403C1764F7D2C6D"),
    //     signalStrength: 3),

    WifiEntry(
        wifiSSID: "Room505",
        security: SecurityEntry(
            securityType: SecurityType.PSK2, pskPassword: "CE1E245FDE1F1670BE234234dfsdfretfgrtrgdfg87C8403C1764F7D2C6D99B69"),
        signalStrength: 2),

    WifiEntry(
        wifiSSID: "Great Hall",
        security: SecurityEntry(
            securityType: SecurityType.PSK2, pskPassword: "CE1E245FDE1F1670BE87C8403C1764F7D2C6D99B69"),
        signalStrength: 2),

    // WifiEntry(
    //     wifiSSID: "CSE-Sec-A",
    //     security: SecurityEntry(
    //         securityType: SecurityType.EAP2,
    //         enterpriseCACertificate:
    //             "A9697939F2C340CE1E245FDE1F1670BE87C8403C1764F7D2C6D99B696FBA5C27EED70C7C74F7A72B3F3FB08B2202D38844A467F0EE86504A3B470EAC71A0A29C", //CSE-SEC-A-CA-Certificate
    //         enterpriseDomainName: "cse-sec-a.org;org",
    //         usedSystemCertificate: "cse-sec-a.org;org",
    //         enterpriseUserDatabase: {"alice_a": "1234", "bob_a": "9B696FBA5C27EED70C"}),
    //     signalStrength: 1,
    //     qrCodePath: null),

    // WifiEntry(
    //     wifiSSID: "CSE-Sec-B",
    //     security: SecurityEntry(
    //         securityType: SecurityType.EAP2,
    //         enterpriseCACertificate:
    //             "BD1F5EB758BB41702E4AFC6B26CF57B65A9A978FAD819FB0E7911224DEB56FF52A8F622F86DF1C3DDA9C5CB0F6FE0C5C290E5A00383950CE86568235069F84AF", //CSE-SEC-B-CA-Certificate
    //         enterpriseDomainName: "cse-sec-b.org",
    //         usedSystemCertificate: "cse-sec-a.org;org",
    //         enterpriseUserDatabase: {"alice_b": "72B3F3FB08B2202", "bob_b": "9B696FBA5C27EED70C"}),
    //     signalStrength: 3,
    //     qrCodePath: null),

    // WifiEntry(
    //     wifiSSID: "UE-Secure",
    //     security: SecurityEntry(
    //         securityType: SecurityType.EAP2,
    //         enterpriseCACertificate:
    //             "382644ED105257F63A8DBEC51AA02DF46A2937A4E73DB2155A183F4096D1FD32A5F4CD92606637ACF8B7A564CD70CD1C1241D34FC475D0FF0F068F099795C3B9", //syne.cs.syr.edu-CA-Certificate
    //         usedSystemCertificate: "dot1x.ue.edu;ue.edu;edu",
    //         enterpriseDomainName: "dot1x.ue.edu;ue.edu;edu",
    //         enterpriseUserDatabase: {
    //           // "s31415@ue.edu": "passwordforwifi",
    //           "username@ue.edu": "passwordforwifi",
    //           // "user3": "secretpassword3456"
    //         },
            
    //         certIssuerName: "USERTrust RSA Certification Authority",
    //         certServerName: "USERTrust RSA Certification Authority",
    //         certOrganization: "The USERTRUST Network",
    //         certSignature: "b493c0dd035f0429"
    //         ),
    //     signalStrength: 2,
    //     qrCodePath: "qr-codes/seqr-01/1.png",
    //     twin: false
    //     ),

    // WifiEntry(
    //     wifiSSID: "UE-Secure-2",
    //     security: SecurityEntry(
    //         securityType: SecurityType.EAP2,
    //         enterpriseCACertificate:
    //             "382644ED105257F63A8DBEC51AA02DF46A2937A4E73DB2155A183F4096D1FD32A5F4CD92606637ACF8B7A564CD70CD1C1241D34FC475D0FF0F068F099795C3B9", //syne.cs.syr.edu-CA-Certificate
    //         usedSystemCertificate: "dot1x.ue.edu;ue.edu;edu",
    //         enterpriseDomainName: "dot1x.ue.edu;ue.edu;edu",
    //         enterpriseUserDatabase: {
    //           // "s31415@ue.edu": "passwordforwifi",
    //           "username@ue.edu": "passwordforwifi",
    //           // "user3": "secretpassword3456"
    //         },
            
    //         certIssuerName: "US RSA Certification Authority",
    //         certServerName: "US RSA Certification Authority",
    //         certOrganization: "The US network",
    //         certSignature: "c537475efdb22adc"
    //         ),
    //     signalStrength: 2,
    //     qrCodePath: "qr-codes/seqr-01/1.png",
    //     ),
    //   WifiEntry(
    //     wifiSSID: "UE-Secure-3",
    //     security: SecurityEntry(
    //         securityType: SecurityType.EAP2,
    //         enterpriseCACertificate:
    //             "382644ED105257F63A8DBEC51AA02DF46A2937A4E73DB2155A183F4096D1FD32A5F4CD92606637ACF8B7A564CD70CD1C1241D34FC475D0FF0F068F099795C3B9", //syne.cs.syr.edu-CA-Certificate
    //         usedSystemCertificate: "dot1x.ue.edu;ue.edu;edu",
    //         enterpriseDomainName: "dot1x.ue.edu;ue.edu;edu",
    //         enterpriseUserDatabase: {
    //           // "s31415@ue.edu": "passwordforwifi",
    //           "username@ue.edu": "passwordforwifi",
    //           // "user3": "secretpassword3456"
    //         },
            
    //         certIssuerName: "Trust Certification Authority",
    //         certServerName: "Trust Certification Authority",
    //         certOrganization: "The Number 1 Network",
    //         certSignature: "712505e32486989c"
    //         ),
    //     signalStrength: 2,
    //     qrCodePath: "qr-codes/seqr-01/1.png",
    //     ),
    // WifiEntry(
    //     wifiSSID: "UE-Secure-4",
    //     security: SecurityEntry(
    //         securityType: SecurityType.EAP2,
    //         enterpriseCACertificate:
    //             "382644ED105257F63A8DBEC51AA02DF46A2937A4E73DB2155A183F4096D1FD32A5F4CD92606637ACF8B7A564CD70CD1C1241D34FC475D0FF0F068F099795C3B9", //syne.cs.syr.edu-CA-Certificate
    //         usedSystemCertificate: "dot1x.ue.edu;ue.edu;edu",
    //         enterpriseDomainName: "dot1x.ue.edu;ue.edu;edu",
    //         enterpriseUserDatabase: {
    //           // "s31415@ue.edu": "passwordforwifi",
    //           "username@ue.edu": "passwordforwifi",
    //           // "user3": "secretpassword3456"
    //         },
            
    //         certIssuerName: "RandHex Certification Authority",
    //         certServerName: "RandHex Certification Authority",
    //         certOrganization: "The RandHex Network",
    //         certSignature: "0334a8c46fa1ca6e"
    //         ),
    //     signalStrength: 2,
    //     qrCodePath: "qr-codes/seqr-01/1.png",
    //     ),
    // WifiEntry(
    //     wifiSSID: "SYNE-Lab (FAKE)",
    //     security: SecurityEntry(
    //       securityType: SecurityType.EAP3,
    //       enterpriseCACertificate: "382644ED105257F63B8CBFG51AA02DF46A2937A4E73DB2155A183F4096D1FD32A5F4CD92606637ACF8B7A564CD70CD1C1241D34FC475D0AB0F068F099795C3B9", //syne.cs.syr.edu-CA-Certificate
    //       enterpriseDomainName: "syne-et.cs.syr.edu",
    //       enterpriseUserDatabase: {"user1":"1234", "user2":"2345", "user3":"3456"}, // todo how to setup evil twin's userdatabase?
    //     ),
    //     signalStrength: 4,
    //     twin: true
    // )
  ];

  // autopopulated: when called populateNetworkStaticLists below
  static List<String> domainNames = ["ue-secure"];
  static Map<String, String>domainNamesToDomainLink = {
    "CSE-SEC-A":"cse-sec-a.org;org",
    "CSE-SEC-B":"cse-sec-b.org;org", 
    "ue-secure":"dot1x.ue.edu;ue.edu;edu"
  };
  static Map<String, String> qrCodeValues = {
    "qr-codes/seqr-01/1.png":"382644ED105257F63A8DBEC51AA02DF46A2937A4E73DB2155A183F4096D1FD32A5F4CD92606637ACF8B7A564CD70CD1C1241D34FC475D0FF0F068F099795C3B9",
    "qr-codes/seqr-02/2.png":"382644ED105257F63A8DBEC51AA02DF46A2937A4E73DB2155A183F4096D1FD32A5F4CD92606637ACF8B7A564CD70CD1C1241D34FC475D0FF0F068F099795C3B9",

  };
  static Map<String, String> qrCodeWifiSSID = {
    "qr-codes/seqr-01/1.png":"UE-Secure",
    "qr-codes/seqr-02/2.png":"UE-Secure"
  };

  static final String certStateDownloaded = "CERTIFICATE_DOWNLOADED";
  static final String certStateNotDownloaded = "CERTIFICATE_NOT_DOWNLOADED";
  static final String certStateInstalled = "CERTIFICATE_INSTALLED";
  static final String certModeVpn = 'VPN and apps';
  static final String certModeWifi = 'Wi-Fi';

  static bool isEnterpriseEntry(WifiEntry element) {
    return SecurityType.EAPLIST.contains(element.security.securityType) &&
        !element.twin &&
        element.security.enterpriseCACertificate != null &&
        element.qrCodePath != null &&
        element.wifiSSID != null;
  }
  // this function should be called exactly once at the very beginning of the webapp
  // static Future<void> populateNetworkStaticLists() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   FixedData.wifiList.forEach((element) {
  //       if (isEnterpriseEntry(element)) {
  //         FixedData.qrCodeWifiSSID[element.qrCodePath] = element.wifiSSID;
  //         FixedData.qrCodeValues[element.qrCodePath] = element.security.enterpriseCACertificate;
  //         FixedData.domainNames.add(element.security.enterpriseDomainName);
  //         prefs?.getString(element.security.enterpriseDomainName)?? prefs?.setString(element.security.enterpriseDomainName, certStateNotDownloaded);
  //       }
  //   });
  // }
}
