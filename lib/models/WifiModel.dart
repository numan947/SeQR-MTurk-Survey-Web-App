import 'package:wifi_qr_survey_app/models/FixedData.dart';
import 'package:wifi_qr_survey_app/models/SecurityModel.dart';
import 'package:wifi_qr_survey_app/MainApp.dart';

const String TOFU_STRING = "Trust on First Use";
const String PLS_SLT_STR = "Please select";
const String USE_SYS_CRT = "Use system certificates";
const String DNT_VALIDAT = "Do not validate";
const String DNT_PROVIDE = "Do not provide";


class WifiConnectionState {
  // various states of a wifi connection during the connection is getting established
  static final String CONNECTED = "CONNECTED";
  static final String DISCONNECTED = "DISCONNECTED";
  static final String CONNECTING = "CONNECTING";
  static final String OBTAININGIP = "OBTAINING IP ADDRESS";
  static final String VERIFYING = "VERIFYING";
}

class WifiEntry {
  bool saved;
  String wifiSSID;
  SecurityEntry security;
  int signalStrength;
  String
      connectionState; // {Disconnected, Connected, Connecting, Obtaining IP Address}
  String qrCodePath;
  bool twin; // evil twin?

  WifiEntry(
      {this.qrCodePath = null,
      this.twin = false,
      this.saved = false,
      this.wifiSSID,
      this.security,
      this.signalStrength,
      this.connectionState = "DISCONNECTED"});

  bool validate(SecurityInputInformation sii) {
    if (saved) return true;

    // print("------------------------------------");
    // print("sii.selectedCustomCertificate ="+sii.selectedCustomCertificate);
    // print("this.security.enterpriseDomainName ="+this.security.enterpriseDomainName);
    // if(sii.enterpriseDomainName!=null)print("sii.enterpriseDomainName = "+sii.enterpriseDomainName);
    // else print("sii.enterpriseDomainName = null");
    // print("FixedData.domainNamesToDomainLink[sii.selectedCustomCertificate] = "+FixedData.domainNamesToDomainLink[sii.selectedCustomCertificate]);

    // print("------------------------------------");
    bool ok = true;
    if (ok && this.wifiSSID != null) ok = ok && this.wifiSSID == sii.wifiSSID;
    if (ok && this.security != null)
      ok = ok && this.security.securityType == sii.securityType;

    if (this.security.securityType == SecurityType.NONE)
      return true;
    else if (SecurityType.PSKLIST.contains(this.security.securityType))
      ok = ok && this.security.pskPassword == sii.pskPassword;
    else if (SecurityType.EAPLIST.contains(this.security.securityType)) {
      if (sii.enterpriseDomainName != null)
        sii.enterpriseDomainName = sii.enterpriseDomainName
            .toLowerCase(); // making this case insensitive

      
      if(this.twin == false) // remove enforcement for evil twins
        ok = ok &&this.security.enterpriseUserDatabase[sii.enterpriseUsername] == sii.enterprisePassword;

      if (sii.enterpriseSelectedCACertificate == TOFU_STRING) {
        return ok;
      }

      if (sii.enterpriseSelectedCACertificate != PLS_SLT_STR &&
          sii.enterpriseSelectedCACertificate != USE_SYS_CRT &&
          sii.enterpriseSelectedCACertificate != DNT_VALIDAT) {
        final enterpriseDomainList =
            this.security.enterpriseDomainName.split(";");
        // print(enterpriseDomainList);

        ok = ok &&
            (FixedData.domainNames.contains(sii.selectedCustomCertificate)) && this.security.enterpriseDomainName == FixedData.domainNamesToDomainLink[sii.selectedCustomCertificate];

        if (sii.enterpriseDomainName != null &&
            sii.enterpriseDomainName.isNotEmpty)
          ok = ok && enterpriseDomainList.contains(sii.enterpriseDomainName);
      }

      if (sii.enterpriseSelectedCACertificate == USE_SYS_CRT) {
        // print("GHASDSA");
        final enterpriseDomainList =
            this.security.usedSystemCertificate.split(";");
        if (sii.enterpriseDomainName != null &&
            sii.enterpriseDomainName.isNotEmpty)
          ok = ok && enterpriseDomainList.contains(sii.enterpriseDomainName);
      }
    }
    // print("OK ==> $ok");
    return ok;
  }
}
