# frozen_string_literal: true

FactoryBot.define do
  factory :session do
    assessment
    tenant_id      { assessment.tenant_id }
    candidate_id   { 42 }
    candidate_name { 'Candidate Example' }
    status         { 'pending' }

    trait :ended do
      status           { 'ended' }
      started_at       { 1.hour.ago }
      ended_at         { Time.current }
      duration_seconds { 3600 }
      end_reason       { 'all_covered' }
    end

    trait :with_transcript do
      transient do
        turns { 4 }
      end

      after(:create) do |session, evaluator|
        evaluator.turns.times do |i|
          create(
            :transcript_turn,
            session: session,
            turn_number: i + 1,
            speaker: i.even? ? 'ai' : 'candidate'
          )
        end
      end
    end
  end

  factory :transcript_turn do
    session
    sequence(:turn_number) { |n| n }
    speaker { 'candidate' }
    text    { 'I built a service that handled retries and idempotency keys.' }
  end

  factory :coverage_map do
    session
    sequence(:skill_id)    { |n| "SK-ENG-#{format('%03d', n)}" }
    sequence(:skill_label) { |n| "Skill #{n}" }
    is_discovered { false }
    state         { 'covered' }
    probe_count   { 3 }

    trait :never_probed do
      state       { 'not_yet' }
      probe_count { 0 }
    end

    trait :partial do
      state       { 'partial' }
      probe_count { 2 }
    end
  end
end
