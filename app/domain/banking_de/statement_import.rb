# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

require "zip"

# Imports uploaded camt files (single XML files or ZIP archives with XML files).
#
# - Reports already imported (same account, period and balances) are skipped.
# - Entries are identified by the bank reference; entries already imported are skipped,
#   so overlapping exports do no harm.
# - Only incoming payments and returned direct debits are stored. Outgoing payments,
#   pending and reversed entries are not relevant here and not stored at all.
class BankingDe::StatementImport
  MAX_FILE_SIZE = 20.megabytes
  MAX_ZIP_ENTRIES = 1000
  MAX_ZIP_SIZE = 100.megabytes

  # German "Geschäftsvorfallcodes" of collected direct debit batches (Sammler)
  BATCH_CODES = %w[191 192 193 195 196].freeze

  Result = Struct.new(:files, :reports, :duplicate_reports, :bookings, :duplicate_bookings,
    :skipped_entries, :errors, keyword_init: true) do
    def initialize(**)
      super
      %i[files reports duplicate_reports bookings duplicate_bookings skipped_entries]
        .each { |key| self[key] ||= 0 }
      self.errors ||= []
    end

    def success?
      errors.empty?
    end
  end

  attr_reader :group, :user, :result

  def initialize(group, user)
    @group = group
    @user = user
    @result = Result.new
  end

  # uploads: objects responding to #original_filename and #read (e.g. uploaded files)
  def import(uploads)
    Array(uploads).each do |upload|
      each_xml(upload.original_filename, upload.read(MAX_FILE_SIZE + 1)) do |name, xml|
        import_xml(name, xml)
      end
    end
    result
  end

  private

  def each_xml(name, data, &)
    if data.nil? || data.bytesize > MAX_FILE_SIZE
      add_error(name, :too_large)
    elsif data.start_with?("PK")
      each_zip_entry(name, data, &)
    else
      yield name, data
    end
  end

  def each_zip_entry(name, data)
    Zip::File.open_buffer(StringIO.new(data)) do |zip|
      entries = xml_entries(zip)
      return add_error(name, :too_many_files) if entries.size > MAX_ZIP_ENTRIES
      return add_error(name, :too_large) if entries.sum(&:size) > MAX_ZIP_SIZE

      entries.each do |entry|
        yield File.basename(entry.name), entry.get_input_stream.read(MAX_FILE_SIZE + 1)
      end
    end
  rescue Zip::Error => e
    add_error(name, :invalid_zip, message: e.message)
  end

  # XML files without hidden files (e.g. __MACOSX/._name.xml)
  def xml_entries(zip)
    zip.entries.select(&:file?)
      .select { |e| File.extname(e.name).casecmp?(".xml") }
      .reject { |e| File.basename(e.name).start_with?(".") || e.name.start_with?("__MACOSX") }
      .sort_by(&:name)
  end

  def import_xml(name, xml)
    result.files += 1
    reports = BankingDe::Camt::Parser.new(xml).reports
    BankingDe::Statement.transaction do
      reports.each { |report| import_report(name, report) }
    end
  rescue BankingDe::Camt::Parser::Error => e
    add_error(name, :invalid_file, message: e.message)
  end

  def import_report(name, report)
    return add_error(name, :no_iban) unless report.account_iban
    return result.duplicate_reports += 1 if duplicate?(report)

    statement = create_statement(name, report)
    result.reports += 1
    report.entries.each { |entry| import_entry(statement, entry) }
  end

  def duplicate?(report)
    BankingDe::Statement.exists?(
      account_iban: report.account_iban, statement_id: report.statement_id,
      from_date: report.from_date, to_date: report.to_date,
      opening_balance: report.opening_balance, closing_balance: report.closing_balance
    )
  end

  def create_statement(name, report)
    BankingDe::Statement.create!(
      group: group, imported_by: user, filename: name.to_s.last(255),
      account_iban: report.account_iban, message_type: report.message_type,
      statement_id: report.statement_id, from_date: report.from_date, to_date: report.to_date,
      opening_balance: report.opening_balance, closing_balance: report.closing_balance
    )
  end

  def import_entry(statement, entry)
    kind = relevant?(entry) && kind_of(entry)
    return result.skipped_entries += 1 unless kind

    details = entry.details.presence || [BankingDe::Camt::Parser::Detail.new]
    details.each_with_index do |detail, index|
      create_booking(statement, entry, detail, kind, reference(entry, details, index))
    end
  end

  def relevant?(entry)
    entry.booked && !entry.reversal
  end

  # Batched entries with single items get one booking per item
  def reference(entry, details, index)
    (details.size > 1) ? "#{entry.bank_reference}/#{index + 1}" : entry.bank_reference
  end

  def create_booking(statement, entry, detail, kind, reference) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    if reference.blank? ||
        BankingDe::Booking.exists?(account_iban: statement.account_iban, bank_reference: reference)
      return result.duplicate_bookings += 1
    end

    BankingDe::Booking.create!(
      statement: statement, group: group, account_iban: statement.account_iban,
      bank_reference: reference, kind: kind, state: "open",
      booking_date: entry.booking_date, value_date: entry.value_date,
      amount: detail.amount || entry.amount,
      counterparty_name: detail.counterparty_name&.first(255),
      counterparty_iban: detail.counterparty_iban,
      remittance_information: detail.remittance_information,
      end_to_end_id: detail.end_to_end_id, mandate_reference: detail.mandate_reference,
      payment_information_id: detail.payment_information_id,
      return_reason: detail.return_reason,
      bank_transaction_code: [entry.domain_code, entry.family_code, entry.sub_family_code,
        entry.proprietary_code].compact.join(" ").presence
    )
    result.bookings += 1
  end

  # nil for entries that are not stored
  def kind_of(entry)
    entry.debit? ? debit_kind(entry) : credit_kind(entry)
  end

  # Only returned direct debits, no outgoing payments and no direct debits of others
  def debit_kind(entry)
    "return" if returned?(entry) && entry.family_code != "RDDT"
  end

  def credit_kind(entry)
    return if returned?(entry) || entry.family_code == "RRTN" # own transfer that came back
    return "transfer" unless direct_debit?(entry)

    batch?(entry) ? "direct_debit_batch" : "direct_debit"
  end

  def returned?(entry)
    entry.details.any?(&:return_reason) || entry.sub_family_code == "UPDD"
  end

  def direct_debit?(entry)
    entry.family_code == "IDDT" ||
      (entry.domain_code.nil? && entry.proprietary_code.to_s.start_with?("NDDT"))
  end

  def batch?(entry)
    gvc = entry.proprietary_code.to_s.split("+")[1]
    return true if BATCH_CODES.include?(gvc)

    entry.details.size == 1 && entry.details.first.counterparty_iban.nil? &&
      entry.details.first.payment_information_id.present?
  end

  def add_error(name, key, **)
    result.errors << I18n.t("banking_de.statement_import.errors.#{key}", file: name, **)
    nil
  end
end
