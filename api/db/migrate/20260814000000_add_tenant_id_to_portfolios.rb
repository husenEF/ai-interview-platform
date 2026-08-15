# frozen_string_literal: true

# Portfolios are addressed directly by :id on several routes
# (/portfolios/:id/export, /fitgap, /regenerate_fitgap) but carried no tenant,
# so those lookups could not be scoped and returned any organization's record.
#
# Giving portfolios a tenant_id lets them use the same TenantScoped default
# scope as assessments, sessions and vacancies, which makes the safe lookup the
# default one rather than something each controller has to remember.
class AddTenantIdToPortfolios < ActiveRecord::Migration[7.0]
  def up
    add_column :portfolios, :tenant_id, :bigint

    # Backfill from the owning session before adding NOT NULL, so this is safe
    # against a database that already holds portfolios. Every portfolio has a
    # session (session_id is NOT NULL), so this covers all existing rows.
    execute <<~SQL
      UPDATE ai_interview.portfolios AS p
      SET tenant_id = s.tenant_id
      FROM ai_interview.sessions AS s
      WHERE p.session_id = s.id
    SQL

    orphaned = select_value(
      'SELECT COUNT(*) FROM ai_interview.portfolios WHERE tenant_id IS NULL'
    ).to_i

    if orphaned.positive?
      raise ActiveRecord::IrreversibleMigration,
            "#{orphaned} portfolio(s) have no session to inherit a tenant from. " \
            'Resolve those rows before running this migration; refusing to guess ' \
            'which organization a candidate record belongs to.'
    end

    change_column_null :portfolios, :tenant_id, false
    add_index :portfolios, :tenant_id
  end

  def down
    remove_index  :portfolios, :tenant_id
    remove_column :portfolios, :tenant_id
  end
end
