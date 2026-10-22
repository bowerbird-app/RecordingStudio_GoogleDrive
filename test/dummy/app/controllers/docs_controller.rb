# frozen_string_literal: true

class DocsController < ApplicationController
  def install
  end

  def configuration
    render :config
  end
end
