# frozen_string_literal: true

module WebhookInbox
  class DashboardController < ApplicationController
    def index
      @events = WebhookInbox::Event.order(created_at: :desc)
      @events = @events.where(status: params[:status]) if params[:status].present?
      @events = @events.where(provider: params[:provider]) if params[:provider].present?
      @events = @events.page(params[:page]).per(50) if @events.respond_to?(:page)
      @events = @events.limit(200) unless @events.respond_to?(:page)

      @status_counts = WebhookInbox::Event.group(:status).count
      @providers     = WebhookInbox::Event.distinct.pluck(:provider).sort
    end

    def show
      @event = WebhookInbox::Event.find(params[:id])
    end

    def replay
      @event = WebhookInbox::Event.find(params[:id])
      @event.retry!
      redirect_to webhook_inbox.dashboard_path, notice: "Event #{@event.event_id} queued for reprocessing."
    end
  end
end
