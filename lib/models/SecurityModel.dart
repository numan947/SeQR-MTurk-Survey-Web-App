class SecurityType{
  static final PSK1 = "WPA-PSK";
  static final PSK2 = "WPA2-PSK";
  static final PSK3 = "WPA3-PSK";

  static final EAP1 = "WPA-ENTERPRISE";
  static final EAP2 = "WPA2-ENTERPRISE";
  static final EAP3 = "WPA3-ENTERPRISE";

  static final NONE = "NONE";

  static final PSKLIST = [PSK1, PSK2, PSK3];
  static final EAPLIST = [EAP1, EAP2, EAP3];
}

class SecurityInputInformation{
  String pskPassword;
  String wifiSSID;
  String securityType;
  String enterpriseUsername;
  String enterprisePassword;
  String enterpriseEAPMethod;
  String enterprisePhase2AuthMethod;
  String enterpriseCACertificate;
  String enterpriseAnonymousIdentity;
  String enterpriseDomainName;
  String enterpriseSelectedCACertificate;
  String enterpriseSelectedUserCertificate;
  String selectedCustomCertificate;
}

class SecurityEntry{
  String securityType;
  String pskPassword;
  Map<String, String>enterpriseUserDatabase; // <username,password>
  String enterpriseEAPMethod;
  String enterprisePhase2AuthMethod;
  String enterpriseCACertificate;
  String enterpriseAnonymousIdentity;
  String enterpriseDomainName;
  String usedSystemCertificate;


  String certSignature;
  String certServerName;
  String certIssuerName;
  String certOrganization;

  SecurityEntry({
      this.securityType,
      this.pskPassword,
      this.enterpriseUserDatabase, // <username,password>
      this.enterpriseEAPMethod,
      this.enterprisePhase2AuthMethod,
      this.enterpriseCACertificate,
      this.enterpriseAnonymousIdentity,
      this.enterpriseDomainName,
      this.usedSystemCertificate,
      this.certIssuerName,
      this.certOrganization,
      this.certServerName,
      this.certSignature
  });
}