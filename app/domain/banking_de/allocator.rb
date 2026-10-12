# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Confirms, takes back and ignores bookings. Everything that changes data of people
# (e.g. "fee paid until") happens in the callbacks of the purposes, in one transaction.
#
# On confirmation of a payment of exactly one person, the payer's IBAN is stored for that
# person if no bank account is known yet. Returned direct debits are noted at the bank
# account, so mandates with blocking return reasons are not collected again unchecked.
class BankingDe::Allocator
  class Error < StandardError; end

  attr_reader :booking, :user

  def initialize(booking, user)
    @booking = booking
    @user = user
  end

  # rows: [{person_id:, purpose:, year:, amount:}, ...]; rows without person are dropped
  def allocate(rows, note: nil)
    raise Error, :not_allocatable unless booking.allocatable?

    allocations = build_allocations(rows)
    raise Error, :no_rows if allocations.empty?

    ActiveRecord::Base.transaction do
      allocations.sort_by { |a| [a.year.to_i, a.id.to_i] }.each do |allocation|
        allocation.save!
        apply(allocation)
      end
      remember_account(allocations)
      finish("done", note)
    end
    allocations
  end

  def revert
    raise Error, :not_done unless booking.done?

    ActiveRecord::Base.transaction do
      forget_return if booking.return?
      revert_allocations
      finish("open", booking.note)
    end
  end

  def ignore(note)
    raise Error, :not_open unless booking.open?

    finish("ignored", note)
  end

  def reopen
    raise Error, :not_ignored unless booking.ignored?

    finish("open", booking.note)
  end

  private

  def build_allocations(rows)
    rows.filter_map do |row|
      row = row.to_h.symbolize_keys
      next if row[:person_id].blank?

      BankingDe::Allocation.new(
        booking: booking, person_id: row[:person_id], purpose: row[:purpose],
        year: row[:year].presence, amount: parse_amount(row[:amount]), created_by: user
      ).tap { |a| raise ActiveRecord::RecordInvalid, a unless a.valid? }
    end
  end

  def parse_amount(value)
    return value if value.is_a?(Numeric)

    BigDecimal(value.to_s.strip.delete(" ").tr(",", "."))
  rescue ArgumentError
    nil
  end

  def apply(allocation)
    callback = allocation.purpose_definition.apply or return

    effect = callback.call(allocation)
    allocation.update_column(:effect, effect) if effect.present?
  end

  # Latest year first, so purposes can step back year by year
  def revert_allocations
    booking.allocations.sort_by { |a| [-a.year.to_i, -a.id] }.each do |allocation|
      allocation.purpose_definition&.revert&.call(allocation)
      allocation.destroy!
    end
  end

  def remember_account(allocations)
    people = allocations.map(&:person).uniq
    return unless people.one?

    booking.return? ? note_return(people.first) : store_iban(people.first)
  end

  def store_iban(person)
    iban = booking.counterparty_iban
    return unless iban && BankingDe::Iban.valid?(iban)
    return if person.banking_de_bank_account

    person.create_banking_de_bank_account!(iban: iban, account_holder: booking.counterparty_name,
      source: "import", created_by: user, updated_by: user)
  end

  def note_return(person)
    account = person.banking_de_bank_account or return

    account.update_columns(last_return_reason: booking.return_reason,
      last_return_on: booking.booking_date, updated_at: Time.current)
  end

  def forget_return
    BankingDe::BankAccount.where(person_id: booking.allocations.select(:person_id),
      last_return_reason: booking.return_reason, last_return_on: booking.booking_date)
      .update_all(last_return_reason: nil, last_return_on: nil)
  end

  def finish(state, note)
    booking.update!(state: state, note: note.presence,
      processed_by: (state == "open") ? nil : user,
      processed_at: (state == "open") ? nil : Time.current)
  end
end
