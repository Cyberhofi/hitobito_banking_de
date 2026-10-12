# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Normalizing, validating (ISO 13616 check digits) and formatting of IBANs
module BankingDe::Iban
  module_function

  def normalize(value)
    value.to_s.gsub(/\s+/, "").upcase.presence
  end

  def valid?(value)
    iban = normalize(value)
    return false unless iban&.match?(/\A[A-Z]{2}\d{2}[A-Z0-9]{11,30}\z/)

    rearranged = iban[4..] + iban[0, 4]
    rearranged.gsub(/[A-Z]/) { |c| (c.ord - 55).to_s }.to_i % 97 == 1
  end

  def format(value)
    normalize(value)&.scan(/.{1,4}/)&.join(" ")
  end

  # Shows only the last four characters, e.g. for lists
  def mask(value)
    iban = normalize(value)
    return unless iban

    "#{iban[0, 2]}… #{iban[-4..]}"
  end
end
