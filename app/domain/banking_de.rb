# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Entry point for organization wagons.
#
# Purposes describe what an incoming payment is for. They are registered by the
# organization wagon, e.g.:
#
#   BankingDe.register_purpose(:membership_fee, amount: 85, yearly: true, primary: true,
#     apply: ->(allocation) { ... return a hash describing the change ... },
#     revert: ->(allocation) { ... undo the change described in allocation.effect ... })
#
# - amount: usual amount, used for suggestions only (no amount check)
# - yearly: the allocation refers to a year
# - primary: the main purpose suggested for incoming payments (one per year)
# - apply / revert: called inside the database transaction when an allocation is confirmed
#   or taken back. Negative allocations (returned direct debits) call them as well, the
#   callbacks distinguish them by allocation.amount.
module BankingDe
  Purpose = Struct.new(:key, :amount, :yearly, :primary, :apply, :revert, keyword_init: true) do
    def label
      I18n.t("banking_de.purposes.#{key}", default: key.to_s.humanize)
    end

    def to_s
      label
    end
  end

  # Bank return reasons after which a mandate must not be used without checking it first
  # (account closed, wrong, blocked, no mandate, holder deceased, ...)
  BLOCKING_RETURN_REASONS = %w[AC01 AC04 AC06 AC13 AG01 BE05 MD01 MD02 MD07 MS02 SL01].freeze

  mattr_reader :purposes, default: {}

  class << self
    def table_name_prefix
      "banking_de_"
    end

    def register_purpose(key, amount: nil, yearly: false, primary: false, apply: nil, revert: nil)
      purposes[key.to_s] = Purpose.new(key: key.to_s, amount: amount&.to_d, yearly: yearly,
        primary: primary, apply: apply, revert: revert)
    end

    def purpose(key)
      purposes.fetch(key.to_s) { raise ArgumentError, "Unknown purpose #{key}" }
    end

    def primary_purpose
      purposes.values.find(&:primary)
    end

    # Person attribute holding a number people may write into the remittance information
    def member_number_attribute
      Settings.banking_de&.member_number_attribute.presence
    end
  end
end
