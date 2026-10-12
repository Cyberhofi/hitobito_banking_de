# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Reads account reports (camt.052) and statements (camt.053) of the ISO 20022 versions
# used by German banks (.02 and .08 tested). Element names are the same in these versions,
# so the namespaces are removed and only the local names are used.
class BankingDe::Camt::Parser
  class Error < StandardError; end

  Report = Struct.new(:message_type, :statement_id, :account_iban, :from_date, :to_date,
    :opening_balance, :closing_balance, :entries, keyword_init: true)

  Entry = Struct.new(:bank_reference, :booking_date, :value_date, :amount, :credit,
    :booked, :reversal, :domain_code, :family_code, :sub_family_code, :proprietary_code,
    :details, keyword_init: true) do
    def debit?
      !credit
    end
  end

  Detail = Struct.new(:amount, :counterparty_name, :counterparty_iban, :remittance_information,
    :end_to_end_id, :mandate_reference, :payment_information_id, :return_reason,
    keyword_init: true)

  SUPPORTED = /\Acamt\.05[23]\.001\.\d\d\z/
  ROOTS = {"BkToCstmrAcctRpt" => "Rpt", "BkToCstmrStmt" => "Stmt"}.freeze
  OPENING = %w[OPBD PRCD].freeze
  CLOSING = %w[CLBD].freeze

  attr_reader :message_type

  def initialize(xml)
    @doc = Nokogiri::XML(xml) { |config| config.strict.nonet.noblanks }
    @message_type = detect_message_type
    @doc.remove_namespaces!
  rescue Nokogiri::XML::SyntaxError => e
    raise Error, e.message
  end

  def reports
    root_name, report_name = ROOTS.find { |name, _| @doc.at_xpath("/Document/#{name}") }
    raise Error, "no camt.052/053 document" unless root_name

    @doc.xpath("/Document/#{root_name}/#{report_name}").map { |node| report(node) }
  end

  private

  def detect_message_type
    namespace = @doc.root&.namespace&.href.to_s
    type = namespace[/camt\.\d{3}\.\d{3}\.\d{2}/]
    raise Error, "unsupported message type #{type || namespace}" unless type&.match?(SUPPORTED)

    type
  end

  def report(node)
    entries = node.xpath("Ntry").map { |n| entry(n) }
    dates = entries.map(&:booking_date).compact
    Report.new(
      message_type: message_type,
      statement_id: text(node, "Id"),
      account_iban: BankingDe::Iban.normalize(text(node, "Acct/Id/IBAN")),
      from_date: date(text(node, "FrToDt/FrDtTm")) || dates.min,
      to_date: date(text(node, "FrToDt/ToDtTm")) || dates.max,
      opening_balance: balance(node, OPENING),
      closing_balance: balance(node, CLOSING),
      entries: entries
    )
  end

  def entry(node) # rubocop:disable Metrics/AbcSize
    Entry.new(
      bank_reference: text(node, "AcctSvcrRef") || text(node, "NtryRef"),
      booking_date: date(text(node, "BookgDt/Dt") || text(node, "BookgDt/DtTm")),
      value_date: date(text(node, "ValDt/Dt") || text(node, "ValDt/DtTm")),
      amount: amount(node),
      credit: text(node, "CdtDbtInd") == "CRDT",
      booked: [nil, "BOOK"].include?(text(node, "Sts/Cd") || text(node, "Sts")),
      reversal: text(node, "RvslInd") == "true",
      domain_code: code(node, "Domn/Cd"),
      family_code: code(node, "Domn/Fmly/Cd"),
      sub_family_code: code(node, "Domn/Fmly/SubFmlyCd"),
      proprietary_code: code(node, "Prtry/Cd"),
      details: node.xpath("NtryDtls/TxDtls").map { |tx| detail(tx) }
    )
  end

  def detail(node)
    Detail.new(
      amount: amount(node),
      counterparty_name: text(node, "RltdPties/UltmtDbtr//Nm") ||
        text(node, "RltdPties/Dbtr//Nm"),
      counterparty_iban: BankingDe::Iban.normalize(text(node, "RltdPties/DbtrAcct/Id/IBAN")),
      remittance_information: node.xpath("RmtInf/Ustrd").map { |u| u.text.strip }
        .reject(&:empty?).join(" ").squeeze(" ").presence,
      end_to_end_id: text(node, "Refs/EndToEndId").then { |id| (id == "NOTPROVIDED") ? nil : id },
      mandate_reference: text(node, "Refs/MndtId"),
      payment_information_id: text(node, "Refs/PmtInfId"),
      return_reason: text(node, "RtrInf/Rsn/Cd")
    )
  end

  # Bank transaction code of the entry; some banks (e.g. Sparkasse) only fill it in the
  # transaction details
  def code(node, path)
    text(node, "BkTxCd/#{path}") || text(node, "NtryDtls/TxDtls[1]/BkTxCd/#{path}")
  end

  def balance(node, types)
    bal = node.xpath("Bal").find { |b| types.include?(text(b, "Tp/CdOrPrtry/Cd")) }
    return unless bal

    value = BigDecimal(text(bal, "Amt"))
    (text(bal, "CdtDbtInd") == "DBIT") ? -value : value
  end

  def amount(node)
    value = text(node, "Amt")
    value && BigDecimal(value)
  end

  def text(node, path)
    node.at_xpath(path)&.text&.strip.presence
  end

  def date(value)
    value && Date.iso8601(value[0, 10])
  rescue Date::Error
    nil
  end
end
