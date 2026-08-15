# frozen_string_literal: true

# assessor_overrides.ai_level records what the AI said at the moment a human
# disagreed with it, so the two judgements can be compared later. With
# portfolio_skills.ai_level now nullable, that snapshot has to be able to say
# "the AI did not rate this".
#
# This is the case that matters most, not an edge case: a skill the model could
# not rate is exactly the one an assessor should be able to rate themselves. The
# NOT NULL here would have blocked that with a validation error naming a column
# the assessor never sees.
class AllowOverridesOfUnassessedSkills < ActiveRecord::Migration[7.0]
  def up
    change_column_null :assessor_overrides, :ai_level, true

    remove_check_constraint :assessor_overrides, name: 'chk_overrides_ai_level'
    add_check_constraint :assessor_overrides,
                         'ai_level IS NULL OR (ai_level >= 1 AND ai_level <= 5)',
                         name: 'chk_overrides_ai_level'
  end

  def down
    unrated = select_value(
      'SELECT COUNT(*) FROM ai_interview.assessor_overrides WHERE ai_level IS NULL'
    ).to_i

    if unrated.positive?
      raise ActiveRecord::IrreversibleMigration,
            "#{unrated} override(s) record that the AI produced no level. The old " \
            'schema cannot represent that, and inventing one would misattribute a ' \
            'rating to the model. Remove those overrides first if the rollback is intended.'
    end

    remove_check_constraint :assessor_overrides, name: 'chk_overrides_ai_level'
    add_check_constraint :assessor_overrides, 'ai_level >= 1 AND ai_level <= 5',
                         name: 'chk_overrides_ai_level'
    change_column_null :assessor_overrides, :ai_level, false
  end
end
