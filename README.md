# hitobito_banking_de

A [hitobito](https://github.com/hitobito/hitobito) wagon for German banking needs of clubs:
account statement import and bank accounts with SEPA direct debit mandates.
Organization-neutral: it works with any group structure. What a payment means for a person
(e.g. "fee paid until") is decided by the organization wagon.

## Features

- **Account statement import** on layer groups (tab "Kontoimport"): upload camt.052 or
  camt.053 files (ISO 20022 versions .02 and .08, e.g. the Sparkasse export
  "XML (CAMT V8 – gebuchte Umsätze)"), several files or a ZIP with all daily files at once.
  - Statements and bookings already imported are recognized and skipped, so exports may
    overlap.
  - Gaps are detected: the closing balance of a statement must be the opening balance of
    the next one.
  - Only incoming payments and returned direct debits are stored. Outgoing payments are
    not stored at all.
- **Suggestions, nothing booked without confirmation.** For every incoming payment the
  wagon suggests who paid (known IBAN or mandate reference, member number in the
  remittance information, names in payer and text, also without umlauts) and how the amount
  splits into purposes and years ("2026/27", 85 + 20, 3 × 85 for three people). The
  treasurer confirms with one click, corrects or ignores (e.g. course fees, donations).
  Allocations can be taken back.
- **Returned direct debits** (with reason, e.g. AC04 account closed) are booked with a
  negative amount and noted at the bank account of the person. Mandates with a blocking
  return reason are not collectible until checked.
- **Bank account and SEPA mandate** per person: IBAN (check digits validated), account
  holder, mandate reference, signing and revocation date. Direct debits may only be
  collected with an active mandate (`BankingDe::BankAccount.collectible`). When a payment
  of exactly one person is confirmed, the payer's IBAN is stored for that person (without
  mandate) if none is known yet.
- **Direct debit batches** show up as one sum in the statement; they are marked and can be
  ignored. Creating SEPA direct debit files (pain.008) is planned.

## Data protection

Bank data is personal and sensitive:

- Only people with the core permission `finance` see and edit it: the import of their layer
  and the bank accounts of people in their layer and below. Nobody else does, the person
  included.
- Bank accounts, bookings and allocations live in own tables and are not part of any
  person export.
- Every confirmation stores who did it and when; the bank account stores who changed it.

## Requirements

- hitobito core (2026 or later)
- An organization wagon that registers the purposes (see below)

Add the wagon next to the core like any other wagon.

## Configuration in the organization wagon

Register what incoming payments can be for, e.g. in the `to_prepare` block of the wagon:

```ruby
BankingDe.register_purpose(:membership_fee, amount: 85, yearly: true, primary: true,
  apply: ->(allocation) { MyClub::Fee.paid(allocation) },    # returns a hash stored as effect
  revert: ->(allocation) { MyClub::Fee.undo(allocation) })  # gets allocation.effect
BankingDe.register_purpose(:work_hours_compensation, amount: 20, yearly: true)
```

- `amount` is only used for suggestions; there is no amount check.
- `primary` is the purpose suggested per year.
- `apply` and `revert` run in the database transaction of the confirmation. Returned
  direct debits call them with a negative amount.
- Labels come from `banking_de.purposes.<key>` in the locales of the organization wagon.

Optional settings (`settings.yml` of the organization wagon):

```yaml
banking_de:
  member_number_attribute: membership_number   # person attribute searched in the text
```

## Development

Run the specs from the wagon directory next to a core checkout:

```sh
bundle exec rake db:test:prepare db:migrate
bundle exec rspec
bundle exec rubocop
```

Test files in `spec/fixtures/files` are synthetic. **Never commit real account
statements**; ZIP files are ignored by git for that reason.

## License

AGPL-3.0-or-later, see [LICENSE](LICENSE).
