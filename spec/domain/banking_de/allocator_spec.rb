# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

require "spec_helper"

describe BankingDe::Allocator do
  let(:user) { people(:top_leader) }
  let(:member) { people(:bottom_member) }
  let!(:log) { register_test_purposes }
  let(:fee) { BankingDe::Booking.find_by!(amount: 85) }
  let(:returned) { BankingDe::Booking.find_by!(kind: "return") }

  before { import_camt("camt052_v08.xml") }

  def allocator(booking)
    described_class.new(booking, user)
  end

  def fee_row(person, year: 2026, amount: 85)
    {person_id: person.id, purpose: "membership_fee", year: year, amount: amount}
  end

  it "allocates, applies the purposes and stores the IBAN of a single payer" do
    allocator(fee).allocate([fee_row(member, year: "2026", amount: "85,00")], note: "ok")

    expect(fee.reload).to have_attributes(state: "done", processed_by: user, note: "ok")
    expect(fee.allocations.first).to have_attributes(person: member, year: 2026, amount: 85,
      effect: {"year" => 2026}, created_by: user)
    expect(log).to eq [[:apply, member.id, 2026, 85]]

    account = member.reload.banking_de_bank_account
    expect(account).to have_attributes(iban: BankingDeHelpers::MEMBER_IBAN, source: "import",
      account_holder: "MEMBER BOTTOM")
    expect(account.mandate?).to be false
  end

  it "does not store the IBAN for several people or over an existing account" do
    allocator(fee).allocate([fee_row(member, amount: 42.5), fee_row(user, amount: 42.5)])
    expect(BankingDe::BankAccount.count).to eq 0

    other = BankingDe::Booking.find_by!(amount: 105, kind: "transfer")
    BankingDe::BankAccount.create!(person: user, iban: "DE89370400440532013000")
    allocator(other).allocate([fee_row(user, amount: 105)])
    expect(user.reload.banking_de_bank_account.iban).to eq "DE89370400440532013000"
  end

  it "applies several years in order and reverts in reverse order" do
    allocator(fee).allocate([fee_row(member, year: 2027), fee_row(member, year: 2026)])
    expect(log.map(&:third)).to eq [2026, 2027]

    allocator(fee.reload).revert
    expect(log.last(2).map(&:third)).to eq [2027, 2026]
    expect(fee.reload).to have_attributes(state: "open", processed_by: nil)
    expect(fee.allocations).to be_empty
  end

  it "drops rows without person and requires one row" do
    expect { allocator(fee).allocate([fee_row(member).merge(person_id: "")]) }
      .to raise_error(BankingDe::Allocator::Error, "no_rows")
  end

  it "requires a year for yearly purposes and saves nothing on errors" do
    rows = [fee_row(member), fee_row(member, year: "", amount: 20)]

    expect { allocator(fee).allocate(rows) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(BankingDe::Allocation.count).to eq 0
    expect(fee.reload).to be_open
  end

  it "does not allocate batches" do
    batch = BankingDe::Booking.find_by!(kind: "direct_debit_batch")

    expect { allocator(batch).allocate([fee_row(member)]) }
      .to raise_error(BankingDe::Allocator::Error, "not_allocatable")
  end

  it "notes returned direct debits at the bank account and blocks the mandate" do
    account = BankingDe::BankAccount.create!(person: member, iban: "DE60855500003333333333",
      mandate_reference: "MANDATE-0001", mandate_signed_on: Date.new(2020, 1, 1))
    expect(account).to be_collectible

    allocator(returned).allocate([fee_row(member, amount: -105)])
    expect(account.reload).to have_attributes(last_return_reason: "AC04", mandate_state: :blocked)
    expect(account).not_to be_collectible
    expect(log.last).to eq [:apply, member.id, 2026, -105]

    allocator(returned.reload).revert
    expect(account.reload.last_return_reason).to be_nil
  end

  it "ignores and reopens" do
    allocator(fee).ignore("Kursgebühr")
    expect(fee.reload).to have_attributes(state: "ignored", note: "Kursgebühr", processed_by: user)

    allocator(fee).reopen
    expect(fee.reload).to have_attributes(state: "open", note: "Kursgebühr", processed_by: nil)
  end
end
