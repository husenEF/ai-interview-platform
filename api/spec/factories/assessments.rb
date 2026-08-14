# frozen_string_literal: true

FactoryBot.define do
  factory :assessment do
    # Assessment includes TenantScoped, whose assign_tenant_id does
    # `self.tenant_id ||= Current.tenant_id`. Setting it here short-circuits
    # that, so the factory works with or without an ambient tenant. Specs about
    # isolation must pass tenant_id explicitly rather than trust the default.
    tenant_id      { 1 }
    created_by     { 1 }
    sequence(:name) { |n| "Backend Engineer Assessment #{n}" }
    time_limit_min { 30 }
    language       { 'en' }

    transient do
      skills_count { 0 }
    end

    after(:create) do |assessment, evaluator|
      create_list(:assessment_skill, evaluator.skills_count, assessment: assessment)
    end
  end

  factory :assessment_skill do
    assessment
    sequence(:skill_id)    { |n| "SK-ENG-#{format('%03d', n)}" }
    sequence(:skill_label) { |n| "Skill #{n}" }
    is_custom     { false }
    scope_include { 'What counts as in scope for this skill.' }
    l1_anchor     { 'Executes with explicit guidance.' }
    l2_anchor     { 'Executes independently on routine scope.' }
    l3_anchor     { 'Executes complex, ambiguous scope.' }
    l4_anchor     { 'Defines standards and reusable systems.' }
    l5_anchor     { 'Org-level authority.' }
    expected_level { 3 }
    sequence(:display_order) { |n| n }
  end
end
