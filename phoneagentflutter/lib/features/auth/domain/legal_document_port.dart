enum LegalDocument { userAgreement, privacyPolicy, personalInformation }

abstract interface class LegalDocumentPort {
  Future<void> open(LegalDocument document);
}
