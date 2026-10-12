# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Upload of account statements (camt.052/053, single XML files or ZIP) and list of the
# imported statements with a completeness check.
class BankingDe::StatementsController < BankingDe::BaseController
  helper_method :continuity

  def index
    @statements = BankingDe::Statement.where(group: group).list.includes(:imported_by)
      .page(params[:page]).per(50)
  end

  def new
  end

  def create
    files = Array(params.dig(:bank_statement, :files)).compact_blank
    return redirect_to(new_group_bank_statement_path(group), alert: t(".no_file")) if files.empty?

    result = BankingDe::StatementImport.new(group, current_user).import(files)
    redirect_to group_bank_bookings_path(group), **flash_for(result)
  end

  private

  def flash_for(result)
    summary = t(".summary", **result.to_h.except(:errors))
    if result.success?
      {notice: summary}
    else
      {alert: [summary, *result.errors]}
    end
  end

  def continuity
    @continuity ||= BankingDe::StatementContinuity.new(group)
  end
end
