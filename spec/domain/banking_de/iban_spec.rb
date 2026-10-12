# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

require "spec_helper"

describe BankingDe::Iban do
  it "validates check digits" do
    expect(described_class.valid?("DE89 3704 0044 0532 0130 00")).to be true
    expect(described_class.valid?("DE88370400440532013000")).to be false
    expect(described_class.valid?("DE8937040044")).to be false
    expect(described_class.valid?(nil)).to be false
  end

  it "normalizes, formats and masks" do
    expect(described_class.normalize(" de89 3704 0044 0532 0130 00 "))
      .to eq "DE89370400440532013000"
    expect(described_class.format("DE89370400440532013000")).to eq "DE89 3704 0044 0532 0130 00"
    expect(described_class.mask("DE89370400440532013000")).to eq "DE… 3000"
  end
end
