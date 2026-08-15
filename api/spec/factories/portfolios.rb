# frozen_string_literal: true

FactoryBot.define do
  factory :portfolio do
    session
    candidate_id      { session.candidate_id }
    generation_status { 'complete' }
    generated_at      { Time.current }

    trait :pending do
      generation_status { 'pending' }
      generated_at      { nil }
    end

    trait :failed do
      generation_status { 'failed' }
      generated_at      { nil }
      generation_error  { 'Gemini::HttpClient::TimeoutError' }
    end
  end

  factory :portfolio_skill do
    portfolio
    sequence(:skill_id)    { |n| "SK-ENG-#{format('%03d', n)}" }
    sequence(:skill_label) { |n| "Skill #{n}" }
    is_discovered      { false }
    ai_level           { 3 }
    ai_confidence      { 'high' }
    evidence           { ['I introduced idempotency keys after a duplicate-charge incident.'] }
    competency_summary { 'Reasons about failure modes before reaching for a fix.' }
  end

  factory :assessor_override do
    portfolio_skill
    ai_level       { portfolio_skill.ai_level }
    override_level { 4 }
    assessor_notes { 'Underrated — the incident story shows clear L4 systems thinking.' }
    overridden_by  { 1 }
    overridden_at  { Time.current }
  end

  factory :vacancy do
    tenant_id  { 1 }
    created_by { 1 }
    sequence(:role_title) { |n| "Senior Backend Engineer #{n}" }
    culture_dimensions      { 'Writes things down. Disagrees early.' }
    competency_expectations { 'Owns a service end to end.' }
  end

  factory :vacancy_skill do
    vacancy
    sequence(:skill_id)    { |n| "SK-ENG-#{format('%03d', n)}" }
    sequence(:skill_label) { |n| "Skill #{n}" }
    expected_level { 3 }
  end
end
