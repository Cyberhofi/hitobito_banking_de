# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

require "spec_helper"

describe BankingDe::YearParser do
  def years(text, date = Date.new(2026, 4, 15))
    described_class.new(text, date).years
  end

  it "finds single years" do
    expect(years("MITGLIEDSBEITRAG 2026")).to eq [2026]
    expect(years("BETRAG FUER YAHR 2026")).to eq [2026]
  end

  it "finds ranges" do
    expect(years("Beitrag 2026/27")).to eq [2026, 2027]
    expect(years("BETRAG 26-27")).to eq [2026, 2027]
    expect(years("JAHRESBT 2026 2027")).to eq [2026, 2027]
  end

  it "ignores dates and implausible years" do
    expect(years("2026 DATUM 13.06.2025, 13.53 UHR")).to eq [2026]
    expect(years("GA 2036 / 04.11.25")).to eq [2026]
  end

  it "falls back to the booking year" do
    expect(years("Beitrag")).to eq [2026]
    expect(years(nil, Date.new(2027, 1, 3))).to eq [2027]
  end
end
