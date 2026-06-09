# frozen_string_literal: true

WebhookInbox::Engine.routes.draw do
  root to: "dashboard#index", as: :dashboard
  resources :events, only: [:show], controller: "dashboard" do
    member do
      post :replay
    end
  end
end
