# frozen_string_literal: true

#  Copyright (c) 2026, Stefan Hofmann. This file is part of
#  hitobito_banking_de and licensed under the Affero General Public License version 3
#  or later. See the LICENSE file at the top-level directory.

# Common parts of the statement import controllers: only on layer groups and only for
# people with the finance permission in this layer.
class BankingDe::BaseController < ApplicationController
  before_action :authorize_group

  helper_method :group

  private

  def group
    @group ||= Group.find(params[:group_id])
  end

  def authorize_group
    raise ActiveRecord::RecordNotFound unless group.layer?

    authorize!(:manage_bank_bookings, group)
  end

  def bookings
    BankingDe::Booking.where(group: group)
  end
end
