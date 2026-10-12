# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Finds the years a payment is meant for in the remittance information, e.g.
# "Beitrag 2026", "2026/27", "Jahresbeitrag 26-27", "2026 2027". Dates (13.04.2026) are
# ignored. Without a plausible year the year of the booking date is used.
class BankingDe::YearParser
  DATE = /\b\d{1,2}\.\d{1,2}\.(?:\d{4}|\d{2})\b/
  RANGE = %r{(?<!\d)(?:20)?(\d{2})\s*[/-]\s*(?:20)?(\d{2})(?!\d)}
  YEAR = /(?<!\d)(20\d{2})(?!\d)/

  def initialize(text, booking_date)
    @text = text.to_s.gsub(DATE, " ")
    @booking_year = booking_date.year
  end

  def years
    found = (ranges + single_years).select { |year| plausible?(year) }.uniq.sort
    found.presence || [@booking_year]
  end

  private

  def ranges
    @text.scan(RANGE).flat_map do |from, to|
      from = 2000 + from.to_i
      to = 2000 + to.to_i
      (to == from + 1) ? [from, to] : []
    end
  end

  def single_years
    @text.scan(YEAR).flatten.map(&:to_i)
  end

  def plausible?(year)
    (@booking_year - 1..@booking_year + 2).cover?(year)
  end
end
