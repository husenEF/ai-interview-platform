# frozen_string_literal: true

# Gemini::HttpClient does ENV.fetch('GEMINI_API_KEY') in its constructor, which
# raises KeyError when the variable is absent. Every request it would make is
# stubbed by WebMock, so the value is irrelevant — but it has to exist, or specs
# fail on construction instead of on the behaviour under test.
ENV['GEMINI_API_KEY'] = 'test-key' if ENV['GEMINI_API_KEY'].blank?
