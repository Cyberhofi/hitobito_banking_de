# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Incoming payments and returned direct debits of the imported statements. Nothing is
# booked without confirmation: the treasurer confirms, corrects or ignores every booking.
class BankingDe::BookingsController < BankingDe::BaseController
  STATES = %w[open done ignored all].freeze

  helper_method :state, :suggestion, :people, :counts, :continuity

  def index
    @bookings = bookings.in_state(state).list
      .includes(:processed_by, allocations: :person)
      .page(params[:page]).per(100)
  end

  def show
    @booking = entry
  end

  def allocate
    check_people!
    allocator.allocate(rows_param, note: params[:note])
    redirect_to next_url, notice: t(".success", booking: entry)
  rescue BankingDe::Allocator::Error, ActiveRecord::RecordInvalid => e
    redirect_to group_bank_booking_path(group, entry), alert: error_message(e)
  end

  def revert
    allocator.revert
    redirect_to group_bank_booking_path(group, entry), notice: t(".success")
  rescue BankingDe::Allocator::Error => e
    redirect_to group_bank_booking_path(group, entry), alert: error_message(e)
  end

  def ignore
    allocator.ignore(params[:note])
    redirect_to next_url, notice: t(".success", booking: entry)
  rescue BankingDe::Allocator::Error => e
    redirect_to group_bank_booking_path(group, entry), alert: error_message(e)
  end

  def reopen
    allocator.reopen
    redirect_to group_bank_booking_path(group, entry), notice: t(".success")
  rescue BankingDe::Allocator::Error => e
    redirect_to group_bank_booking_path(group, entry), alert: error_message(e)
  end

  private

  def entry
    @entry ||= bookings.find(params[:id])
  end

  def allocator
    BankingDe::Allocator.new(entry, current_user)
  end

  def rows_param
    params.fetch(:rows, {}).values.map { |row| row.permit(:person_id, :purpose, :year, :amount) }
  end

  # Only people the user may manage the bank data of may be allocated
  def check_people!
    ids = rows_param.pluck(:person_id).compact_blank.map(&:to_i).uniq
    allowed = Person.where(id: ids).select { |person| can?(:update_bank_account, person) }
    raise ActiveRecord::RecordNotFound unless allowed.size == ids.size
  end

  # After confirming from the detail page continue with the next open booking
  def next_url
    return group_bank_bookings_path(group) if params[:return_to] == "index"

    following = bookings.in_state("open").where.not(kind: "direct_debit_batch")
      .where("booking_date > :date OR (booking_date = :date AND id > :id)",
        date: entry.booking_date, id: entry.id).list.first
    following ? group_bank_booking_path(group, following) : group_bank_bookings_path(group)
  end

  def error_message(error)
    case error
    when ActiveRecord::RecordInvalid then error.record.errors.full_messages.to_sentence
    else t("banking_de.bookings.errors.#{error.message}")
    end
  end

  def state
    STATES.include?(params[:state]) ? params[:state] : "open"
  end

  def counts
    @counts ||= bookings.group(:state).count
  end

  def people
    @people ||= BankingDe::Suggestion.people_for(group)
  end

  def suggestion
    @suggestion ||= BankingDe::Suggestion.new(people)
  end

  def continuity
    @continuity ||= BankingDe::StatementContinuity.new(group)
  end
end
