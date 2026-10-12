# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

require "spec_helper"

describe BankingDe::Camt::Parser do
  it "reads camt.052.001.08 account reports" do
    parser = described_class.new(camt_file("camt052_v08.xml").read)
    report = parser.reports.first

    expect(parser.message_type).to eq "camt.052.001.08"
    expect(report.account_iban).to eq BankingDeHelpers::OWN_IBAN
    expect(report.from_date).to eq Date.new(2026, 4, 15)
    expect(report.opening_balance).to eq 1000
    expect(report.closing_balance).to eq 1335
    expect(report.entries.size).to eq 5

    fee = report.entries.first
    expect(fee.amount).to eq 85
    expect(fee.credit).to be true
    expect(fee.booked).to be true
    expect(fee.details.first.counterparty_name).to eq "MEMBER BOTTOM"
    expect(fee.details.first.counterparty_iban).to eq BankingDeHelpers::MEMBER_IBAN
    expect(fee.details.first.end_to_end_id).to be_nil

    expect(report.entries.second.details.first.remittance_information)
      .to eq "Beitrag 2026 und Pflichtstunden Top Leader"

    returned = report.entries.fourth
    expect(returned.debit?).to be true
    expect(returned.details.first.return_reason).to eq "AC04"
    expect(returned.details.first.mandate_reference).to eq "MANDATE-0001"
  end

  it "reads camt.053.001.02 statements" do
    report = described_class.new(camt_file("camt053_v02.xml").read).reports.first

    expect(report.from_date).to eq Date.new(2026, 4, 16)
    expect(report.opening_balance).to eq 1335
    expect(report.entries.map(&:booked)).to eq [true, true]
    expect(report.entries.first.details.first.counterparty_name).to eq "MEMBER BOTTOM"
  end

  it "rejects other documents" do
    expect {
      described_class.new("<Document xmlns='urn:iso:std:iso:20022:tech:xsd:pain.008.001.08'/>")
    }
      .to raise_error(described_class::Error, /pain.008/)
    expect { described_class.new("no xml") }.to raise_error(described_class::Error)
  end

  it "does not resolve external entities" do
    xml = <<~XML
      <?xml version="1.0"?>
      <!DOCTYPE d [<!ENTITY x SYSTEM "file:///etc/passwd">]>
      <Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.02"><BkToCstmrStmt><Stmt>
      <Id>&x;</Id><Acct><Id><IBAN>#{BankingDeHelpers::OWN_IBAN}</IBAN></Id></Acct></Stmt></BkToCstmrStmt></Document>
    XML
    report = described_class.new(xml).reports.first

    expect(report.statement_id.to_s).not_to include "root:"
  end
end
