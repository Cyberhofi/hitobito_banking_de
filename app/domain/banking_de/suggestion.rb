# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Suggests who paid a booking, for which years and how the amount splits into purposes.
# Nothing is booked here; the suggestions only prefill the form the treasurer confirms.
#
# Scores per person:
#   known IBAN or mandate reference  100
#   member number in the text         80
#   last name in name/text            40 (all parts of the last name)
#   first name in name/text           25 (only together with the last name)
class BankingDe::Suggestion
  SURE = 100
  LIKELY = 65
  MAX_CANDIDATES = 5
  MIN_NUMBER_LENGTH = 3

  Candidate = Struct.new(:person, :score, :reasons, keyword_init: true) do
    def level
      if score >= SURE then :sure
      elsif score >= LIKELY then :likely
      else
        :possible
      end
    end
  end

  Row = Struct.new(:person_id, :purpose, :year, :amount, keyword_init: true)

  # people: the people who may be suggested, see .people_for
  def self.people_for(group)
    groups = group.layer_group.self_and_descendants.select(:id)
    attrs = [:id, :first_name, :last_name, :nickname, :company_name, :company, :birthday]
    attrs << BankingDe.member_number_attribute.to_sym if BankingDe.member_number_attribute
    Person.where(id: Role.where(group_id: groups).select(:person_id))
      .select(*attrs).order(:last_name, :first_name).to_a
  end

  def initialize(people)
    @people = people
    @index = BankingDe::NameIndex.new(people)
    @candidates = {}
  end

  def candidates(booking)
    @candidates[booking.id || booking.object_id] ||= compute_candidates(booking)
  end

  # Candidate that may be preselected: sure, or likely and clearly ahead of the next one
  def best(booking)
    first, second = candidates(booking)
    return unless first
    return first if first.level == :sure
    return first if first.level == :likely && (second.nil? || second.score < first.score)

    nil
  end

  def years(booking)
    BankingDe::YearParser.new(booking.remittance_information, booking.booking_date).years
  end

  def rows(booking)
    person_id = best_person_id(booking)
    return [return_row(booking, person_id)] if booking.return?

    rows = split(booking.amount, years(booking))
    # several fees for the same year: paid for several people, only the first one is known
    several = several_people?(rows)
    rows.each_with_index { |row, i| row.person_id = person_id if i.zero? || !several }
  end

  private

  def best_person_id(booking)
    best(booking)&.person&.id
  end

  def compute_candidates(booking)
    scores = Hash.new { |h, k| h[k] = Candidate.new(person: k, score: 0, reasons: []) }
    add_account_matches(booking, scores)
    add_member_number_matches(booking, scores)
    add_name_matches(booking, scores)
    scores.values.sort_by { |c| [-c.score, c.person.last_name.to_s, c.person.first_name.to_s] }
      .first(MAX_CANDIDATES)
  end

  def return_row(booking, person_id)
    Row.new(person_id: person_id, purpose: BankingDe.primary_purpose&.key,
      year: booking.booking_date.year, amount: -booking.amount)
  end

  def several_people?(rows)
    rows.select { |row| row.purpose == BankingDe.primary_purpose&.key }
      .map(&:year).tally.values.any? { |count| count > 1 }
  end

  def add_account_matches(booking, scores)
    accounts.each do |account|
      reason = account_match(account, booking)
      add(scores, @index.person(account.person_id), SURE, reason) if reason
    end
  end

  def account_match(account, booking)
    if booking.counterparty_iban.present? && account.iban == booking.counterparty_iban
      :iban
    elsif booking.mandate_reference.present? &&
        account.mandate_reference == booking.mandate_reference
      :mandate
    end
  end

  def accounts
    @accounts ||= BankingDe::BankAccount.where(person_id: @people.map(&:id))
      .select(:person_id, :iban, :mandate_reference).to_a
  end

  def add_member_number_matches(booking, scores)
    attr = BankingDe.member_number_attribute or return
    text = booking.remittance_information.to_s.upcase
    tokens = number_tokens(text)
    compact = text.gsub(/[^A-Z0-9]/, "")

    @people.each do |person|
      number = normalize_number(person.send(attr))
      next unless number && number.length >= MIN_NUMBER_LENGTH

      add(scores, person, 80, :member_number) if member_number_in?(number, tokens, compact)
    end
  end

  # Pure numbers must stand alone (not within dates or IBANs); numbers with letters may be
  # written with spaces or dashes ("A 0815" for "A-0815")
  def member_number_in?(number, tokens, compact)
    tokens.include?(number) || (number.match?(/[A-Z]/) && compact.include?(number))
  end

  def add_name_matches(booking, scores)
    text = [booking.counterparty_name, booking.remittance_information].compact.join(" ")
    @index.matches(text).each do |person, first_name_found|
      add(scores, person, 40, :last_name)
      add(scores, person, 25, :first_name) if first_name_found
    end
  end

  def add(scores, person, points, reason)
    candidate = scores[person]
    return if candidate.reasons.include?(reason)

    candidate.score += points
    candidate.reasons << reason
  end

  def number_tokens(text)
    text.to_s.upcase.scan(/[A-Z]*\d[A-Z0-9]*/).map { |t| normalize_number(t) }.compact.to_set
  end

  def normalize_number(value)
    value = value.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    value = value.sub(/\A0+(?=\d)/, "") if value.match?(/\A\d+\z/)
    value.presence
  end

  # Splits an amount into the primary purpose per year plus other purposes for the rest,
  # e.g. 85 + 20 or 2 x 85 for two years. Falls back to one row with the full amount.
  def split(amount, years)
    primary = BankingDe.primary_purpose
    return [Row.new(amount: amount, year: years.first)] unless primary&.amount

    [years.size, 1].uniq.each do |count|
      rows = split_with(primary, amount, years.first(count))
      return rows if rows
    end
    several_fees(primary, amount, years.first) ||
      [Row.new(purpose: primary.key, year: years.first, amount: amount)]
  end

  # e.g. 255 = 3 x 85 for three people
  def several_fees(primary, amount, year)
    count = amount / primary.amount
    return unless count == count.to_i && count.between?(2, 10)

    Array.new(count.to_i) { primary_row(primary, year) }
  end

  def split_with(primary, amount, years)
    rest = amount - primary.amount * years.size
    return if rest.negative?

    rows = years.map { |year| primary_row(primary, year) }
    return rows if rest.zero?

    other = purpose_for_rest(primary, rest, years.size) or return
    rows + rest_rows(other, rest, years)
  end

  def rest_rows(purpose, rest, years)
    Array.new((rest / purpose.amount).to_i) do |i|
      Row.new(purpose: purpose.key, year: years[i], amount: purpose.amount)
    end
  end

  # Another purpose that makes up the rest, at most once per year
  def purpose_for_rest(primary, rest, max)
    BankingDe.purposes.values.find do |p|
      next false if p == primary || !p.amount&.positive?

      (rest % p.amount).zero? && rest / p.amount <= max
    end
  end

  def primary_row(primary, year)
    Row.new(purpose: primary.key, year: year, amount: primary.amount)
  end
end
