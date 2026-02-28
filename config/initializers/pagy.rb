# frozen_string_literal: true

require "pagy"

# Pagy設定
Pagy::DEFAULT[:limit] = 10
Pagy::DEFAULT[:overflow] = :last_page
