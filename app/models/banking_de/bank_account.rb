# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Bank account of a person together with the SEPA direct debit mandate, if one was given.
# Direct debits may only be collected with an active mandate (reference and signing date,
# not revoked) and without a blocking return reason since the last change.
class BankingDe::BankAccount < ActiveRecord::Base
  SOURCES = %w[manual import].freeze
  MANDATE_REFERENCE_FORMAT = %r{\A[A-Za-z0-9+?/\-:().,' ]+\z}

  belongs_to :person, class_name: "::Person"
  belongs_to :created_by, class_name: "::Person", optional: true
  belongs_to :updated_by, class_name: "::Person", optional: true

  normalizes :iban, with: ->(value) { BankingDe::Iban.normalize(value) }
  normalizes :account_holder, :mandate_reference, with: ->(value) { value.strip.presence }

  validates :iban, presence: true
  validates :source, inclusion: {in: SOURCES}
  validates :mandate_reference, uniqueness: true, length: {maximum: 35},
    format: {with: MANDATE_REFERENCE_FORMAT}, allow_nil: true
  validates :mandate_signed_on, presence: true, if: :mandate_reference
  validates :mandate_reference, presence: true, if: :mandate_signed_on
  validate :assert_valid_iban
  validate :assert_revoked_after_signed

  before_save :reset_return, if: -> { persisted? && iban_changed? }

  scope :with_active_mandate, lambda {
    where.not(mandate_reference: nil).where.not(mandate_signed_on: nil)
      .where("mandate_revoked_on IS NULL OR mandate_revoked_on > ?", Date.current)
  }
  scope :collectible, lambda {
    with_active_mandate.where(last_return_reason: nil)
      .or(with_active_mandate.where.not(last_return_reason: BankingDe::BLOCKING_RETURN_REASONS))
  }

  def mandate?
    mandate_reference.present? && mandate_signed_on.present?
  end

  def mandate_active?
    mandate? && (mandate_revoked_on.nil? || mandate_revoked_on > Date.current)
  end

  def mandate_blocked?
    BankingDe::BLOCKING_RETURN_REASONS.include?(last_return_reason)
  end

  def collectible?
    mandate_active? && !mandate_blocked?
  end

  # :none, :active, :revoked or :blocked
  def mandate_state
    if !mandate? then :none
    elsif !mandate_active? then :revoked
    elsif mandate_blocked? then :blocked
    else
      :active
    end
  end

  def to_s
    BankingDe::Iban.format(iban)
  end

  private

  def assert_valid_iban
    errors.add(:iban, :invalid) if iban.present? && !BankingDe::Iban.valid?(iban)
  end

  def assert_revoked_after_signed
    return unless mandate_signed_on && mandate_revoked_on
    return if mandate_revoked_on >= mandate_signed_on

    errors.add(:mandate_revoked_on, :before_signed)
  end

  def reset_return
    self.last_return_reason = nil
    self.last_return_on = nil
  end
end
