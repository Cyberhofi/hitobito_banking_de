# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Confirmed assignment of (a part of) a booking to a person and a purpose. Negative amounts
# stand for returned direct debits.
class BankingDe::Allocation < ActiveRecord::Base
  belongs_to :booking, class_name: "BankingDe::Booking"
  belongs_to :person, class_name: "::Person"
  belongs_to :created_by, class_name: "::Person", optional: true

  validates :purpose, inclusion: {in: ->(_) { BankingDe.purposes.keys }}
  validates :amount, presence: true, numericality: {other_than: 0}
  validates :year, presence: true, numericality: {only_integer: true, in: 2000..2100},
    if: -> { purpose_definition&.yearly }

  scope :list, -> { order(:year, :id) }

  def purpose_definition
    BankingDe.purposes[purpose]
  end

  def negative?
    amount.negative?
  end
end
