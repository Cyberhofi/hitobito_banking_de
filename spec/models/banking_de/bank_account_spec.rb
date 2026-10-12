# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

require "spec_helper"

describe BankingDe::BankAccount do
  let(:person) { people(:bottom_member) }

  def build(**attrs)
    described_class.new(person: person, iban: "DE89 3704 0044 0532 0130 00", **attrs)
  end

  it "normalizes and validates the IBAN" do
    account = build
    expect(account).to be_valid
    expect(account.iban).to eq "DE89370400440532013000"

    expect(build(iban: "DE00370400440532013000")).not_to be_valid
  end

  it "requires reference and signing date together" do
    expect(build(mandate_reference: "M-1")).not_to be_valid
    expect(build(mandate_signed_on: Date.current)).not_to be_valid
    expect(build(mandate_reference: "M-1", mandate_signed_on: Date.current)).to be_valid
    expect(build(mandate_reference: "M_1!", mandate_signed_on: Date.current)).not_to be_valid
  end

  it "does not allow revoking before signing" do
    account = build(mandate_reference: "M-1", mandate_signed_on: Date.new(2026, 2, 1),
      mandate_revoked_on: Date.new(2026, 1, 1))
    expect(account).not_to be_valid
  end

  it "keeps mandate references unique" do
    build(mandate_reference: "M-1", mandate_signed_on: Date.current).save!
    other = described_class.new(person: people(:top_leader), iban: "DE89370400440532013000",
      mandate_reference: "M-1", mandate_signed_on: Date.current)
    expect(other).not_to be_valid
  end

  it "knows the mandate state and whether direct debits may be collected" do
    account = build
    expect(account.mandate_state).to eq :none
    expect(account).not_to be_collectible

    account.assign_attributes(mandate_reference: "M-1", mandate_signed_on: Date.current - 1.year)
    expect(account.mandate_state).to eq :active
    expect(account).to be_collectible

    account.last_return_reason = "AM04"
    expect(account).to be_collectible
    account.last_return_reason = "MD07"
    expect(account.mandate_state).to eq :blocked
    expect(account).not_to be_collectible

    account.mandate_revoked_on = Date.current
    expect(account.mandate_state).to eq :revoked
  end

  it "selects collectible accounts" do
    build(mandate_reference: "M-1", mandate_signed_on: Date.current).save!
    described_class.create!(person: people(:top_leader), iban: "DE52120300001111111111",
      mandate_reference: "M-2", mandate_signed_on: Date.current, last_return_reason: "AC04")

    expect(described_class.collectible.map(&:person)).to eq [person]
  end

  it "resets the last return when the IBAN changes" do
    account = build(last_return_reason: "AC04", last_return_on: Date.current)
    account.save!
    account.update!(iban: "DE52120300001111111111")

    expect(account.last_return_reason).to be_nil
  end
end
