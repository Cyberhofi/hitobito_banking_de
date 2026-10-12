# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

require "spec_helper"

describe BankingDe::Suggestion do
  let(:group) { groups(:top_layer) }
  let(:suggestion) { described_class.new(described_class.people_for(group)) }

  before do
    register_test_purposes
    import_camt("camt052_v08.xml", "camt053_v02.xml")
  end

  def booking(amount, name = nil)
    scope = BankingDe::Booking.where(amount: amount)
    scope = scope.where(counterparty_name: name) if name
    scope.first!
  end

  def rows(booking)
    suggestion.rows(booking).map { |r| [r.purpose, r.year, r.amount] }
  end

  it "suggests people of the layer by name in payer and text" do
    best = suggestion.best(booking(85))

    expect(best.person).to eq people(:bottom_member)
    expect(best.reasons).to eq %i[last_name first_name]
    expect(best.level).to eq :likely

    expect(suggestion.best(booking(105, "Erika Example")).person).to eq people(:top_leader)
  end

  it "is sure with a known IBAN" do
    BankingDe::BankAccount.create!(person: people(:top_leader), iban: BankingDeHelpers::OTHER_IBAN)

    best = suggestion.best(booking(170))

    expect(best.person).to eq people(:top_leader)
    expect(best.level).to eq :sure
    expect(best.reasons).to eq [:iban]
  end

  it "finds the member number" do
    allow(Settings).to receive(:banking_de)
      .and_return(Config::Options.new(member_number_attribute: "nickname"))
    people(:top_leader).update_column(:nickname, "A-0815")
    booking(170).update!(remittance_information: "Beitrag A 0815")

    candidate = suggestion.candidates(booking(170)).first
    expect(candidate.person).to eq people(:top_leader)
    expect(candidate.reasons).to include :member_number
  end

  it "does not suggest people outside the layer" do
    booking(85).update!(counterparty_name: "Somebody", remittance_information: "Bottom Member 2026")
    other_layer = described_class.new(described_class.people_for(groups(:bottom_layer_two)))

    expect(other_layer.candidates(booking(85))).to be_empty
  end

  it "splits the amount into purposes and years" do
    expect(rows(booking(85))).to eq [["membership_fee", 2026, 85]]
    expect(rows(booking(105, "Erika Example")))
      .to eq [["membership_fee", 2026, 85], ["work_hours", 2026, 20]]
    expect(rows(booking(170))).to eq [["membership_fee", 2026, 85], ["membership_fee", 2027, 85]]
  end

  it "suggests the fee for several people for multiples of the fee in one year" do
    batch = booking(255)
    batch.update!(kind: "transfer", remittance_information: "Beitrag 2026 fuer drei")

    expect(rows(batch)).to eq [["membership_fee", 2026, 85]] * 3
    expect(suggestion.rows(batch).map(&:person_id).compact.size).to be <= 1
  end

  it "suggests a negative fee for returned direct debits" do
    expect(rows(BankingDe::Booking.find_by!(kind: "return"))).to eq [["membership_fee", 2026, -105]]
  end
end
