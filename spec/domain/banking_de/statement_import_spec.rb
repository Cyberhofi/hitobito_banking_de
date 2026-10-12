# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

require "spec_helper"

describe BankingDe::StatementImport do
  let(:bookings) { BankingDe::Booking.order(:bank_reference) }

  it "stores incoming payments and returned direct debits only" do
    result = import_camt("camt052_v08.xml")

    expect(result).to be_success
    expect(result.reports).to eq 1
    expect(result.bookings).to eq 4
    expect(result.skipped_entries).to eq 1
    expect(bookings.map(&:kind)).to match_array %w[transfer transfer direct_debit_batch return]
    expect(BankingDe::Booking.where(counterparty_name: "Some Shop")).to be_empty
  end

  it "keeps the details of a booking" do
    import_camt("camt052_v08.xml")
    booking = BankingDe::Booking.find_by(kind: "return")

    expect(booking).to have_attributes(state: "open", amount: 105, return_reason: "AC04",
      mandate_reference: "MANDATE-0001", account_iban: BankingDeHelpers::OWN_IBAN,
      group: groups(:top_layer), booking_date: Date.new(2026, 4, 15))
    expect(booking.statement.imported_by).to eq people(:top_leader)
  end

  it "skips statements and bookings already imported" do
    import_camt("camt052_v08.xml")
    result = import_camt("camt052_v08.xml", "camt053_v02.xml")

    expect(result.duplicate_reports).to eq 1
    expect(result.reports).to eq 1
    expect(result.duplicate_bookings).to eq 1
    expect(result.bookings).to eq 1
    expect(BankingDe::Booking.count).to eq 5
    expect(BankingDe::Statement.count).to eq 2
  end

  it "reads ZIP archives" do
    result = described_class.new(groups(:top_layer), people(:top_leader))
      .import([zip_upload("camt052_v08.xml", "camt053_v02.xml")])

    expect(result.files).to eq 2
    expect(result.bookings).to eq 5
  end

  it "reports invalid files without stopping the import" do
    uploads = [BankingDeHelpers::Upload.new("bad.xml", "<foo/>"), camt_upload("camt053_v02.xml")]
    result = described_class.new(groups(:top_layer), people(:top_leader)).import(uploads)

    expect(result).not_to be_success
    expect(result.errors.first).to start_with "bad.xml"
    expect(result.bookings).to eq 2
  end

  it "finds gaps between statements" do
    import_camt("camt052_v08.xml", "camt053_v02.xml")
    continuity = BankingDe::StatementContinuity.new(groups(:top_layer))
    expect(continuity.gaps).to be_empty
    expect(continuity.latest[BankingDeHelpers::OWN_IBAN].closing_balance).to eq 1505

    BankingDe::Statement.find_by(statement_id: "TEST-STMT-0416").update!(opening_balance: 2000)
    gap = BankingDe::StatementContinuity.new(groups(:top_layer)).gaps.first
    expect(gap.after).to eq Date.new(2026, 4, 15)
    expect(gap.before).to eq Date.new(2026, 4, 16)
  end
end
