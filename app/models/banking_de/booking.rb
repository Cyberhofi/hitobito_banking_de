# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# A relevant entry of an imported statement: incoming payments and returned direct debits.
# Outgoing payments are not stored.
#
# kind:  transfer           incoming credit transfer (or other credit)
#        direct_debit       single collected direct debit
#        direct_debit_batch collected direct debits booked as one sum (no single items)
#        return             returned direct debit (debited again)
# state: open, done (allocated), ignored
class BankingDe::Booking < ActiveRecord::Base
  KINDS = %w[transfer direct_debit direct_debit_batch return].freeze
  STATES = %w[open done ignored].freeze

  belongs_to :statement, class_name: "BankingDe::Statement"
  belongs_to :group, class_name: "::Group"
  belongs_to :processed_by, class_name: "::Person", optional: true
  has_many :allocations, class_name: "BankingDe::Allocation", dependent: :restrict_with_error

  validates :kind, inclusion: {in: KINDS}
  validates :state, inclusion: {in: STATES}

  scope :list, -> { order(booking_date: :asc, id: :asc) }
  scope :in_state, ->(state) { (state == "all") ? all : where(state: state) }

  STATES.each do |s|
    define_method(:"#{s}?") { state == s }
  end

  def return?
    kind == "return"
  end

  def batch?
    kind == "direct_debit_batch"
  end

  def allocatable?
    open? && !batch?
  end

  def allocated_amount
    allocations.sum(&:amount)
  end

  def to_s
    "#{I18n.l(booking_date)} #{counterparty_name}".strip
  end
end
