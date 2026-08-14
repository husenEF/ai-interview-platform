# frozen_string_literal: true

# CoverageAnalyzerWorker is retry: 0 and rescues everything, so an analyzer
# failure leaves the coverage map exactly as it was — typically `not_yet`.
#
# On its own that was invisible. It stops being invisible now that `not_yet`
# means something concrete: the portfolio reports such a skill as "not discussed
# during the interview". If the analyzer crashed, that statement is false — the
# skill was discussed, the software failed to notice.
#
# Recording the failure lets the two cases be told apart, so a skill that went
# unanalysed is reported as unanalysed rather than as unasked.
class AddAnalysisErrorToCoverageMaps < ActiveRecord::Migration[7.0]
  def change
    add_column :coverage_maps, :last_analysis_error, :text
    add_column :coverage_maps, :last_analysis_failed_at, :datetime
  end
end
