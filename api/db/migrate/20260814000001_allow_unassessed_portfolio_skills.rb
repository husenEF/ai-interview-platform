# frozen_string_literal: true

# portfolio_skills could not express "we did not assess this".
#
# ai_level was NOT NULL and constrained to 1..5, so every skill written to a
# portfolio had to carry a rating — including skills the interview never
# probed, and skills the model returned null or garbage for. The generator
# resolved that with `.to_i.clamp(1, 5)`, which turns nil into 1: the lowest
# rating on the scale, presented to a recruiter as a real judgement about a
# candidate who was never asked.
#
# The concept already exists downstream — fit_result has a `not_assessed`
# value — it just never reached the table where ratings are produced.
#
# After this migration a skill row is exactly one of:
#   - assessed:   ai_level 1..5, ai_confidence set, not_assessed_reason NULL
#   - unassessed: ai_level NULL, ai_confidence NULL, not_assessed_reason set
# enforced in the database by chk_portfolio_skills_rating_xor, so no future
# code path can reintroduce a fabricated level.
class AllowUnassessedPortfolioSkills < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      CREATE TYPE ai_interview.not_assessed_reason AS ENUM (
        'never_probed', 'insufficient_evidence', 'analysis_failed'
      );
    SQL

    change_column_null :portfolio_skills, :ai_level, true
    change_column_null :portfolio_skills, :ai_confidence, true
    add_column :portfolio_skills, :not_assessed_reason, :enum,
               enum_type: 'ai_interview.not_assessed_reason'

    # The original range check rejects NULL under Postgres three-valued logic
    # only because of the NOT NULL beside it; state it explicitly instead.
    remove_check_constraint :portfolio_skills, name: 'chk_portfolio_skills_ai_level'
    add_check_constraint :portfolio_skills,
                         'ai_level IS NULL OR (ai_level >= 1 AND ai_level <= 5)',
                         name: 'chk_portfolio_skills_ai_level'

    add_check_constraint :portfolio_skills, <<~SQL.squish, name: 'chk_portfolio_skills_rating_xor'
      (ai_level IS NOT NULL AND ai_confidence IS NOT NULL AND not_assessed_reason IS NULL)
      OR
      (ai_level IS NULL AND ai_confidence IS NULL AND not_assessed_reason IS NOT NULL)
    SQL

    # The generator now upserts by skill_label so assessor overrides survive
    # regeneration. That is only well-defined if a label identifies at most one
    # row per portfolio. Refuse rather than silently pick a winner.
    duplicates = select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM (
        SELECT portfolio_id, skill_label
        FROM ai_interview.portfolio_skills
        GROUP BY portfolio_id, skill_label
        HAVING COUNT(*) > 1
      ) AS dupes
    SQL

    if duplicates.positive?
      raise ActiveRecord::IrreversibleMigration,
            "#{duplicates} portfolio/skill_label pair(s) appear more than once. " \
            'Deduplicate them before running this migration; refusing to guess ' \
            "which row is the candidate's real rating."
    end

    add_index :portfolio_skills, %i[portfolio_id skill_label], unique: true,
                                 name: 'index_portfolio_skills_on_portfolio_and_label'
  end

  def down
    unassessed = select_value(
      'SELECT COUNT(*) FROM ai_interview.portfolio_skills WHERE ai_level IS NULL'
    ).to_i

    if unassessed.positive?
      raise ActiveRecord::IrreversibleMigration,
            "#{unassessed} skill(s) are recorded as not assessed and the old schema " \
            'cannot represent that. Rolling back would require inventing a level for ' \
            'each of them, which is the defect this migration exists to remove. ' \
            'Delete or re-generate those portfolios first if the rollback is intended.'
    end

    remove_index :portfolio_skills, name: 'index_portfolio_skills_on_portfolio_and_label'
    remove_check_constraint :portfolio_skills, name: 'chk_portfolio_skills_rating_xor'
    remove_check_constraint :portfolio_skills, name: 'chk_portfolio_skills_ai_level'
    add_check_constraint :portfolio_skills, 'ai_level >= 1 AND ai_level <= 5',
                         name: 'chk_portfolio_skills_ai_level'

    remove_column :portfolio_skills, :not_assessed_reason
    change_column_null :portfolio_skills, :ai_confidence, false
    change_column_null :portfolio_skills, :ai_level, false

    execute 'DROP TYPE ai_interview.not_assessed_reason;'
  end
end
