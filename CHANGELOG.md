# hitobito_banking_de Changelog

## 0.1.0 (unreleased)

- Account statement import (camt.052/camt.053, versions .02 and .08, single files or ZIP)
  with duplicate detection and gap check
- Suggestions by IBAN, mandate reference, member number and names; split into purposes
  and years
- Confirmation, correction, ignoring and taking back of bookings; purposes registered by
  the organization wagon
- Returned direct debits with reason, noted at the bank account
- Bank account and SEPA direct debit mandate per person, IBAN learned from confirmed
  payments
- Access only with the `finance` permission
